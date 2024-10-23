# Makefile
# Spins up and tests container infrastructure for the demos
# By J. Stuart McMurray
# Created 20241007
# Last Modified 20241024

# LOCAL may be used to store intermediary files between invocations.
SRCDIR           = ./src
APTGET           = DEBIAN_FRONTEND=noninteractive >/dev/null apt-get -y -qq\
		   -o DPkg::Lock::Timeout=-1
CONTAINERSRCDIR  = ${SRCDIR}/containers
CURL             = /usr/bin/curl
GOBUILDFLAGS     = -trimpath -ldflags "-w -s"
GOSOURCES       != find . -name '*.go'
LOCAL            =./local
PERLSSL          = /usr/share/perl5/IO/Socket/SSL.pm
PROVE            = /usr/bin/prove
TESTS           != find ./t -type f
SYSLOG           = /var/log/syslog

# Add in other makefiles
INCS != ls ./src/include.mk/*.mk
.for INC in ${INCS}
.include "${INC}"
.endfor

.MAIN: test

.BEGIN::
	@mkdir -p ${LOCAL}

# Tests
test: ${PROVE} ${HTTPCHECKERPID} ${PASSWORDSTOREPID} ${TESTS} flags
	${PROVE} -I t/lib
.PHONY: test
${TESTS}: ${PERLSSL} 

# Install various programs and such
${PROVE}:
	${APTGET} install perl
${CURL}:
	${APTGET} install ca-certificates curl
${PERLSSL}:
	${APTGET} install libio-socket-ssl-perl

clean::
	rm -rf ${LOCAL}
.PHONY: clean
