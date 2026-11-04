if (interactive()) {
  local({
    load <- function(...) {
      tryCatch(pkgload::load_all(), error = function(e) {
        message("Could not load the package with pkgload::load_all(): ", conditionMessage(e))
      })
    }
    # R attaches the default packages after this profile; load the package above them.
    pending <- setdiff(getOption("defaultPackages"), .packages())
    if (length(pending)) {
      setHook(packageEvent(pending[length(pending)], "attach"), load)
    } else {
      load()
    }
  })
}
