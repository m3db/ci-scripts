
install-vendor: install-glide
	@echo Installing glide deps
	glide --debug install

HAS_GLIDE := $(glide -version 2>&1 > /dev/null)

install-glide:
ifdef HAS_GLIDE
	go get -u github.com/Masterminds/glide && cd $(GOPATH)/src/github.com/Masterminds/glide && git checkout v0.12.3 && go install
endif
	@glide -version > /dev/null || echo "Glide install failed"

install-ci:
	make install-vendor

