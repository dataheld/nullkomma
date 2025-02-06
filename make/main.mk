.DELETE_ON_ERROR:

.PHONY: all help

.DEFAULT_GOAL := help

## Run all targets
all: check-flake

all-check:
	check-nix

.PHONY: format
# Format all files
format:
	treefmt

.PHONY: format-ci
# Format all files, stop on diff
format-ci:
	treefmt --ci
