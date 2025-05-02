open Printf
open Devkit
open Melange_json.Primitives

let log = Log.from "basecamp-client"

module RateLimiter = Lwt_throttle.Make (struct
  type t = unit

  let equal _ _ = true
  let hash _ = 1
end)

type t = {
  organization_id : int;
  client_id : string;
  client_secret : string;
  refresh_token : string;
  mutable access_token : string;
  app_name : string;
  email : string;
  rate_limiter : RateLimiter.t;
}

(** As per
    https://github.com/basecamp/bc3-api?tab=readme-ov-file#rate-limiting-429-too-many-requests,
    For a sense of scale, the first rate limit you'll commonly encounter is
    currently 50 requests per 10 second period per IP address. The default rate
    here is 3 req/s *)
let make ~organization_id ~client_id ~client_secret ~refresh_token
    ?(access_token = "empty") ?(app_name = "ocaml-basecamp-client")
    ?(email = "empty") ?(n_req_per_sec = 5) () =
  let rate_limiter = RateLimiter.create ~rate:n_req_per_sec ~max:1000 ~n:1000 in
  {
    organization_id;
    client_id;
    client_secret;
    refresh_token;
    access_token;
    app_name;
    email;
    rate_limiter;
  }

let get_access_token ({ client_id; client_secret; refresh_token; _ } : t) =
  let url =
    Oauth2.make_token_refresher_url ~client_id ~client_secret ~refresh_token
    |> Uri.to_string
  in
  match%lwt Web.http_request_lwt ~verbose:true `POST url with
  | `Error err ->
      Lwt.return_error
      @@ sprintf "error while trying to generate access_token: %s" err
  | `Ok s -> (
      let json = Yojson.Basic.from_string s in
      match Yojson.Basic.Util.member "access_token" json with
      | `String token -> Lwt.return_ok token
      | _ -> Lwt.return_error "Invalid token response format")

(** Refresh the [access_token] (with the [refresh_token]) *)
let refresh_token t =
  match%lwt get_access_token t with
  | Error err -> Exn_lwt.fail "failed to refresh_token. %s" err
  | Ok access_token ->
      t.access_token <- access_token;
      log#info "access_token refreshed";
      Lwt.return_unit

(** [with_refresh_token_if_expired f t] calls [f] with [t] and refreshes the
    access_token if the operation failed because the access_token has expired.
    It will only retry the operation once. *)
let with_refresh_token_if_expired f t =
  let handle_token_expired f =
    log#info "basecamp access_token expired, trying to acquire a fresh one...";
    let%lwt () = refresh_token t in
    Lwt_result.bind_error (f ()) (function
      | `Token_expired ->
          let msg = "failed to refresh the access_token" in
          log#error "%s" msg;
          Daemon.signal_exit ();
          Lwt.return_error msg
      | `Other err -> Lwt.return_error err)
  in
  let f () =
    Lwt_result.bind_error (f t) (fun err ->
        Lwt.return_error
        @@
        if
          CCString.find ~sub:"token expired" err <> -1
          || CCString.find ~sub:"OAuth token could not be verified" err <> -1
        then `Token_expired
        else `Other err)
  in
  Lwt_result.bind_error (f ()) (function
    | `Token_expired -> handle_token_expired f
    | `Other err -> Lwt.return_error err)

(* Don't use this directly, it doesn't include the oauth2 refresh *)
let make_req_aux meth url ~(parse : string -> 'a) ?(body : string option)
    ?(verbose = true) t =
  let auth = sprintf "Authorization: Bearer %s" t.access_token in
  let ua = sprintf "User-Agent: %s (%s)" t.app_name t.email in
  let body = Option.map (fun json -> `Raw ("application/json", json)) body in
  let headers = [ auth; ua ] in
  let resp_headers = ref [] in
  let collect_headers header =
    if String.starts_with ~prefix:"HTTP/2" header || header = "\r\n" then ()
    else resp_headers := String.trim header :: !resp_headers;
    String.length header
  in
  match%lwt RateLimiter.wait t.rate_limiter () with
  | false -> Lwt_result.fail "Too many pending requests"
  | true -> (
      match%lwt
        Web.http_request_lwt
          ~setup:(fun h -> Curl.set_headerfunction h collect_headers)
          ~verbose ~headers ?body meth (Uri.to_string url)
      with
      | `Error e -> Lwt_result.fail e
      | `Ok s -> (
          let resp_headers =
            List.filter_map
              (fun header ->
                match Stringext.cut header ~on:":" with
                | Some (k, v) -> Some (String.trim k, String.trim v)
                | None ->
                    log#warn "Got unparsable header %S" header;
                    None)
              !resp_headers
          in
          try Lwt_result.return (parse s, resp_headers)
          with exn ->
            Lwt_result.fail @@ sprintf "%s: %s" (Exn.to_string exn) s))

(* Client calling helpers *)
let make_req_by_url meth url ~(parse : string -> 'a) ?body ?verbose t =
  with_refresh_token_if_expired (make_req_aux meth url ~parse ?body ?verbose) t

let make_req_by_url_no_resp_hdrs meth url ~(parse : string -> 'a)
    ?(body : string option) ?verbose t =
  Lwt_result.map fst (make_req_by_url meth url ~parse ?body ?verbose t)

let make_req_by_path meth ~path ~(parse : string -> 'a) ?(body : string option)
    ?verbose t =
  let url = Uri.make ~scheme:"https" ~host:"3.basecampapi.com" ~path () in
  (* let url = Url.make ~scheme:Https ~path "3.basecampapi.com" in *)
  with_refresh_token_if_expired (make_req_aux meth url ~parse ?body ?verbose) t

let make_req_by_path_no_resp_hdrs meth ~path ~(parse : string -> 'a)
    ?(body : string option) ?verbose t =
  Lwt_result.map fst (make_req_by_path meth ~path ~parse ?body ?verbose t)

let extract_link_header headers =
  let extract_between_angle_brackets text =
    let open Re in
    let pattern =
      compile (seq [ char '<'; group (rep1 (compl [ char '>' ])); char '>' ])
    in
    try
      let matches = exec pattern text in
      Some (Group.get matches 1)
    with Not_found -> None
  in
  match List.assoc_opt "link" headers with
  | None -> None
  | Some link ->
      Option.map Uri.of_string
        (* Url.parse_exn *) (extract_between_angle_brackets link)

let fetch_all_paginated_results ~paginated_query ~parse t :
    ('a, string) Lwt_result.t =
  let open Lwt_result.Syntax in
  let rec aux acc fetch =
    match%lwt fetch with
    | Error e -> Lwt.return_error e
    | Ok (res, None) -> Lwt.return_ok (res @ acc)
    | Ok (res, Some next_page) ->
        let fetch =
          let+ fetch_ok, headers = make_req_by_url `GET next_page ~parse t in
          (fetch_ok, extract_link_header headers)
        in
        aux (res @ acc) fetch
  in
  aux [] (paginated_query t)

(*************************** Endpoints ***************************)

(* Person *)

let get_person ~person_id t =
  make_req_by_path_no_resp_hdrs `GET
    ~path:(sprintf "%d/people/%d.json" t.organization_id person_id)
    ~parse:Model.person_of_json_string t

let get_people t =
  Lwt_result.map
    (fun (r, hdrs) ->
      log#debug "get_people headers: [%s]"
        (List.map (fun (k, v) -> sprintf "%s: %s" k v) hdrs
        |> String.concat "\n");
      (r, extract_link_header hdrs))
    (make_req_by_path `GET
       ~path:(sprintf "%d/people.json" t.organization_id)
       ~parse:Model.people_of_json_string t)

let get_my_profile t =
  make_req_by_path_no_resp_hdrs `GET
    ~path:(sprintf "%d/my/profile.json" t.organization_id)
    ~parse:Model.person_of_json_string t

(* Project *)

let get_project ~project_id t =
  make_req_by_path_no_resp_hdrs `GET
    ~path:(sprintf "%d/projects/%d.json" t.organization_id project_id)
    ~parse:Model.project_of_json_string t

let get_projects t =
  Lwt_result.map
    (fun (r, hdrs) ->
      log#debug "get_projects headers: [%s]"
        (List.map (fun (k, v) -> sprintf "%s: %s" k v) hdrs
        |> String.concat "\n");
      (r, extract_link_header hdrs))
    (make_req_by_path `GET
       ~path:(sprintf "%d/projects.json" t.organization_id)
       ~parse:Model.projects_of_json_string t)

(* Todo set *)

let get_todoset ~project_id ~todoset_id t =
  make_req_by_path_no_resp_hdrs `GET
    ~path:
      (sprintf "%d/buckets/%d/todosets/%d.json" t.organization_id project_id
         todoset_id)
    ~parse:Model.todoset_of_json_string t

(* Todo List *)

let get_todolist ~project_id ~todolist_id t =
  make_req_by_path_no_resp_hdrs `GET
    ~path:
      (sprintf "%d/buckets/%d/todolists/%d.json" t.organization_id project_id
         todolist_id)
    ~parse:Model.todolist_of_json_string t

let get_todolists ~project_id ~todoset_id t =
  Lwt_result.map
    (fun (r, hdrs) ->
      log#debug "get_todolists headers: [%s]"
        (List.map (fun (k, v) -> sprintf "%s: %s" k v) hdrs
        |> String.concat "\n");
      (r, extract_link_header hdrs))
    (make_req_by_path `GET
       ~path:
         (sprintf "%d/buckets/%d/todosets/%d/todolists.json" t.organization_id
            project_id todoset_id)
       ~parse:Model.todolists_of_json_string t)

(* Todo *)

let get_todo ~project_id ~todo_id t =
  make_req_by_path_no_resp_hdrs `GET
    ~path:
      (sprintf "%d/buckets/%d/todos/%d.json" t.organization_id project_id
         todo_id)
    ~parse:Model.todo_of_json_string t

let get_todos ~project_id ~todolist_id t =
  Lwt_result.map
    (fun (r, hdrs) ->
      log#debug "get_todos headers: [%s]"
        (List.map (fun (k, v) -> sprintf "%s: %s" k v) hdrs
        |> String.concat "\n");
      (r, extract_link_header hdrs))
    (make_req_by_path `GET
       ~path:
         (sprintf "%d/buckets/%d/todolists/%d/todos.json" t.organization_id
            project_id todolist_id)
       ~parse:Model.todos_of_json_string t)

type create_todo_body = {
  content : string;
  description : string option; [@json.option] [@json.drop_default]
  assignee_ids : int list option; [@json.option] [@json.drop_default]
  completion_subscriber_ids : int list option;
      [@json.option] [@json.drop_default]
  notify : bool option; [@json.option] [@json.drop_default]
  due_on : string option; [@json.option] [@json.drop_default]
  starts_on : string option; [@json.option] [@json.drop_default]
}
[@@deriving to_json]

let create_todo ~project_id ~todolist_id ~content ?description ?assignee_ids
    ?completion_subscriber_ids ?notify ?due_on ?starts_on t =
  let body =
    {
      content;
      description;
      assignee_ids;
      completion_subscriber_ids;
      notify;
      due_on;
      starts_on;
    }
    |> create_todo_body_to_json |> Yojson.Basic.to_string
  in
  make_req_by_path_no_resp_hdrs `POST
    ~path:
      (sprintf "%d/buckets/%d/todolists/%d/todos.json" t.organization_id
         project_id todolist_id)
    ~body ~parse:Model.todo_of_json_string t
