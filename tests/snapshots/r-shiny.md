# `nk` in `tests/fixtures/r-shiny`

```text
Available recipes:
    [nullkomma]
    all *args                  # Format, build and run every check
    check *args                # Run the checks that `nix flake check` also runs
    generate-files *args       # Regenerate nullkomma's Git-ignored files; entering the dev shell does this too
    treefmt *args              # Format and lint all files
    write-files *args          # Update the files nullkomma committed, keeping your edits
    mcp                        # Serve the tasks as MCP tools over stdio, for agents
    graph *args                # Print the task dependency graph; args go to `process-compose graph` (default: -f mermaid)

    [gitleaks]
    gitleaks-git *args         # Scan Git history for secrets; treefmt scans the files

    [jscpd]
    jscpd *args                # Find duplicated code

    [nix]
    flake-checker *args        # Check that flake.lock pins a recent, upstream Nixpkgs
    flake-update *args         # Update flake inputs, then write-files and generate-files; args go to `nix flake update`

    [r]
    r-build-site *args         # Build the pkgdown website; --preview opens it in a browser
    r-check *args              # Build the package and run R CMD check
    r-document *args           # Generate R manuals and NAMESPACE with roxygen2
    r-document-namespace *args # Generate NAMESPACE with roxygen2; --check fails if it was stale
    r-lock *args               # Resolve DESCRIPTION into the R lockfile (pkg.lock) with pak
    r-run-app                  # Serve the working-tree Shiny app with pkgload
    r-test *args               # Run testthat on the working-tree package, loaded with pkgload; --installed tests the installed package
```
