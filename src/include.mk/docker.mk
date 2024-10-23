# docker.mk
# Install docker
# By J. Stuart McMurray
# Created 20241009
# Last Modified 20241020

DOCKER = /usr/bin/docker

# Install docker, for when we just need to test something and can't remember
# the path to the docker binary.
install_docker: ${DOCKER}
.PHONY: install_docker

${DOCKER}: /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.asc
	${APTGET}\
		install\
		docker-ce\
		docker-ce-cli\
		containerd.io\
		docker-buildx-plugin\
		docker-compose-plugin
	${DOCKER} run --quiet --rm hello-world >/dev/null
	touch $@
/etc/apt/sources.list.d/docker.list: /etc/apt/keyrings/docker.asc
	{\
		echo -n "deb [arch=$$(dpkg --print-architecture) ";\
		echo -n "signed-by=/etc/apt/keyrings/docker.asc] ";\
		echo -n "https://download.docker.com/linux/debian ";\
		echo -n "$$(. /etc/os-release && echo "$$VERSION_CODENAME") ";\
		echo "stable";\
	} > $@
	${APTGET} update
/etc/apt/keyrings/docker.asc: ${CURL}
	install -m 0755 -d ${@:H}
	curl -fsSL -o $@ https://download.docker.com/linux/debian/gpg
	chmod a+r $@
