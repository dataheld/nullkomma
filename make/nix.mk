NIX_FILES := $(wildcard *.nix)

.PHONY: build-nix
## Build all flake outputs with derivations
build-nix:
	flake-iter build

.PHONY: check-nix
## Check all nix stuff
check-nix: check-flake check-flake-checker

.PHONY: check-flake
# Check nix flake for bad syntax etc.
check-flake:
	nix flake check --all-systems

.PHONY: check-flake-checker
# Check nix flake for outdated dependencies, etc.
check-flake-checker: flake.lock
	flake-checker

.PHONY: update-flake
# Update flake.lock file
update-flake:
	nix flake update

# Complete flake.lock file
flake.lock: $(NIX_FILES)
	nix flake lock
