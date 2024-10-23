# Dockerfile
# Make a container for httpchecker
# By J. Stuart McMurray
# Created 20241011
# Last Modified 20241019

FROM debian:latest

# Add our server binary
ARG LOCAL
COPY ${LOCAL}/httpchecker /httpchecker

# Make sure curl's installed
RUN <<_eof
set -e
export DEBIAN_FRONTEND=noninteractive
exec >&-
apt-get -y -qq update
apt-get -y -qq install curl
_eof

# Add a couple of passwords
ARG BA_CREDENTIALS
ENV BA_CREDENTIALS=${BA_CREDENTIALS}
ARG INTERNAL_SERVICE_PASS
ENV INTERNAL_SERVICE_PASS=${INTERNAL_SERVICE_PASS}

# Add in a flag andthe script to start it all
COPY ${LOCAL}/httpchecker.flag /usr/lib
COPY --chown=root:root --chmod=0700 ${LOCAL}/httpcheckerstart.sh /

CMD ["/httpcheckerstart.sh"]
