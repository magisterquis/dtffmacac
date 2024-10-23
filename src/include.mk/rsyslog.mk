# rsyslog.mk
# Install rsyslog
# By J. Stuart McMurray
# Created 20241019
# Last Modified 20241024

SYSLOG ?= /var/log/syslog

${SYSLOG}:
	${APTGET} install rsyslog
	@# Wait for it to start
	while ! [ -f $@ ]; do sleep .1; done


