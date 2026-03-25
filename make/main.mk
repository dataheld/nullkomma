.DELETE_ON_ERROR:

.PHONY: all help

.DEFAULT_GOAL := help

## Run all targets
all: check-flake render

all-check:
	check-nix

.PHONY: gha
## Run approximately what is run on GitHub Actions
gha: gha-ci

.PHONY: gha-ci
gha-ci: build-nix check-flake-checker
