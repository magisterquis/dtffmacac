Password Store
==============
Example service which stores passwords.

Something like a legacy program written by some long-lost dev and wrapped in a
TLS's, containered frontend.

Send it an HTTP request with basic auth with any username and the password in
`passwordstore_password` and a path like `/password_name` and the password
named `password_name` will (hopefully) be returned.

Passwords are put in `passwords.fs` as Forth words named the password name
which print out the password and a newline.

It also doubles as an target for password timing attacks.
