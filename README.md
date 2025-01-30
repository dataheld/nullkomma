# NixPlate

Opinionated Boilerplate for Projects using Nix

## Installation

### Nix

Install Nix.
The [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer) is recommended.

## Updating

### Nix

There are two separate aspects to updating the nix dependencies.

1. There may be newer versions available *given* the pinning in `flake.nix`.
    This can be accomplished by running `make update-flake` locally and may change the `flake.lock`.
    However such updates may break a project.
    It is therefore recommended **to only run this in CI**,
    using the periodically scheduled `nix_maintenance.yml` job.
    It will automatically open pull requests if there are updates available.
    Users can then inspect whether the updated project still passes all tests.
2. The versions pinned in `flake.nix` (and the resulting `flake.lock`) itself may be out of date.
    The [DeterminateSystems/flake-checker](https://github.com/DeterminateSystems/flake-checker) will fail if this is the case.
    It runs on every push as well as periodically.
    You can also run this locally using `make check-flake-checker`.
