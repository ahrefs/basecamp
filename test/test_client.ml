open Basecamp
open Devkit
open Lwt_result.Syntax
open Melange_json.Primitives

let () = Log.set_loglevels "debug"
let log = Log.from "test_client"

type config = {
  organization_id : int;
  client_id : string;
  client_secret : string;
  refresh_token : string;
  access_token : string option; [@json.option]
}
[@@deriving json, json_string]

let client =
  let json = Yojson.Basic.from_file "test_client.json" in
  log#info "%s" (Yojson.Basic.pretty_to_string json);
  let { organization_id; client_id; client_secret; refresh_token; access_token } = config_of_json json in
  Client.make ~organization_id ~client_id ~client_secret ~refresh_token ?access_token ()

let exec_print_query ~name ~query ~to_string =
  let%lwt oc =
    Lwt_io.open_file ~flags:[ Unix.O_WRONLY; O_TRUNC; O_CREAT ] ~mode:Lwt_io.output
      (Printf.sprintf "json/%s-actual.json" name)
  in
  let%lwt res =
    match%lwt query with
    | exception exn ->
      let err = Exn.to_string exn in
      let%lwt () = Lwt_io.write_line oc err in
      Lwt.return_error err
    | Error msg ->
      let%lwt () = Lwt_io.write_line oc msg in
      Lwt.return_error msg
    | Ok obj ->
      let%lwt () = Lwt_io.write_line oc (obj |> to_string |> Yojson.Basic.prettify) in
      Lwt.return_ok obj
  in
  let%lwt () = Lwt_io.close oc in
  Lwt.return res

let () =
  Lwt_main.run
  @@
  (* People *)
  let people_queries () =
    let* people =
      exec_print_query ~name:"people"
        ~query:
          (Client.fetch_all_paginated_results ~paginated_query:Client.get_people ~parse:Model.people_of_json_string
             client)
        ~to_string:Model.people_to_json_string
    in
    match people with
    | [] -> Lwt.return_error "No users"
    | person :: _ ->
      let* person' =
        exec_print_query ~name:"person"
          ~query:(Client.get_person client ~person_id:person.id)
          ~to_string:Model.person_to_json_string
      in
      assert (person = person');
      let* _profile =
        exec_print_query ~name:"profile" ~query:(Client.get_my_profile client) ~to_string:Model.person_to_json_string
      in
      Lwt.return_ok ()
  in

  (* Projects *)
  let projects_queries () =
    let* projects =
      exec_print_query ~name:"projects"
        ~query:(Lwt_result.map fst (Client.get_projects client))
        ~to_string:Model.projects_to_json_string
    in

    let all_dock_items = List.fold_right (fun Model.{ dock; _ } acc -> dock @ acc) projects [] in
    (* Check for unrecognized dock item types because we use this to discover the rest of the project objects *)
    let unrecognized =
      List.filter_map
        (fun (dock_item : Model.dock_item) ->
          match dock_item.name with
          | Unrecognized s -> Some s
          | _ -> None)
        all_dock_items
    in
    if unrecognized <> [] then log#warn "Unrecognized dock item types: [%s]" (String.concat ";" unrecognized);

    match projects with
    | [] -> Lwt.return_error "No projects"
    | project :: _ ->
      let* project' =
        exec_print_query ~name:"project"
          ~query:(Client.get_project client ~project_id:project.id)
          ~to_string:Model.project_to_json_string
      in
      assert (project = project');

      (* Todo sets *)
      let todoset = List.find_opt (fun (dock_item : Model.dock_item) -> dock_item.name = Todoset) project.dock in
      (match todoset with
      | None ->
        Lwt.return_error
          "No todoset found in GET all projects for 1st page, did not run the rest of the tests that depend on this"
      | Some { id; _ } ->
        let* todoset =
          exec_print_query ~name:"todoset"
            ~query:(Client.get_todoset client ~project_id:project.id ~todoset_id:id)
            ~to_string:Model.todoset_to_json_string
        in

        (* Todo lists *)
        let* todolists =
          exec_print_query ~name:"todolists"
            ~query:(Lwt_result.map fst (Client.get_todolists client ~project_id:project.id ~todoset_id:todoset.id))
            ~to_string:Model.todolists_to_json_string
        in
        (match todolists with
        | [] -> Lwt.return_error "No todolists"
        | todolist :: _ ->
          let* todolist' =
            exec_print_query ~name:"todolist"
              ~query:(Client.get_todolist client ~project_id:project.id ~todolist_id:todolist.id)
              ~to_string:Model.todolist_to_json_string
          in
          assert (todolist = todolist');

          (* Todos *)
          let* todos =
            exec_print_query ~name:"todos"
              ~query:(Lwt_result.map fst (Client.get_todos client ~project_id:project.id ~todolist_id:todolist.id))
              ~to_string:Model.todos_to_json_string
          in

          (match todos with
          | [] -> Lwt.return_error "No todolists"
          | todo :: _ ->
            let* todo' =
              exec_print_query ~name:"todo"
                ~query:(Client.get_todo client ~project_id:project.id ~todo_id:todo.id)
                ~to_string:Model.todo_to_json_string
            in
            assert (todo = todo');
            Lwt.return_ok ())))
  in

  let%lwt results = Lwt.all [ people_queries (); projects_queries () ] in
  let failures =
    List.fold_left
      (fun cnt r ->
        match r with
        | Ok () -> cnt
        | Error msg ->
          log#error "%s" msg;
          cnt + 1)
      0 results
  in
  if failures > 0 then log#error "Total: %d failures" failures else log#info "All tests Passed";
  Lwt.return_unit
