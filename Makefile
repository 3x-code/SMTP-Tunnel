.PHONY: all clean build release install uninstall

VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE := $(shell date -u +%Y%m%d%H%M%S)

GO := go
GOFLAGS := -ldflags="-s -w -X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.date=$(DATE)"
CGO_ENABLED := 0

all: clean deps build

deps:
	$(GO) mod download
	$(GO) mod verify

build: build-client build-server

build-client:
	CGO_ENABLED=$(CGO_ENABLED) $(GO) build $(GOFLAGS) -o bin/smtp-tunnel-iran-client ./cmd/client

build-server:
	CGO_ENABLED=$(CGO_ENABLED) $(GO) build $(GOFLAGS) -o bin/smtp-tunnel-iran-server ./cmd/server

clean:
	rm -rf bin/ dist/
	$(GO) clean

install: build
	install -d /usr/local/bin
	install -m 755 bin/smtp-tunnel-iran-client /usr/local/bin/
	install -m 755 bin/smtp-tunnel-iran-server /usr/local/bin/

uninstall:
	rm -f /usr/local/bin/smtp-tunnel-iran-client
	rm -f /usr/local/bin/smtp-tunnel-iran-server

help:
	@echo "Available targets:"
	@echo "  build    - Build for current platform"
	@echo "  clean    - Remove build artifacts"
	@echo "  install  - Install to /usr/local/bin"
	@echo "  uninstall- Remove from system"
