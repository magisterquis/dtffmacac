# go.mk
# Install Go
# By J. Stuart McMurray
# Created 20241009
# Last Modified 20241019

GO          = ${_GOPATH}/go/bin/go
STATICCHECK = ${_GOPATH}/bin/staticcheck
_GOPATH     = ${HOME}/go

# Go compiler
${GO}: ${CURL}
	mkdir -p $@
	${CURL} -sfL https://dl.google.com/go/$$(\
		${CURL} -sfL 'https://go.dev/VERSION?m=text' | head -n 1\
	).linux-${MACHINE_ARCH}.tar.gz  | tar -C "${_GOPATH}" -xzf -
	echo "export PATH=$$PATH:$$(\
		$@ env GOROOT\
	)/bin:$$(\
		$@ env GOPATH\
	)/bin" >> ${HOME}/.bashrc
	touch $@
${STATICCHECK}: ${GO}
	${GO} install honnef.co/go/tools/cmd/staticcheck@latest
	#
# Make sure all the Go code is solid
go_test: ${GO} ${STATICCHECK} .USE
	${GO} test ${GOBUILDFLAGS} -timeout 10s ${>:M*.go:H}
	${GO} vet  ${GOBUILDFLAGS} ${>:M*.go:H}
.if ${PATH:S/${_GOPATH}//} == ${PATH}
	. ~/.bashrc; ${STATICCHECK} ${>:M*.go:H}
.else
	${STATICCHECK} ${>:M*.go:H}
.endif
