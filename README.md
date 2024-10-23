Demystifying the First Few Minutes after Compromising a Container
=================================================================
Material for a talk

Put the contents of this Archive on a Debian 12 box, grab bmake, cd in, and run
`bmake`.

Probably best to use a separate box as it kinda takes over :/

This code.  It's not good.

Infrastructure
--------------
Developed and Tested on Debian 12.  The [`digitalocean`](./digitalocean)
directory has a [Makefile](./digitalocean/Makefile) for spinning up and setting
up a DigitalOcean Droplet.

Initial Access
--------------
A service will be listening for HTTPS connections on port 4444 with a
self-signed certificate.

Username: `checker`
Password: `s3cr3t_p4ssw0rd`

Flags
-----
There are three flags in the environment, all with filenames ending in `.flag`.