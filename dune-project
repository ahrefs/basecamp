(lang dune 3.16)

(name basecamp)

(generate_opam_files true)

(source
 (github ahrefs/basecamp))

(authors
 "Koonwen Lee <koonwen.lee@ahrefs.com>"
 "Ahrefs <github@ahrefs.com>")

(maintainers
 "Koonwen Lee <koonwen.lee@ahrefs.com>"
 "Ahrefs <github@ahrefs.com>")

(license MIT)

(documentation "https://github.com/ahrefs/basecamp")

(package
 (name basecamp)
 (synopsis "Basecamp client library")
 (depends
   ocaml
   ocurl
   containers
   devkit
   dune
   lwt
   lwt_ppx
   ptime
   uri
   re
   stringext
   melange-json-native
   ppx_deriving
  (yojson :with-test)
  (ocamlformat :with-dev-setup)
  (ocaml-lsp-server :with-dev-setup))
 (tags
  (basecamp "org:ahrefs")))
