# Validate DESCRIPTION constraints against the selected package set, using R's parser.
# Usage: Rscript --vanilla description-constraints.R DESCRIPTION VERSIONS FIELD...
args <- commandArgs(trailingOnly = TRUE)
db <- read.dcf(args[[1]], fields = args[-c(1, 2)])
versions <- read.delim(args[[2]], header = FALSE, col.names = c("name", "version"), colClasses = "character")
selected <- setNames(versions$version, versions$name)
base <- installed.packages(lib.loc = .Library, priority = "base")
selected <- c(selected, setNames(base[, "Version"], base[, "Package"]), R = as.character(getRversion()))
for (field in colnames(db)) {
  if (is.na(db[1, field])) next
  for (dep in tools:::.split_dependencies(db[1, field])) {
    if (is.null(dep$version)) next
    actual <- selected[[dep$name]]
    if (is.null(actual)) stop("nullkomma.r: no selected version for ", dep$name)
    matches <- do.call(dep$op, list(package_version(actual), dep$version))
    if (!isTRUE(matches)) {
      stop("nullkomma.r: DESCRIPTION requires ", dep$name, " (", dep$op, " ",
           dep$version, "); selected version is ", actual, ". Choose another snapshot or pinned remote.")
    }
  }
}
cat("ok\n")
