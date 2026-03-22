.DELETE_ON_ERROR:

.PHONY: all help

.DEFAULT_GOAL := help

## Run all targets
all: check-flake render

all-check:
	check-nix
