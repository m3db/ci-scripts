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
		go install github.com/alecthomas/gometalinter && gometalinter --install)
	@which gometalinter > /dev/null || (echo "gometalinter install failed" && exit 1)
