# `tests/fixtures/r-shiny`

## `nk`

```text
Available recipes:
    [nullkomma]
    all *args                  # Format, build and run every check
    check *args                # Run the checks that `nix flake check` also runs
    flake-check *args          # Run every check sandboxed, on Git-tracked files, as CI does; args go to `nix flake check`
    generate-files *args       # Regenerate the files nullkomma generates from Nix; entering the dev shell does this too
    generate-files-check *args # Check that the committed generated files match Nix
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
    flake-update *args         # Update flake inputs in flake.lock and dev/flake.lock, all or those named, then write-files and generate-files

    [r]
    r-build-site *args         # Build the pkgdown website; --preview opens it in a browser
    r-check *args              # Build the package and run R CMD check
    r-document *args           # Generate R manuals and NAMESPACE with roxygen2
    r-document-namespace *args # Generate NAMESPACE with roxygen2; --check fails if it was stale
    r-lock *args               # Resolve DESCRIPTION into the R lockfile (pkg.lock) with pak
    r-preview-site             # Serve the pkgdown website on localhost, reloading pages when r-build-site rewrites them
    r-run-app                  # Serve the working-tree Shiny apps with pkgload, open them in the browser, and reload them on changes
    r-test *args               # Run testthat on the working-tree package, loaded with pkgload; --installed tests the installed package
```

## Files

```text
committed .agents/skills/nk-audit-output/
committed .agents/skills/nk-upgrade/
committed .agents/skills/nullkomma-r-package-development/
committed .mcp.json
committed .vscode/mcp.json
generated .Rprofile
generated .nvim.lua
generated .vscode/extensions.json
generated .vscode/settings.json
source    .Rbuildignore (sections: r)
source    .envrc (sections: direnv)
source    .github/workflows/push.yml (sections: github)
source    .gitignore (sections: git)
source    AGENTS.md (sections: agents)
```
