# Prints the manifest for vendoring pkgdown's CDN assets, from its own pins.
deps <- new.env(parent = asNamespace("pkgdown"))
deps$cached_dependency <- function(name, version, files) {
  lapply(files, function(file) {
    list(name = file.path(name, version, basename(file$url)), url = file$url, hash = file$integrity)
  })
}
external <- pkgdown:::external_dependencies
environment(external) <- deps
pins <- Filter(function(dep) !inherits(dep, "html_dependency"), external(NULL))
writeLines(jsonlite::toJSON(do.call(c, pins), auto_unbox = TRUE, pretty = TRUE))
