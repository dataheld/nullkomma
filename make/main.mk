.DELETE_ON_ERROR:

.PHONY: all help

.DEFAULT_GOAL := help

## Run all targets
all: check-flake render

all-check:
	check-nix

.PHONY: gha
## Run approximately what is run on GitHub Actions
gha: gha-push

.PHONY: gha-push
gha-push: build-nix check-flake-checker

.PHONY: gha-cron
gha-cron: check-flake-checker update-flake
