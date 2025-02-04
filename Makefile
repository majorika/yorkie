YORKIE_VERSION := 0.2.2

GIT_COMMIT := $(shell git rev-parse --short HEAD)
GO_PROJECT = github.com/yorkie-team/yorkie

ifeq ($(OS),Windows_NT)
    BUILD_DATE := $(shell echo %date:~6,4%-%date:~0,2%-%date:~3,2%)
    GO_SRC := $(shell dir /s /b *.go | findstr /v "vendor")
    EXECUTABLE = ./bin/yorkie.exe
else
    BUILD_DATE := $(shell date "+%Y-%m-%d")
    GO_SRC := $(shell find . -path ./vendor -prune -o -type f -name '*.go' -print)
    EXECUTABLE = ./bin/yorkie
endif

# inject the version number into the golang version package using the -X linker flag
GO_LDFLAGS ?=
GO_LDFLAGS += -X ${GO_PROJECT}/internal/version.GitCommit=${GIT_COMMIT}
GO_LDFLAGS += -X ${GO_PROJECT}/internal/version.Version=${YORKIE_VERSION}
GO_LDFLAGS += -X ${GO_PROJECT}/internal/version.BuildDate=${BUILD_DATE}

tools: ## install tools for developing yorkie
	go generate -tags tools tools/tools.go

proto: ## generate proto files
	protoc api/yorkie.proto \
-I=. \
-I=$(GOPATH)/src \
-I=$(GOPATH)/src/github.com/gogo/protobuf/protobuf \
--gofast_out=plugins=grpc,\
Mgoogle/protobuf/timestamp.proto=github.com/gogo/protobuf/types,\
Mgoogle/protobuf/any.proto=github.com/gogo/protobuf/types,:.

build: ## builds an executable that runs in the current environment
	go build -o $(EXECUTABLE) -ldflags "${GO_LDFLAGS}" ./cmd/yorkie

build-binaries: ## builds binaries to attach a new release
	rm -rf binaries
	./scripts/build-binaries.sh $(YORKIE_VERSION) "$(GO_LDFLAGS)"

fmt: ## applies format and simplify codes
	gofmt -s -w $(GO_SRC)

lint: ## runs the golang-ci lint, checks for lint violations
	 golangci-lint run ./...

test: ## runs integration tests that require local applications such as MongoDB
	go clean -testcache
	go test -tags integration -race ./...

bench: ## runs benchmark tests
	go test -tags bench -benchmem -bench=. ./test/bench

docker: ## builds docker images with the current version and latest tag
	docker buildx build --push --platform linux/amd64,linux/arm64,linux/386 -t yorkieteam/yorkie:$(YORKIE_VERSION) -t yorkieteam/yorkie:latest .

docker-latest: ## builds docker images with latest tag
	docker buildx build --push --platform linux/amd64,linux/arm64,linux/386 -t yorkieteam/yorkie:latest .

default: help
help:
	@echo 'Yorkie commands for' $(EXENAME) $(VERSION)
	@echo
	@echo 'Commands:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "    %-20s %s\n", $$1, $$2}'
	@echo

.PHONY: tools proto build fmt lint test docker docker-latest release help
