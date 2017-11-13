metalinter_version  := 0262fb20957a4c2d3bb7c834a6a125ae3884a2c6
badtime_version     := d5c312d05ed78e5032805b9eb5acb37ae13d8d91>>>>>>> Update badtime

install-vendor: install-glide
	@echo Installing glide deps
	glide --debug install

install-glide:
		@which glide > /dev/null || (go get -u github.com/Masterminds/glide && cd $(GOPATH)/src/github.com/Masterminds/glide && git checkout v0.12.3 && go install)
		@glide -version > /dev/null || (echo "Glide install failed" && exit 1)

install-ci:
	make install-vendor

install-metalinter:
	@which gometalinter > /dev/null || (go get -u github.com/alecthomas/gometalinter && \
		cd $(GOPATH)/src/github.com/alecthomas/gometalinter && \
		git checkout $(metalinter_version) && \
		go install && gometalinter --install)
	@which gometalinter > /dev/null || (echo "gometalinter install failed" && exit 1)

install-linter-badtime:
	@which badtime > /dev/null || (go get -u github.com/m3db/build-tools/linters/badtime && \
		cd $(GOPATH)/src/github.com/m3db/build-tools/linters/badtime && \
		git checkout $(badtime_version) && go install)
	@which badtime > /dev/null || (echo "badtime install failed" && exit 1)
