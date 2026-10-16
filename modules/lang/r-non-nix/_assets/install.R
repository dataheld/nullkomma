local({
  library <- getOption("nullkomma.r.library")
  if (nzchar(Sys.getenv("IN_NIX_SHELL")) || is.null(library) ||
      !identical(library, .libPaths()[1]) || file.access(library, 2) != 0) {
    stop("Run from the project directory, outside Nix, with its .Rprofile enabled.", call. = FALSE)
  }
  if (!requireNamespace("pak", lib.loc = library, quietly = TRUE)) {
    install.packages("pak", lib = library, repos = sprintf(
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
    lib = library,
    dependencies = getOption("nullkomma.r.dependencies"),
    ask = FALSE
  )
})
