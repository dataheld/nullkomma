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
if (identical(getOption("repos")[["CRAN"]], paste0(
  "https://packagemanager.posit.co/cran/", Sys.getenv("NULLKOMMA_PPM_SNAPSHOT")
))) {
  pak::repo_add(CRAN = paste0("PPM@", Sys.getenv("NULLKOMMA_PPM_SNAPSHOT")))
}
pak::local_install_deps(
  dependencies = getOption("nullkomma.r.dependencies"),
  ask = FALSE
)
```

The PPM resolver selects a platform-specific repository when supported; a custom
repository URL is left unchanged. pak chooses binaries when available,
otherwise source packages. Source packages may need a compiler and system
libraries; pak reports these requirements and may offer to install them with
administrator privileges. The local library is Git-ignored; do not commit it.

#### Add or remove dependencies

Edit `DESCRIPTION`: use `Imports` for packages needed to run your code,
`Suggests` for tests (for example, testthat), and `Config/Needs/development`
for development tools. All `Config/Needs/*` fields are included by default.
Restart R and re-run the installation command after editing, so new
`Config/Needs/*` fields are picked up. To remove an unused installed
package as well, run `pak::pkg_remove("packageName")`; this only changes your
local library, not `DESCRIPTION`.

Refresh the committed lockfile after changing dependencies. Resolve against an
empty library so installed binaries do not enter the shared source-only lock:

```r
local({
  previous <- options(
    repos = c(CRAN = Sys.getenv("NULLKOMMA_PPM_URL")),
    pkg.platforms = "source"
  )
  library <- tempfile()
  dir.create(library)
  on.exit({
    options(previous)
    unlink(library, recursive = TRUE)
  })
  pak::lockfile_create(
    "deps::.",
    dependencies = getOption("nullkomma.r.dependencies"),
    lib = library,
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

#### Build and check a package

For projects with a `Package:` field in `DESCRIPTION`, run these commands in a
terminal from the project directory (replace the archive name with your package
and version):

If `man/*.Rd` is generated and Git-ignored, first run
`roxygen2::roxygenise()` in R. Declare roxygen2 in `Config/Needs/development`
so the dependency installation above supplies it (or install it once with
`install.packages("roxygen2")`). Keep the generated `NAMESPACE` committed.
The Nix development tasks generate manuals automatically, but plain R does not.

```sh
R CMD build .
R CMD check yourpackage_0.1.0.tar.gz
```

The committed `.Rbuildignore` excludes Nix files, lockfiles, editor/CI settings,
startup files and the local library from the source package. Existing project
exclusions are preserved when setting it up. Building manuals and vignettes may
require additional tools such as LaTeX; CRAN's submission requirements still
apply.
