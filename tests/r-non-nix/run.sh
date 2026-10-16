#!/usr/bin/env bash
set -euo pipefail
test ! -e /nix
if command -v nix; then
  echo "The Ubuntu test must not contain Nix" >&2
  exit 1
fi
test "$(id -u)" != 0
grep -q '^VERSION_ID="24.04"$' /etc/os-release
cp -R /fixture/. .
chmod -R u+w .

export R_LIBS_USER="$HOME/existing-user-library"
export R_LIBS_SITE="$HOME/existing-site-library"
mkdir -p "$R_LIBS_USER" "$R_LIBS_SITE"
R CMD INSTALL --library="$R_LIBS_USER" .
R CMD INSTALL --library="$R_LIBS_SITE" .
Rscript --vanilla - <<'RS'
  install.packages("pak", lib = Sys.getenv("R_LIBS_USER"), repos = sprintf(
    "https://r-lib.github.io/p/pak/stable/%s/%s/%s",
    .Platform$pkgType, R.Version()$os, R.Version()$arch
  ))
  stopifnot(requireNamespace("pak", lib.loc = Sys.getenv("R_LIBS_USER"), quietly = TRUE))
RS
find "$R_LIBS_USER" "$R_LIBS_SITE" -type f -exec sha256sum {} + | sort >/tmp/external-before
test -s /tmp/external-before

# Execute the actual R examples in the emitted documentation, in order.
awk '/^```r$/ { code=1; next } /^```$/ { code=0 } code { print }' README.md >examples.R
Rscript - <<'RS'
  stopifnot(as.character(getRversion()) == Sys.getenv("NULLKOMMA_R_VERSION"))
  stopifnot(l10n_info()[["UTF-8"]])
  stopifnot(getOption("repos")[["CRAN"]] == Sys.getenv("NULLKOMMA_PPM_URL"))
  stopifnot(startsWith(.libPaths()[1], file.path(getwd(), ".R", "library")))
  stopifnot(!requireNamespace("pak", quietly = TRUE))
  stopifnot(!requireNamespace("nullkommafixture", quietly = TRUE))
  stopifnot(!any(file.path(Sys.getenv("HOME"), c(
    "existing-user-library", "existing-site-library"
  )) %in% .libPaths()))
RS

Rscript - <<'RS'
  source("examples.R")
  for (package in c("pak", "testthat", "assertthat", "rematch")) {
    stopifnot(startsWith(find.package(package), .libPaths()[1]))
  }
  status <- pak::lib_status(lib = getOption("nullkomma.r.library"))
  stopifnot(all(c("pak", "testthat", "assertthat", "rematch") %in% status$package))
  stopifnot(all(status$library == getOption("nullkomma.r.library")))
  binary_library <- tempfile()
  dir.create(binary_library)
  plan <- pak::pkg_install("brio", lib = binary_library, dependencies = FALSE, ask = FALSE)
  stopifnot(sum(plan$package == "brio") == 1L)
  stopifnot(isTRUE(plan$binary[plan$package == "brio"]))
RS

# A new Config/Needs field is discovered without a Nix regeneration.
printf 'Config/Needs/extra: RColorBrewer\n' >>DESCRIPTION
Rscript examples.R
Rscript -e 'stopifnot(requireNamespace("RColorBrewer", quietly = TRUE))'
sed -i '/^Config\/Needs\/extra:/d' DESCRIPTION
Rscript -e 'pak::pkg_remove("RColorBrewer", lib = getOption("nullkomma.r.library"))'
Rscript examples.R
Rscript -e 'stopifnot(!requireNamespace("RColorBrewer", quietly = TRUE))'

# The committed lock stays source-only and the project survives a fresh session.
Rscript - <<'RS'
  lock <- jsonlite::read_json("pkg.lock")
  stopifnot(all(vapply(lock$packages, function(p) identical(p$platform, "source"), logical(1))))
  stopifnot(file.exists("pkg.lock"), dir.exists(Sys.getenv("R_LIBS_USER")))
RS
find "$R_LIBS_USER" "$R_LIBS_SITE" -type f -exec sha256sum {} + | sort >/tmp/external-after
cmp /tmp/external-before /tmp/external-after

rm examples.R
mkdir -p nix .github/workflows .vscode .direnv
touch flake.lock nix/helper.nix .github/workflows/ci.yml .vscode/settings.json \
  .direnv/cache .envrc project-only.txt
R CMD build --no-build-vignettes --no-manual .
tar -tf nullkommafixture_0.0.1.tar.gz >/tmp/package-files
if grep -E '([.]nix$|/(flake[.]lock|pkg[.]lock|[.]R|[.]Rprofile|[.]Renviron|[.]envrc|[.]direnv|[.]github|[.]vscode|project-only[.]txt)(/|$))' /tmp/package-files; then
  echo "Development-only files leaked into the package source" >&2
  exit 1
fi
grep -qx 'nullkommafixture/R/hello.R' /tmp/package-files
grep -qx 'nullkommafixture/DESCRIPTION' /tmp/package-files
R CMD check --no-manual --ignore-vignettes nullkommafixture_0.0.1.tar.gz
if grep -Eq '^Status: .*(WARNING|ERROR)' nullkommafixture.Rcheck/00check.log; then
  cat nullkommafixture.Rcheck/00check.log >&2
  exit 1
fi
