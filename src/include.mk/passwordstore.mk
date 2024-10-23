# passwordstore.mk
# Build the password store
# By J. Stuart McMurray
# Created 20241019
# Last Modified 20241021

PASSWORDSTORENAME        = passwordstore
PASSWORDSTOREBIN         = ${LOCAL}/${PASSWORDSTORENAME}
PASSWORDSTOREFINGERPRINT = tls_fingerprint
PASSWORDSTOREIMAGE       = ${LOCAL}/${PASSWORDSTORENAME}.image
PASSWORDSTOREPID         = ${LOCAL}/${PASSWORDSTORENAME}.pid
PASSWORDSTORESRCDIR      = ${CONTAINERSRCDIR}/${PASSWORDSTORENAME}

PASSWORDSTOREISALIVE = [ -n "$$( ${DOCKER} ps\
		         	     --quiet\
		         	     --filter name=${PASSWORDSTORENAME} )" ]
PASSWORDSTORESTOP    = ! ${PASSWORDSTOREISALIVE} || {\
		${DOCKER} kill ${PASSWORDSTORENAME};\
		while ${PASSWORDSTOREISALIVE}; do sleep .1; done;\
	}; rm -f ${PASSWORDSTOREPID}

PASSWORDSTOREFSRC      = ${LOCAL}/${PASSWORDSTORENAME}.fs
PASSWORDSTOREPASSWORD  = ${LOCAL}/${PASSWORDSTORENAME}_password
PASSWORDSTOREPASSWORDS = ${LOCAL}/passwords.fs
PASSWORDSTORESTARTER   = ${LOCAL}/${PASSWORDSTORENAME}start.sh

# Don't assume passwordstore is running
.BEGIN:: passwordstore_begin
passwordstore_begin:
	@pidof -q ${PASSWORDSTORENAME} || rm -f ${PASSWORDSTOREPID}
	@if ! [ -e ${DOCKER} ] ||\
		[ -z $$(${DOCKER} image ls --quiet ${PASSWORDSTORENAME}) ];\
	then\
		rm -f ${PASSWORDSTOREIMAGE};\
	fi
.PHONY: passwordstore_begin

# Build the passwordstore binary
${PASSWORDSTOREBIN}: ${GO} ${PASSWORDSTORESRCDIR}/*.go go_test
	${GO} build ${GOBUILDFLAGS} -o $@ ${>:M*.go}

# Build the HTTP Checker container image
${PASSWORDSTOREIMAGE}: ${DOCKER} ${PASSWORDSTOREBIN}
${PASSWORDSTOREIMAGE}: ${PASSWORDSTORESRCDIR}/Dockerfile
${PASSWORDSTOREIMAGE}: ${PASSWORDSTORESTARTER} ${PASSWORDSTOREFSRC}
${PASSWORDSTOREIMAGE}: ${PASSWORDSTOREPASSWORDS} ${PASSWORDSTOREPASSWORD}
	${DOCKER} build\
		--build-arg LOCAL=${LOCAL}\
		--file ${>:M*Dockerfile}\
		--quiet\
		--tag ${PASSWORDSTORENAME}\
		.
	date > $@
	
# Copy things to local/
.for F in ${PASS} ${PASSWORDSTOREFSRC} ${PASSWORDSTOREPASSWORDS}\
	${PASSWORDSTORESTARTER} ${PASSWORDSTOREPASSWORD}
$F: ${PASSWORDSTORESRCDIR}/${F:T}
	cp $> $@
.endfor

# (Re)start the Passwordstore  container
${PASSWORDSTOREPID}: ${DOCKER} ${PASSWORDSTOREIMAGE}
${PASSWORDSTOREPID}: ${PASSWORDSTORESECRET} ${SYSLOG}
	${PASSWORDSTORESTOP}
	${DOCKER} run\
		--detach\
		--init\
		--log-driver syslog\
		--log-opt tag=${PASSWORDSTORENAME}\
		--name ${PASSWORDSTORENAME}\
		--publish 127.0.0.1:5555:5555\
		--quiet\
		--rm\
		${PASSWORDSTORENAME}
	while ${PASSWORDSTOREISALIVE} && ! [ -f\
		/proc/$$(\
			pidof ${PASSWORDSTORENAME}\
		)/root/${PASSWORDSTOREFINGERPRINT}\
	]; do\
		sleep .1;\
	done
	pidof ${PASSWORDSTORENAME} >$@ || ( rm -f $@; exit 1)
.PHONY: restart_passwordstore
	
# Stop the container if it's running
stop_passwordstore:
	${PASSWORDSTORESTOP}
.PHONY: stop_passwordstore

# Remove our image on clean
clean:: clean_passwordstore
clean_passwordstore: stop_passwordstore
	${DOCKER} image rm --force ${PASSWORDSTORENAME}
	rm -f ${PASSWORDSTOREIMAGE}
.PHONY: clean_passwordstore
