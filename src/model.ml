open Melange_json.Primitives

(** Types for Basecamp API using melange-json PPX *)

type timestamp = Devkit.Time.t

let timestamp_of_json s =
  let of_rfc_3339_exn s =
    match Ptime.of_rfc3339 s with
    | Ok (t, _, _) -> Ptime.to_float_s t
    | Error (`RFC3339 _) -> Devkit.Exn.fail "Error parsing timestamp %s" s
  in
  Melange_json.Of_json.string s |> of_rfc_3339_exn

let timestamp_to_json t =
  Devkit.Time.gmt_string_ms t |> Melange_json.To_json.string

type person = {
  id : int;
  name : string;
  email_address : string;
  avatar_url : string;
  title : string option; [@json.option]
  created_at : timestamp;
  updated_at : timestamp;
}
[@@deriving json, json_string] [@@json.allow_extra_fields]
(** Extended Person model for /people endpoint *)

type people = person list [@@deriving json, json_string]
(** List of people *)

(** Topology: Basecamp is hierachically organized of objects within containers.
    Projects (i.e. Buckets) are the top-level containers for other objects, see
    {!type:dock_item_type}. Objects may each also have their own sub-hierachies,
    i.e.

    Todos Topology:

    Project (Bucket) -> Todosets -> Todolist -> Todo *)

type bucket = { id : int; name : string }
[@@deriving json, json_string] [@@json.allow_extra_fields]
(** Bucket - toplevel container for objects, referring to Project container *)

type parent = { id : int; title : string; url : string; app_url : string }
[@@deriving json, json_string] [@@json.allow_extra_fields]
(** Direct parent reference for current object *)

type todo = {
  id : int;
  title : string;
  description : string;
  url : string;
  app_url : string;
  created_at : timestamp;
  updated_at : timestamp;
  parent : parent; (* Todolist *)
  bucket : bucket; (* Project *)
  completed : bool;
  creator : person;
  assignees : people;
  completion_subscribers : people;
  comments_count : int;
}
[@@deriving json, json_string] [@@json.allow_extra_fields]
(** Todo model -
    https://github.com/basecamp/bc3-api/blob/master/sections/todos.md *)

type todos = todo list [@@deriving json, json_string]
(** List of todos *)

type todolist = {
  id : int;
  name : string;
  title : string;
  description : string;
  app_url : string;
  parent : parent; (* Todoset *)
  bucket : bucket; (* Project *)
  creator : person;
}
[@@deriving json, json_string] [@@json.allow_extra_fields]
(** Todo list model -
    https://github.com/basecamp/bc3-api/blob/master/sections/todolists.md *)

type todolists = todolist list [@@deriving json, json_string]
(** List of todolists *)

type todoset = {
  id : int;
  name : string;
  title : string;
  app_url : string;
  creator : person;
  bucket : bucket; (* Project *)
}
[@@deriving json, json_string] [@@json.allow_extra_fields]
(** Todo set model -
    https://github.com/basecamp/bc3-api/blob/master/sections/todosets.md *)

type todosets = todoset list [@@deriving json, json_string]
(** List of todo sets *)

type dock_item_type =
  | Message_board
  | Todoset
  | Vault
  | Chat
  | Schedule
  | Kanban_board
  | Questionnaire
  | Inbox
  | Unrecognized of string

let dock_item_type_of_json s =
  match Melange_json.Of_json.string s with
  | "message_board" -> Message_board
  | "todoset" -> Todoset
  | "vault" -> Vault
  | "chat" -> Chat
  | "schedule" -> Schedule
  | "kanban_board" -> Kanban_board
  | "questionnaire" -> Questionnaire
  | "inbox" -> Inbox
  | s -> Unrecognized s

let dock_item_type_to_json t =
  (match t with
    | Message_board -> "message_board"
    | Todoset -> "todoset"
    | Vault -> "vault"
    | Chat -> "chat"
    | Schedule -> "schedule"
    | Kanban_board -> "kanban_board"
    | Questionnaire -> "questionnaire"
    | Inbox -> "inbox"
    | Unrecognized s -> s)
  |> Melange_json.To_json.string

type dock_item = {
  id : int;
  title : string;
  name : dock_item_type;
  app_url : string; (* Used as a link to be shared for usage in the browser *)
  url : string;
      (* url that you can call directly to get the item instead of building new URL *)
}
[@@deriving json, json_string] [@@json.allow_extra_fields]
(** Project dock entry *)

type dock = dock_item list [@@deriving json, json_string]

type project = {
  id : int;
  name : string;
  description : string option; [@json.option]
  app_url : string;
  status : string;
  dock : dock_item list;
}
[@@deriving json, json_string] [@@json.allow_extra_fields]
(** Project model -
    https://github.com/basecamp/bc3-api/blob/master/sections/projects.md *)

type projects = project list [@@deriving json, json_string]
(** Projects list *)
