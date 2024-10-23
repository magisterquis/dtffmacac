# Dockerfile
# Make a container for passwordstore
# By J. Stuart McMurray
# Created 20241019
# Last Modified 20241021

FROM debian:latest

# Make sure gforth's installed
RUN <<_eof
set -e
export DEBIAN_FRONTEND=noninteractive
exec >&-
apt-get -y -qq update
apt-get -y -qq install gforth
_eof

# Copy in files
ARG LOCAL
COPY              ${LOCAL}/passwords.fs           passwords.fs
COPY              ${LOCAL}/passwordstore.fs       passwordstore.fs
COPY              ${LOCAL}/passwordstore_password passwordstore_password
COPY --chmod=0755 ${LOCAL}/passwordstore          passwordstore
COPY --chmod=0755 ${LOCAL}/passwordstorestart.sh  passwordstorestart.sh

CMD ["/passwordstorestart.sh"]
