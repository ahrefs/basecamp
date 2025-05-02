open Basecamp.Model
open Printf

(* Helper module for reading test JSON files *)
module TestUtil = struct
  let parse_json_file filename from_json_string to_json_string =
    In_channel.with_open_text filename (fun ic ->
      printf "\n=============%s===============\n" filename;
      let content = In_channel.input_all ic in
      try
        let record = from_json_string content in
        printf "%s\n" (Yojson.Basic.prettify (to_json_string record))
      with e -> Printf.printf "Error: %s\n" (Printexc.to_string e))
end

(* Run tests and output results *)
let () =
  (* Person Test *)
  TestUtil.parse_json_file "person.json" person_of_json_string person_to_json_string;
  TestUtil.parse_json_file "people.json" people_of_json_string people_to_json_string;

  (* Projects *)
  TestUtil.parse_json_file "project.json" project_of_json_string project_to_json_string;
  TestUtil.parse_json_file "projects.json" projects_of_json_string projects_to_json_string;

  (* Todolist Test *)
  TestUtil.parse_json_file "todolist.json" todolist_of_json_string todolist_to_json_string;
  TestUtil.parse_json_file "todolists.json" todolists_of_json_string todolists_to_json_string;

  (* Todo Test *)
  TestUtil.parse_json_file "todo.json" todo_of_json_string todo_to_json_string;
  TestUtil.parse_json_file "todos.json" todos_of_json_string todos_to_json_string
