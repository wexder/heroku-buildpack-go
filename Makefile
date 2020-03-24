TMP := ''
IMAGE := heroku/heroku:16-build
BASH_COMMAND := /bin/bash
GO_BUCKET_URL := file:///buildpack/test/assets

.PHONY: test test-v2 shell quick publish docker test-assets
.DEFAULT: test
.NOTPARALLEL: docker test-assets

sync:
	./sbin/sync-files.sh

test: BASH_COMMAND := test/run.sh
test: docker

test-v2: BASH_COMMAND := test/run-v2.sh
test-v2: IMAGE := heroku/heroku:18-build
test-v2: docker

shell: docker

quick: BASH_COMMAND := test/quick.sh; bash
quick: docker

# make FIXTURE=<fixture name> ENV=<FOO=BAR> compile
compile: BASH_COMMAND := test/quick.sh compile $(FIXTURE) $(ENV); bash
compile: docker

testpack: BASH_COMMAND := test/quick.sh dotest $(FIXTURE) $(ENV); bash
testpack: docker

publish:
	@bash sbin/publish.sh

docker: test-assets
	$(eval TMP := $(shell sbin/copy true))
	@echo "Running docker ($(IMAGE)) with /buildpack=$(TMP) ..."
	@docker pull $(IMAGE)
	@docker run -v $(TMP):/buildpack:ro --rm -it -e "GITLAB_TOKEN=$(GITLAB_TOKEN)" -e "GITHUB_TOKEN=$(GITHUB_TOKEN)" -e "GO_BUCKET_URL=$(GO_BUCKET_URL)" -e "GO_DOWNLOAD_BASE=$(GO_DOWNLOAD_BASE)" -e "IMAGE=$(IMAGE)" $(IMAGE) bash -c "cd /buildpack; $(BASH_COMMAND)"
	@rm -rf $(TMP)

test-assets:
	@echo "Setting up test assets"
	@sbin/fetch-test-assets
