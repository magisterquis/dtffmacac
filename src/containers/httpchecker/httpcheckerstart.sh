#!/bin/sh
# httpcheckerstart.sh
# Start our container going
# By J. Stuart McMurray
# Created 20241017
# Last Modified 20241017

set -e

# Remove this file
rm $0

# Remove disk files
awk '4==NF && !/major/ {system("rm -v /dev/" $4)}' /proc/partitions

# Start the HTTP Checker itself
exec /httpchecker -credentials ${BA_CREDENTIALS}
