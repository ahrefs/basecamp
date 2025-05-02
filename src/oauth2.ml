let domain = "launchpad.37signals.com"

let make_request_auth_url ~client_id ~redirect_uri =
  let query =
    [
      ("type", [ "web_server" ]);
      ("client_id", [ client_id ]);
      ("redirect_uri", [ redirect_uri ]);
    ]
  in
  Uri.make ~scheme:"https" ~path:"authorization/new" ~query ~host:domain ()

let make_token_issuer_url ~client_id ~redirect_uri ~client_secret
    ~verification_code =
  let query =
    [
      ("type", [ "web_server" ]);
      ("client_id", [ client_id ]);
      ("redirect_uri", [ redirect_uri ]);
      ("client_secret", [ client_secret ]);
      ("code", [ verification_code ]);
    ]
  in
  Uri.make ~scheme:"https" ~path:"authorization/token" ~query ~host:domain ()

let make_token_refresher_url ~client_id ~client_secret ~refresh_token =
  let query =
    [
      ("type", [ "refresh" ]);
      ("client_id", [ client_id ]);
      ("client_secret", [ client_secret ]);
      ("refresh_token", [ refresh_token ]);
    ]
  in
  Uri.make ~scheme:"https" ~path:"authorization/token" ~query ~host:domain ()
