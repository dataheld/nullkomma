# `nk` in `tests/fixtures/python`

```text
Available recipes:
    [nullkomma]
    all *args               # Format, build and run every check
    check *args             # Run the checks that `nix flake check` also runs
    flake-check *args       # Run every check sandboxed, on Git-tracked files, as CI does; args go to `nix flake check`
    link-files *args        # Link nullkomma's files from the Nix store; entering the dev shell does this too
    project-files *args     # Check that project files have the lines nullkomma requires
    treefmt *args           # Format and lint all files
    write-files *args       # Create missing project files; --overwrite <file>... replaces committed ones that lack lines, to reconcile with git diff
    mcp                     # Serve the tasks as MCP tools over stdio, for agents
    graph *args             # Print the task dependency graph; args go to `process-compose graph` (default: -f mermaid)

    [gitleaks]
    gitleaks-git *args      # Scan Git history for secrets; treefmt scans the files

    [jscpd]
    jscpd *args             # Find duplicated code

    [nix]
    flake-checker *args     # Check that flake.lock pins a recent, upstream Nixpkgs
    flake-update *args      # Update flake inputs in flake.lock and dev/flake.lock, all or those named

    [python]
    python-lock *args       # Resolve pyproject.toml into uv.lock; then commit it and run `direnv reload`
    python-lock-check *args # Check uv.lock without changing it or accessing the network; needs static dependencies
    python-test *args       # Run pytest from a dependency group on the editable working tree; --installed tests the installed package, other arguments go to pytest
    python-typecheck *args  # Check Python types with ty
```
