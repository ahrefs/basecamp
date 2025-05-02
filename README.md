# Basecamp

A comprehensive OCaml client library for the Basecamp 3 API, developed by Ahrefs.

## Overview

This library provides a typed OCaml interface to the [Basecamp 3 API](https://github.com/basecamp/bc3-api), making it easy to interact with Basecamp from OCaml applications. It handles authentication, request rate limiting, pagination, and provides a comprehensive set of models and client functions to work with Basecamp resources.

## Features

- OAuth2 authentication support
- Comprehensive Basecamp resource models
- Type-safe API client
- Automatic request rate limiting
- Pagination support
- Lwt-based asynchronous API

## Installation

```bash
opam install basecamp
```

## Usage

### Authentication

The library uses OAuth2 for authentication. You'll need to register your application with Basecamp to obtain client credentials.

```ocaml
let client = Basecamp.Client.make
  ~organization_id:123456
  ~client_id:"your_client_id"
  ~client_secret:"your_client_secret"
  ~refresh_token:"your_refresh_token"
  ~app_name:"Your App Name"
  ~email:"your_email@example.com"
  ()
```

### Examples

#### Fetching Projects

```ocaml
open Lwt_result.Syntax

let get_all_projects client =
  let* projects, next_page = Basecamp.Client.get_projects client in
  Lwt_io.printf "Found %d projects\n" (List.length projects)
```

#### Working with Todos

```ocaml
(* Create a new todo *)
let create_new_todo client ~project_id ~todolist_id =
  let* todo = Basecamp.Client.create_todo
    ~project_id
    ~todolist_id
    ~content:"Implement new feature"
    ~description:"This is a detailed description of what needs to be done"
    ~due_on:"2023-12-31"
    client
  in
  Lwt_io.printf "Created todo with ID: %d\n" todo.id
  
(* Get all todos in a list *)
let get_todos client ~project_id ~todolist_id =
  let* todos, _ = Basecamp.Client.get_todos 
    ~project_id 
    ~todolist_id 
    client 
  in
  Lwt_io.printf "Found %d todos\n" (List.length todos)
```

#### Pagination Support

```ocaml
(* Fetch all paginated results *)
let get_all_people client =
  let* people = Basecamp.Client.fetch_all_paginated_results
    ~paginated_query:Basecamp.Client.get_people
    ~parse:Basecamp.Model.people_of_json_string
    client
  in
  Lwt_io.printf "Found %d people\n" (List.length people)
```

## API Documentation

The library provides access to the following Basecamp resources:

- People and profiles
- Projects
- Todosets
- Todolists
- Todos

For more details, see the [inline documentation](https://github.com/ahrefs/basecamp).

## Development

### Building

```bash
dune build
```

### Running Tests

```bash
dune runtest    # test models
```

To run tests with a real Basecamp account, create a `test_client.json` file with your credentials:

```json
{
  "organization_id": 123456,
  "client_id": "your_client_id",
  "client_secret": "your_client_secret",
  "refresh_token": "your_refresh_token"
}
```

```bash
cd test && dune exec -- ./test_client.exe
```

## License

This project is released into the public domain under the Unlicense. See the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgements

Developed and maintained by [Ahrefs](https://github.com/ahrefs).
