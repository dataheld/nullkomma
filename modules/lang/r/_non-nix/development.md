### R development without Nix {.callout-tip}

You do not need Nix or direnv. Install R (the recommended version is recorded in
`.Renviron`), open this directory in R or RStudio, and start a fresh R session.
The committed `.Rprofile` reads `.Renviron`, selects the project's dated Posit
Package Manager (PPM) repository, and creates a writable library in
`.R/library/<R-version>/<platform>/`. Nothing is installed automatically at
startup. Do not use `R --vanilla`: it skips these project settings.

#### Install dependencies

Run this in the R console, from the directory containing `DESCRIPTION`:

```r
if (!requireNamespace("pak", quietly = TRUE)) {
  install.packages("pak", repos = sprintf(
    "https://r-lib.github.io/p/pak/stable/%s/%s/%s",
    .Platform$pkgType, R.Version()$os, R.Version()$arch
  ))
}
pak::local_install_deps(
  dependencies = getOption("nullkomma.r.dependencies"),
  ask = FALSE
)
```

pak chooses binaries for your operating system and R version when available,
otherwise source packages. Source packages may need a compiler and system
libraries; pak reports these requirements and may offer to install them with
administrator privileges. The local library is Git-ignored; do not commit it.

#### Add or remove dependencies

Edit `DESCRIPTION`: use `Imports` for packages needed to run your code,
`Suggests` for tests (for example, testthat), and `Config/Needs/development`
for development tools. All `Config/Needs/*` fields are included by default.
Re-run the installation command after editing. To remove an unused installed
package as well, run `pak::pkg_remove("packageName")`; this only changes your
local library, not `DESCRIPTION`.

Refresh the committed lockfile after changing dependencies:

```r
local({
  previous <- options(pkg.platforms = "source")
  on.exit(options(previous))
  pak::lockfile_create(
    "deps::.",
    dependencies = getOption("nullkomma.r.dependencies"),
    lockfile = "pkg.lock"
  )
})
```

Commit `DESCRIPTION` and `pkg.lock` together. Restart R after updating packages.
Nix collaborators can refresh the same lockfile with `r-lock`.

The PPM date approximates the Nix package set: R package versions can differ,
and neither your R installation nor system libraries are pinned by this setup.
`pak::lockfile_install()` reproduces the lock's source-package choices instead,
but may need compilation and working source URLs. Keep `.Renviron`, `.Rprofile`
and these instructions committed so collaborators need no Nix-generated files.
