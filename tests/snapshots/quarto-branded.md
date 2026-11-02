# `nk` in `tests/fixtures/quarto-branded`

```text
Available recipes:
    [nullkomma]
    all *args            # Format, build and run every check
    check *args          # Run the checks that `nix flake check` also runs
    generate-files *args # Regenerate nullkomma's Git-ignored files; entering the dev shell does this too
    treefmt *args        # Format and lint all files
    write-files *args    # Update the files nullkomma committed, keeping your edits
    mcp                  # Serve the tasks as MCP tools over stdio, for agents
    graph *args          # Print the task dependency graph; args go to `process-compose graph` (default: -f mermaid)

    [gitleaks]
    gitleaks-git *args   # Scan Git history for secrets; treefmt scans the files

    [jscpd]
    jscpd *args          # Find duplicated code

    [nix]
    flake-checker *args  # Check that flake.lock pins a recent, upstream Nixpkgs
    flake-update *args   # Update flake inputs, then write-files and generate-files; args go to `nix flake update`

    [quarto]
    quarto-preview *args # Serve the site on localhost, re-rendering and reloading on changes
    quarto-render *args  # Render the Quarto site
```
