# `nk` in `tests/fixtures/r`

```text
Available recipes:
    [nullkomma]
    all *args                  # Format, build and run every check
    check *args                # Run the checks that `nix flake check` also runs
    flake-check *args          # Run every check sandboxed, on Git-tracked files, as CI does; args go to `nix flake check`
    link-files *args           # Link nullkomma's files from the Nix store; entering the dev shell does this too
    project-files *args        # Check that project files have the lines nullkomma requires
    treefmt *args              # Format and lint all files
    write-files *args          # Create missing project files; --overwrite <file>... replaces committed ones that lack lines, to reconcile with git diff
    mcp                        # Serve the tasks as MCP tools over stdio, for agents
    graph *args                # Print the task dependency graph; args go to `process-compose graph` (default: -f mermaid)

    [gitleaks]
    gitleaks-git *args         # Scan Git history for secrets; treefmt scans the files

    [jscpd]
    jscpd *args                # Find duplicated code

    [nix]
    flake-checker *args        # Check that flake.lock pins a recent, upstream Nixpkgs
    flake-update *args         # Update flake inputs in flake.lock and dev/flake.lock, all or those named

    [r]
    r-build-site *args         # Build the pkgdown website; --preview opens it in a browser
    r-check *args              # Build the package and run R CMD check
    r-document *args           # Generate R manuals and NAMESPACE with roxygen2
    r-document-namespace *args # Generate NAMESPACE with roxygen2; --check fails if it was stale
    r-lock *args               # Resolve DESCRIPTION into the R lockfile (pkg.lock) with pak
    r-preview-site             # Serve the pkgdown website on localhost, reloading pages when r-build-site rewrites them
    r-test *args               # Run testthat on the working-tree package, loaded with pkgload; --installed tests the installed package; other arguments select test files by regex
```
