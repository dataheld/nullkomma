# `nk` in `tests/fixtures/md`

```text
Available recipes:
    [nullkomma]
    all *args            # Format and run check, plus checks that need network or Docker
    check *args          # Run the checks that are tasks, in the working tree
    generate-files *args # Overwrite Git-ignored files generated from Nix
    treefmt *args        # Format and lint all files
    write-files *args    # Write source-of-truth files; keep your edits and report upstream conflicts
    mcp                  # Serve the tasks as MCP tools over stdio, for agents
    graph *args          # Print the process dependency graph; args go to `process-compose graph` (default: -f mermaid)

    [gitleaks]
    gitleaks-git *args   # Scan Git history for secrets

    [jscpd]
    jscpd *args          # Find duplicated code

    [nix]
    flake-checker *args  # Check flake.lock for outdated or non-upstream Nixpkgs
    flake-update *args   # `nix flake update` flake.lock and dev/flake.lock, then write-files and generate-files; args go to `nix flake update` and skip dev/flake.lock
```
