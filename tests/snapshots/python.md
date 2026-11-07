# `nk` in `tests/fixtures/python`

```text
Available recipes:
    [nullkomma]
    all *args               # Format, build and run every check
    check *args             # Run the checks that `nix flake check` also runs
    flake-check *args       # Run every check sandboxed, on Git-tracked files, as CI does; args go to `nix flake check`
    generate-files *args    # Regenerate nullkomma's Git-ignored files; entering the dev shell does this too
    treefmt *args           # Format and lint all files
    write-files *args       # Update the files nullkomma committed, keeping your edits
    mcp                     # Serve the tasks as MCP tools over stdio, for agents
    graph *args             # Print the task dependency graph; args go to `process-compose graph` (default: -f mermaid)

    [gitleaks]
    gitleaks-git *args      # Scan Git history for secrets; treefmt scans the files

    [jscpd]
    jscpd *args             # Find duplicated code

    [nix]
    flake-checker *args     # Check that flake.lock pins a recent, upstream Nixpkgs
    flake-update *args      # Update flake inputs, then write-files and generate-files; args go to `nix flake update`

    [python]
    python-lock *args       # Resolve pyproject.toml into uv.lock; then commit it and run `direnv reload`
    python-lock-check *args # Check uv.lock without changing it or accessing the network; needs static dependencies
    python-test *args       # Run pytest from a dependency group on the editable working tree; --installed tests the installed package, other arguments go to pytest
    python-typecheck *args  # Check Python types with ty
```
