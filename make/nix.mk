.PHONY: check-nix check-flake

## Check all nix stuff
check-nix: check-flake

# Check nix flake
check-flake:
	nix flake check --all-systems
