metalinter_version 	:= 0262fb20957a4c2d3bb7c834a6a125ae3884a2c6
maptime_version 		:= a3f8910440bba296b90fd559b425009981c8bcb8

install-vendor: install-glide
	@echo Installing glide deps
	glide --debug install

install-glide:
		@which glide > /dev/null || (go get -u github.com/Masterminds/glide && cd $(GOPATH)/src/github.com/Masterminds/glide && git checkout v0.12.3 && go install)
		@glide -version > /dev/null || (echo "Glide install failed" && exit 1)

install-ci:
	make install-vendor

install-metalinter-internal:
	@which gometalinter > /dev/null || (go get -u github.com/alecthomas/gometalinter && \
		cd $(GOPATH)/src/github.com/alecthomas/gometalinter && \
		git checkout $(metalinter_version) && \
		go install && gometalinter --install)
	@which gometalinter > /dev/null || (echo "gometalinter install failed" && exit 1)

install-linter-maptime:
	@which maptime > /dev/null || (go get -u github.com/m3db/build-tools/linters/maptime && \
		cd $(GOPATH)/src/github.com/m3db/build-tools/linters/maptime && \
		git checkout $(maptime_version) && go install)
	@which maptime > /dev/null || (echo "maptime install failed" && exit 1)
