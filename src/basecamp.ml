module Oauth2 = Oauth2
module Model = Model

module Client : sig
  type t

  val make :
    organization_id:int ->
    client_id:string ->
    client_secret:string ->
    refresh_token:string ->
    ?access_token:string ->
    ?app_name:string ->
    ?email:string ->
    ?n_req_per_sec:int ->
    unit ->
    t

  (* For calling urls received in the response of some of the objects directly, response headers may contain "link" header for paginated results *)
  val make_req_by_url :
    Devkit.Web.http_action ->
    Uri.t ->
    parse:(string -> 'a) ->
    ?body:string ->
    ?verbose:bool ->
    t ->
    ('a * (string * string) list, string) Lwt_result.t

  val extract_link_header : (string * string) list -> Uri.t option

  val make_req_by_url_no_resp_hdrs :
    Devkit.Web.http_action ->
    Uri.t ->
    parse:(string -> 'a) ->
    ?body:string ->
    ?verbose:bool ->
    t ->
    ('a, string) Lwt_result.t

  val fetch_all_paginated_results :
    paginated_query:(t -> ('a list * Uri.t option, string) result Lwt.t) ->
    parse:(string -> 'a list) ->
    t ->
    ('a list, string) result Lwt.t

  val get_person : person_id:int -> t -> (Model.person, string) Lwt_result.t
  val get_people : t -> (Model.people * Uri.t option, string) Lwt_result.t
  val get_my_profile : t -> (Model.person, string) Lwt_result.t
  val get_project : project_id:int -> t -> (Model.project, string) Lwt_result.t
  val get_projects : t -> (Model.projects * Uri.t option, string) Lwt_result.t
  val get_todoset : project_id:int -> todoset_id:int -> t -> (Model.todoset, string) Lwt_result.t
  val get_todolist : project_id:int -> todolist_id:int -> t -> (Model.todolist, string) Lwt_result.t
  val get_todolists : project_id:int -> todoset_id:int -> t -> (Model.todolists * Uri.t option, string) Lwt_result.t
  val get_todo : project_id:int -> todo_id:int -> t -> (Model.todo, string) Lwt_result.t
  val get_todos : project_id:int -> todolist_id:int -> t -> (Model.todos * Uri.t option, string) Lwt_result.t
  val create_todo :
    project_id:int ->
    todolist_id:int ->
    content:string ->
    ?description:string ->
    ?assignee_ids:int list ->
    ?completion_subscriber_ids:int list ->
    ?notify:bool ->
    ?due_on:string ->
    ?starts_on:string ->
    t ->
    (Model.todo, string) result Lwt.t
end =
  Client
