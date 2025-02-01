.PHONY: check-nix check-flake update-flake build-nix

NIX_FILES := $(wildcard *.nix)

## Build all flake outputs with derivations
build-nix:
	flake-iter build

## Check all nix stuff
check-nix: check-flake check-flake-checker

# Check nix flake for bad syntax etc.
check-flake:
	nix flake check --all-systems

# Check nix flake for outdated dependencies, etc.
check-flake-checker: flake.lock
	flake-checker

# Update flake.lock file
update-flake:
	nix flake update

# Complete flake.lock file
flake.lock: $(NIX_FILES)
	nix flake lock
