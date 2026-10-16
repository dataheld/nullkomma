### R development without Nix {.callout-tip}

You do not need Nix or direnv. Install R (the recommended version is recorded in
`.Renviron`), open this directory in R or RStudio, and start a fresh R session.
The committed `.Rprofile` reads `.Renviron`, selects the project's dated Posit
Package Manager (PPM) repository, and creates a writable library in
`.R/library/<R-version>/<platform>/`. Nothing is installed automatically at
startup. Other user and site libraries are excluded from this project's library
search path; R's own base/recommended library remains available. Your existing
libraries and global defaults are not modified. Do not use `R --vanilla`: it skips
these project settings.

#### Install dependencies

Run this in the R console, from the directory containing `DESCRIPTION`:

```r
source(".R/install.R")
```

Or run `Rscript .R/install.R` in a terminal from the project directory. This
helper installs pak and the DESCRIPTION dependencies explicitly into the project
library, even if pak is already installed elsewhere. Re-run it to update
dependencies. It refuses to run without the project profile or inside Nix.

The PPM resolver selects a platform-specific repository when supported; a custom
repository URL is left unchanged. pak chooses binaries when available,
otherwise source packages. Source packages may need a compiler and system
libraries; pak reports these requirements and may offer to install them with
administrator privileges. The local library is Git-ignored; do not commit it.

The helper delegates resolution, downloads, caching and installation to
[`pak::local_install_deps()`](https://pak.r-lib.org/reference/local_install_deps.html),
with a single `lib` path: unrelated user/site libraries cannot satisfy its
dependencies. pak still considers base and recommended packages supplied by R.
For diagnostics, use `pak::lib_status(lib = getOption("nullkomma.r.library"))`
to inspect the local library, or
`pak::pkg_sysreqs("deps::.", dependencies = getOption("nullkomma.r.dependencies"))`
to inspect OS requirements without installing them. pak's private dependencies
are already isolated; no extra bootstrap package or `pak_setup()` is needed.

#### Add or remove dependencies

Edit `DESCRIPTION`: use `Imports` for packages needed to run your code,
`Suggests` for tests (for example, testthat), and `Config/Needs/development`
for development tools. All `Config/Needs/*` fields are included by default.
Restart R and re-run the installation command after editing, so new
`Config/Needs/*` fields are picked up. To remove an unused installed
package as well, specify the library explicitly; this only changes your
local library, not `DESCRIPTION`:
`pak::pkg_remove("packageName", lib = getOption("nullkomma.r.library"))`.

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
`install.packages("roxygen2", lib = getOption("nullkomma.r.library"))`).
Keep the generated `NAMESPACE` committed.
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

#### Optional R version management with rig

[rig](https://rig.r-lib.org/) can install and select R without requiring Nix.
With a recent rig supporting [user mode](https://rig.r-lib.org/admin-vs-user-mode.html),
replace `<version>` below with `NULLKOMMA_R_VERSION` from `.Renviron`:

```sh
rig add --user --without-pak <version>
rig run --user --r-version <version> -f .R/install.R
rig run --user --r-version <version>
```

The R interpreter is installed per-user, not per-repo; packages still go into
this repo's `.R/library/`. No `rig default`, `rig library default`, or mode
migration is needed. Older rig releases may not support `--user`; upgrade first
rather than falling back to an administrator installation. In particular,
admin-mode installs on macOS can replace another patch version of R.

[`rig library`](https://rig.r-lib.org/reference/library.html) manages named
user-wide libraries, not repo-local ones. We do not switch their default or
install into them. Rig's experimental [`rig proj`](https://rig.r-lib.org/proj-guide.html)
provides project environments, but introduces `rproj.toml` and `rproj.lock`;
this setup deliberately keeps DESCRIPTION and pak's `pkg.lock` as its only
dependency declarations. Rig is optional and never runs during R startup.
