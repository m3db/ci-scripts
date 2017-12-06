metalinter_version  := v2.0.0
badtime_version     := a1d80fa39058e2de323bf0b54d47bfab92e9a97f

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
