# Package name and version of a DESCRIPTION, one per line.
# Usage: Rscript description-meta.R DESCRIPTION
db <- read.dcf(commandArgs(trailingOnly = TRUE)[[1]], fields = c("Package", "Version"))
writeLines(db[1, c("Package", "Version")])
