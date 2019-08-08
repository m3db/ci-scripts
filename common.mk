GOPATH=$(shell eval $$(go env | grep GOPATH) && echo $$GOPATH)
metalinter_version   := v2.0.0
m3linters_version    := 3414a73aff9004cba439f1657dcd70c514d2b67a
genclean_version     := 3414a73aff9004cba439f1657dcd70c514d2b67a
genny_version        := 9d8700bcc567cd22ea2ef42ce5835a9c80296c4a
coverfile            := cover.out
coverage_exclude     := .excludecoverage
coverage_html        := coverage.html
convert_test_data    := .ci/convert-test-data.sh
test                 := .ci/test-cover.sh
test_big             := .ci/test-big-cover.sh
test_one_integration := .ci/test-one-integration.sh
test_ci_integration  := .ci/test-integration.sh
test_log             := test.log
codecov_push         := .ci/codecov.sh


.PHONY: validate-gopath
validate-gopath:
	@stat $(GOPATH) > /dev/null

install-vendor: install-glide validate-gopath
	# collapse in buildkite by default
	@echo "--- Install glide deps"
	@echo "Installing glide deps"
	PATH=$(GOPATH)/bin:$(PATH) GOPATH=$(GOPATH) glide --debug install

install-glide:
		@PATH=$(GOPATH)/bin:$(PATH) which glide > /dev/null || (go get github.com/Masterminds/glide && cd $(GOPATH)/src/github.com/Masterminds/glide && git checkout v0.12.3 && go install)
		@PATH=$(GOPATH)/bin:$(PATH) glide -version > /dev/null || (echo "Glide install failed" && exit 1)

# Not all SEMAPHORE instances have large amounts of memory. Enabling swap to
# compesate for the lack of. This conditional tests an environmental variable
# injected into SEMAPHORE instances, https://semaphoreci.com/docs/available-environment-variables.html
prep-semaphore:
	if [[ -v SEMAPHORE ]]; then sudo swapoff -a && sudo fallocate -l 8G /swapfile && sudo mkswap /swapfile && sudo chmod 0600 /swapfile && sudo swapon /swapfile; fi

install-ci:
	make prep-semaphore # test to see if running on SEMAPHORE instance
	make install-vendor

install-metalinter:
	@PATH=$(GOPATH)/bin:$(PATH) which gometalinter > /dev/null || (go get -u github.com/alecthomas/gometalinter && \
		cd $(GOPATH)/src/github.com/alecthomas/gometalinter && \
		git checkout $(metalinter_version) && \
		go install && gometalinter --install)
	@PATH=$(GOPATH)/bin:$(PATH) which gometalinter > /dev/null || (echo "gometalinter install failed" && exit 1)

install-linter-badtime:
	@PATH=$(GOPATH)/bin:$(PATH) which badtime > /dev/null || (go get -u github.com/m3db/build-tools/linters/badtime && \
		cd $(GOPATH)/src/github.com/m3db/build-tools/linters/badtime && \
		git checkout $(m3linters_version) && go install && git checkout master)
	@PATH=$(GOPATH)/bin:$(PATH) which badtime > /dev/null || (echo "badtime install failed" && exit 1)

install-linter-importorder:
	@PATH=$(GOPATH)/bin:$(PATH) which importorder > /dev/null || (go get -u github.com/m3db/build-tools/linters/importorder && \
		cd $(GOPATH)/src/github.com/m3db/build-tools/linters/importorder && \
		git checkout $(m3linters_version) && go install && git checkout master)
	@PATH=$(GOPATH)/bin:$(PATH) which importorder > /dev/null || (echo "importorder install failed" && exit 1)

install-util-genclean:
	@PATH=$(GOPATH)/bin:$(PATH) which genclean > /dev/null || (go get -u github.com/m3db/build-tools/utilities/genclean && \
		cd $(GOPATH)/src/github.com/m3db/build-tools/utilities/genclean && \
		git checkout $(genclean_version) && go install)
	@PATH=$(GOPATH)/bin:$(PATH) which genclean > /dev/null || (echo "genclean install failed" && exit 1)

install-generics-bin:
	@PATH=$(GOPATH)/bin:$(PATH) which genny > /dev/null || (go get -u github.com/mauricelam/genny && \
		cd $(GOPATH)/src/github.com/mauricelam/genny && \
		git checkout $(genny_version) && \
		go install)
	@PATH=$(GOPATH)/bin:$(PATH) which genny > /dev/null || (echo "genny install failed" && exit 1)

test-base:
	$(test) $(coverfile) $(coverage_exclude) | tee $(test_log)

test-big-base:
	$(test_big) $(coverfile) $(coverage_exclude) | tee $(test_log)

test-base-html: test-base
	gocov convert $(coverfile) | gocov-html > $(coverage_html) && (PATH=$(GOPATH)/bin:$(PATH) which open && open $(coverage_html))
	@rm -f $(test_log) &> /dev/null

test-base-integration:
	go test -v -tags=integration ./integration

# Usage: make test-base-single-integration name=<test_name>
test-base-single-integration:
	$(test_one_integration) $(name)

test-base-ci-unit: test-base
	@PATH=$(GOPATH)/bin:$(PATH) which goveralls > /dev/null || go get -u -f github.com/m3db/goveralls
	PATH=$(GOPATH)/bin:$(PATH) goveralls -coverprofile=$(coverfile) -service=semaphore || (echo -e "Coveralls failed" && exit 1)

test-base-ci-integration:
	$(test_ci_integration) $(coverfile) $(coverage_exclude)
