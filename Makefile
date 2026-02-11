# SMTP-Tunnel Makefile
.PHONY: all clean build release install uninstall test

VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "none")
DATE := $(shell date -u +%Y%m%d%H%M%S)

GO := go
LDFLAGS := -ldflags="-s -w -X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.date=$(DATE)"
CGO_ENABLED := 0

all: clean deps test build

deps:
	$(GO) mod download
	$(GO) mod verify

build: build-client build-server build-tools

build-client:
	CGO_ENABLED=$(CGO_ENABLED) $(GO) build $(LDFLAGS) -o bin/smtp-tunnel-client ./cmd/client

build-server:
	CGO_ENABLED=$(CGO_ENABLED) $(GO) build $(LDFLAGS) -o bin/smtp-tunnel-server ./cmd/server

build-tools:
	CGO_ENABLED=$(CGO_ENABLED) $(GO) build -o bin/smtp-tunnel-certgen ./cmd/tools/certgen

test:
	$(GO) test -v -race ./...

clean:
	rm -rf bin/ dist/
	$(GO) clean

install: build
	sudo install -m 755 bin/smtp-tunnel-client /usr/local/bin/
	sudo install -m 755 bin/smtp-tunnel-server /usr/local/bin/

uninstall:
	sudo rm -f /usr/local/bin/smtp-tunnel-client
	sudo rm -f /usr/local/bin/smtp-tunnel-server

release: test
	mkdir -p dist
	tar czf dist/smtp-tunnel-$(VERSION).tar.gz bin/
	cd dist && sha256sum *.tar.gz > checksums.txt

help:
	@echo "Targets: build, clean, install, uninstall, test, release"

.DEFAULT_GOAL := all
