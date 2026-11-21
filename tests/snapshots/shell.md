# `nk` in `tests/fixtures/shell`

```text
Available recipes:
    [nullkomma]
    all *args           # Format, build and run every check
    check *args         # Run the checks that `nix flake check` also runs
    flake-check *args   # Run every check sandboxed, on Git-tracked files, as CI does; args go to `nix flake check`
    link-files *args    # Link nullkomma's files from the Nix store; entering the dev shell does this too
    project-files *args # Check that project files have the lines nullkomma requires
    treefmt *args       # Format and lint all files
    write-files *args   # Create the project files nullkomma requires that are missing; --overwrite <file>... replaces those that lack lines, to reconcile with git diff
    mcp                 # Serve the tasks as MCP tools over stdio, for agents
    graph *args         # Print the task dependency graph; args go to `process-compose graph` (default: -f mermaid)

    [gitleaks]
    gitleaks-git *args  # Scan Git history for secrets; treefmt scans the files

    [jscpd]
    jscpd *args         # Find duplicated code

    [nix]
    flake-checker *args # Check that flake.lock pins a recent, upstream Nixpkgs
    flake-update *args  # Update flake inputs in flake.lock and dev/flake.lock, all or those named, then link-files

    [shell]
    bats *args          # Run the Bats tests
```
