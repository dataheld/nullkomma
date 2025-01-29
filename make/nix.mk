.PHONY: check-nix check-flake update-flake

NIX_FILES := $(wildcard *.nix)

## Check all nix stuff
check-nix: check-flake

# Check nix flake
check-flake:
	nix flake check --all-systems

# Update flake.lock file
update-flake:
	nix flake update

# Complete flake.lock file
flake.lock: $(NIX_FILES)
	nix flake lock
