# flags.mk
# Add non-container flag(s?)
# By J. Stuart McMurray
# Created 20241015
# Last Modified 20241015

FLAGSSRC=${SRCDIR}/flags
ESCAPEDFLAG = /var/run/escaped.flag
DELETEDFLAG=${LOCAL}/deleted.flag
DELETEDFLAGPID=${DELETEDFLAG}.pid
DELETEDFLAGTMP=/tmp/${DELETEDFLAG:T}

# Work out whether or not we have a flag in a deleted file
.BEGIN:: flags_begin
flags_begin:
	@(ls -l /proc/*/fd/* 2>/dev/null | grep -q ${DELETEDFLAGTMP}) ||\
		rm -f ${DELETEDFLAGPID};
.PHONY: flags_begin

# List of flgas to be built
flags: ${ESCAPEDFLAG} ${DELETEDFLAGPID}
.PHONY: flags

# "Easy" flag found when escaping
${LOCAL}/${ESCAPEDFLAG:T}: ${FLAGSSRC}/${ESCAPEDFLAG:T}
	cp $> $@
${ESCAPEDFLAG}: ${LOCAL}/${ESCAPEDFLAG:T}
	cp $> $@

# Flag which can't be found by just mounting the disk.
${DELETEDFLAGPID}: ${DELETEDFLAG}
	cp ${DELETEDFLAG} ${DELETEDFLAGTMP}
	echo 'echo "$$$$" > ${PWD}/$@ && while :; do sleep 1024; done' |\
		sh >>${DELETEDFLAGTMP} 2>&1 &
	while [ ! -f $@ ]; do sleep .1; done
	rm ${DELETEDFLAGTMP}
${DELETEDFLAG}: ${FLAGSSRC}/${DELETEDFLAG:T}
	cp $> $@

