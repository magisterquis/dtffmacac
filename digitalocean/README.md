DigitalOcean
============
This makefile is meant to create and manage a DigitalOcean Droplet.

Created Droplets will be created with the name `dtffmacac`, tagged with the
tag `dtffmacac`, and use key named `dtffmacac` (which is expected to correspond
to `~/.ssh/id_ed25519_dtffmacac`).

Useful targets
--------------

Target      | Description
------------|------------
`clean`     | Removes the Droplet as well as Droplet-specific files.
`distclean` | `clean` but also removes all generated files and `run.sh`.
`run`       | Sync up this repository if needed and run the command in `run.sh`, which will contain `make test` by default.
`ssh`       | SSH to the Droplet.
`sync`      | Sync code to the droplet.

`run`, `ssh`, and `sync` will cause a Droplet to be created if one hasn't been
already.
