# Makefile for podman
# See docs/make.md for usage

export GOPROXY ?= https://proxy.golang.org

GO ?= go
GOFLAGS ?= -trimpath
GOTAGS ?= $(shell hack/btrfs_tag.sh) $(shell hack/btrfs_installed_tag.sh) $(shell hack/ostree_tag.sh) $(shell hack/selinux_tag.sh) $(shell hack/systemd_tag.sh) $(shell hack/libsubid_tag.sh)

GIT_COMMIT ?= $(shell git rev-parse HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
BUILD_INFO ?= $(shell date +%s)
IMPORT_PATH := github.com/containers/podman

LDFLAGS_PODMAN ?= \
	-X $(IMPORT_PATH)/libpod/define.gitCommit=$(GIT_COMMIT) \
	-X $(IMPORT_PATH)/libpod/define.buildInfo=$(BUILD_INFO)

BINDIR ?= $(CURDIR)/bin
MANDIR ?= /usr/share/man
INSTALL ?= install
INSTALL.PROGRAM ?= $(INSTALL) -m 755
INSTALL.DATA ?= $(INSTALL) -m 644

PODMAN_VERSION ?= $(shell cat version/version.go | grep 'Version = ' | awk '{print $$3}' | tr -d '"')

.PHONY: all
all: binaries

.PHONY: binaries
binaries: podman podman-remote ## Build podman and podman-remote binaries

.PHONY: podman
podman: ## Build the podman binary
	$(GO) build \
		$(GOFLAGS) \
		-tags "$(GOTAGS)" \
		-ldflags "$(LDFLAGS_PODMAN)" \
		-o $(BINDIR)/podman \
		./cmd/podman

.PHONY: podman-remote
podman-remote: ## Build the podman-remote binary
	$(GO) build \
		$(GOFLAGS) \
		-tags "$(GOTAGS) remote" \
		-ldflags "$(LDFLAGS_PODMAN)" \
		-o $(BINDIR)/podman-remote \
		./cmd/podman

.PHONY: test
test: unit integration ## Run all tests

.PHONY: unit
unit: ## Run unit tests
	$(GO) test -tags "$(GOTAGS)" ./...

.PHONY: integration
integration: ## Run integration tests
	$(GO) test -tags "$(GOTAGS) integration" -v ./test/...

.PHONY: lint
lint: ## Run golangci-lint
	golangci-lint run --timeout 10m

.PHONY: vendor
vendor: ## Update vendor directory
	$(GO) mod tidy
	$(GO) mod vendor
	$(GO) mod verify

.PHONY: install
install: ## Install podman binary
	$(INSTALL.PROGRAM) $(BINDIR)/podman $(DESTDIR)/usr/bin/podman

.PHONY: install.man
install.man: ## Install man pages
	$(INSTALL) -d $(DESTDIR)$(MANDIR)/man1
	$(INSTALL.DATA) docs/build/man/*.1 $(DESTDIR)$(MANDIR)/man1/

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf $(BINDIR)
	# Note: intentionally not removing vendor/ here to avoid slow re-downloads
	# run 'make vendor-clean' to also wipe the vendor directory

.PHONY: vendor-clean
vendor-clean: clean ## Remove build artifacts including vendor directory
	rm -rf vendor/

.PHONY: fmt
fmt: ## Format Go source files
	$(GO) fmt ./...

.PHONY: version
version: ## Print the current version
	@echo $(PODMAN_VERSION)

.PHONY: help
help: ## Display this help text
	@grep -E '^[a-zA-Z_/-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' | \
		sort
