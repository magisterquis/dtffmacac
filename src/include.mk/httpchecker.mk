# httpchecker.mk
# Build the HTTP Checker
# By J. Stuart McMurray
# Created 20241009
# Last Modified 20241019

HTTPCHECKERNAME    = httpchecker
HTTPCHECKERBIN     = ${LOCAL}/httpchecker
HTTPCHECKERIMAGE   = ${LOCAL}/httpchecker.image
HTTPCHECKERPID     = ${LOCAL}/httpchecker.pid
HTTPCHECKERSRCDIR  = ${CONTAINERSRCDIR}/httpchecker

HTTPCHECKERISALIVE = [ -n "$$( ${DOCKER} ps\
		         	     --quiet\
		         	     --filter name=${HTTPCHECKERNAME} )" ]
HTTPCHECKERSTOP   = ! ${HTTPCHECKERISALIVE} || {\
		${DOCKER} kill ${HTTPCHECKERNAME};\
		while ${HTTPCHECKERISALIVE}; do sleep .1; done;\
	}; rm -f ${HTTPCHECKERPID}

HTTPCHECKERSECRET   = ${LOCAL}/httpchecker_secret
HTTPCHECKERISP      = ${LOCAL}/httpchecker_internal_service_password
HTTPCHECKERBACREDS  = ${LOCAL}/httpchecker_basicauth_creds
HTTPCHECKERFLAG     = ${LOCAL}/httpchecker.flag
HTTPCHECKERSTARTER  = ${LOCAL}/httpcheckerstart.sh

# Don't assume httpchecker is running
.BEGIN:: httpchecker_begin
httpchecker_begin:
	@pidof -q ${HTTPCHECKERNAME} || rm -f ${HTTPCHECKERPID}
	@if ! [ -e ${DOCKER} ] ||\
		[ -z $$(${DOCKER} image ls --quiet ${HTTPCHECKERNAME}) ];\
	then\
		rm -f ${HTTPCHECKERIMAGE};\
	fi
.PHONY: httpchecker_begin

# Build the HTTP Checker binary
${HTTPCHECKERBIN}: ${GO} ${HTTPCHECKERSRCDIR}/*.go go_test
	${GO} build ${GOBUILDFLAGS} -o $@ ${>:M*.go}

# Build the HTTP Checker container image
${HTTPCHECKERIMAGE}: ${DOCKER} ${HTTPCHECKERBIN} ${HTTPCHECKERBACREDS}
${HTTPCHECKERIMAGE}: ${HTTPCHECKERSECRET} ${HTTPCHECKERISP}
${HTTPCHECKERIMAGE}: ${HTTPCHECKERSRCDIR}/Dockerfile ${HTTPCHECKERFLAG}
${HTTPCHECKERIMAGE}: ${HTTPCHECKERSTARTER}
	${DOCKER} build\
		--build-arg BA_CREDENTIALS=$$(cat ${HTTPCHECKERBACREDS})\
		--build-arg INTERNAL_SERVICE_PASS=$$(cat ${HTTPCHECKERISP})\
		--build-arg LOCAL=${LOCAL}\
		--file ${>:M*Dockerfile}\
		--quiet\
		--tag ${HTTPCHECKERNAME}\
		.
	date > $@

# A secret to mount inside the docker container
.for F in ${HTTPCHECKERSECRET} ${HTTPCHECKERISP} ${HTTPCHECKERBACREDS} \
	${HTTPCHECKERFLAG} ${HTTPCHECKERSTARTER}
$F: ${HTTPCHECKERSRCDIR}/${F:T}
	cp $> $@
.endfor

# (Re)start the HTTP Checker container
${HTTPCHECKERPID}: ${DOCKER} ${HTTPCHECKERIMAGE}
${HTTPCHECKERPID}: ${HTTPCHECKERSECRET} ${SYSLOG}
	${HTTPCHECKERSTOP}
	${DOCKER} run\
		--detach\
		--init\
		--log-driver syslog\
		--log-opt tag=${HTTPCHECKERNAME}\
		--name ${HTTPCHECKERNAME}\
		--privileged\
		--publish 0.0.0.0:4444:4444\
		--quiet\
		--rm\
		--volume ${HTTPCHECKERSECRET}:/run/secrets/api_key:ro\
		${HTTPCHECKERNAME}
	while ${HTTPCHECKERISALIVE} &&\
		! pidof ${HTTPCHECKERNAME} >/dev/null; do\
		sleep .1;\
	done
	pidof ${HTTPCHECKERNAME} >$@ || ( rm -f $@; exit 1)
.PHONY: restart_httpchecker


# Stop the container if it's running
stop_httpchecker:
	${HTTPCHECKERSTOP}
.PHONY: stop_httpchecker

# Remove our image on clean
clean:: clean_httpchecker
clean_httpchecker: stop_httpchecker
	${DOCKER} image rm --force ${HTTPCHECKERNAME}
	rm -f ${HTTPCHECKERIMAGE}
.PHONY: clean_httpchecker
