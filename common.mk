metalinter_version   := v2.0.0
m3linters_version    := 294ebc8b60b6758a4fe1b0921fb10630db16a5bf
mockclean_version    := 3e9c30b229f100027d742104ad6d6b2d968374bd
genny_version        := 9d8700bcc567cd22ea2ef42ce5835a9c80296c4a
coverfile            := cover.out
coverage_exclude     := .excludecoverage
coverage_xml         := coverage.xml
coverage_html        := coverage.html
junit_xml            := junit.xml
convert_test_data    := .ci/convert-test-data.sh
test                 := .ci/test-cover.sh
test_big             := .ci/test-big-cover.sh
test_one_integration := .ci/test-one-integration.sh
test_ci_integration  := .ci/test-integration.sh
test_log             := test.log
codecov_push         := .ci/codecov.sh

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
		git checkout $(m3linters_version) && go install && git checkout master)
	@which badtime > /dev/null || (echo "badtime install failed" && exit 1)

install-linter-importorder:
	@which importorder > /dev/null || (go get -u github.com/m3db/build-tools/linters/importorder && \
		cd $(GOPATH)/src/github.com/m3db/build-tools/linters/importorder && \
		git checkout $(m3linters_version) && go install && git checkout master)
	@which importorder > /dev/null || (echo "importorder install failed" && exit 1)

install-util-mockclean:
	@which mockclean > /dev/null || (go get -u github.com/m3db/build-tools/utilities/mockclean && \
		cd $(GOPATH)/src/github.com/m3db/build-tools/utilities/mockclean && \
		git checkout $(mockclean_version) && go install)
	@which mockclean > /dev/null || (echo "mockclean install failed" && exit 1)

install-generics-bin:
	@which genny > /dev/null || (go get -u github.com/mauricelam/genny && \
		cd $(GOPATH)/src/github.com/mauricelam/genny && \
		git checkout $(genny_version) && \
		go install)
	@which genny > /dev/null || (echo "genny install failed" && exit 1)

test-base:
	@which go-junit-report > /dev/null || go get -u github.com/sectioneight/go-junit-report
	$(test) $(coverfile) $(coverage_exclude) | tee $(test_log)

test-big-base:
	@which go-junit-report > /dev/null || go get -u github.com/sectioneight/go-junit-report
	$(test_big) $(coverfile) $(coverage_exclude) | tee $(test_log)

test-base-xml: test-base
	go-junit-report < $(test_log) > $(junit_xml)
	gocov convert $(coverfile) | gocov-xml > $(coverage_xml)
	@$(convert_test_data) $(coverage_xml)
	@rm $(coverfile) &> /dev/null

test-base-html: test-base
	gocov convert $(coverfile) | gocov-html > $(coverage_html) && (which open && open $(coverage_html))
	@rm -f $(test_log) &> /dev/null

test-base-integration:
	go test -v -tags=integration ./integration

# Usage: make test-base-single-integration name=<test_name>
test-base-single-integration:
	$(test_one_integration) $(name)

test-base-ci-unit: test-base
	@which goveralls > /dev/null || go get -u -f github.com/m3db/goveralls
	goveralls -coverprofile=$(coverfile) -service=semaphore || (echo -e "Coveralls failed" && exit 1)

test-base-ci-integration:
	$(test_ci_integration) $(coverfile) $(coverage_exclude)
