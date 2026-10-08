# Package names a DESCRIPTION depends on, one per line, parsed by R itself.
# Usage: Rscript description-deps.R DESCRIPTION FIELD...
args <- commandArgs(trailingOnly = TRUE)
fields <- args[-1]
db <- read.dcf(args[[1]], fields = c("Package", fields))
db[, "Package"] <- "description"
deps <- tools::package_dependencies("description", db = db, which = fields)[["description"]]
# base packages ship with R itself
base <- rownames(installed.packages(lib.loc = .Library, priority = "base"))
writeLines(sort(setdiff(deps, c("R", base))))
