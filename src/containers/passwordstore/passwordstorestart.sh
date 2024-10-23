#!/bin/bash
#
# passwordstore.sh
# Start the password store bits going
# By J. Stuart McMurray
# Created 20241019
# Last Modified 20241019

set -e

# Start the frontend going
{ PATH=.:$PATH exec passwordstore & } | cat

# Start our frontend going
exec gforth passwords.fs passwordstore.fs >/dev/tcp/127.0.0.1/9999 <&1
