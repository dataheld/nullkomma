# `Remotes:` entries of a DESCRIPTION (pak/remotes syntax), one per line.
# Usage: Rscript description-remotes.R DESCRIPTION
db <- read.dcf(commandArgs(trailingOnly = TRUE)[[1]], fields = "Remotes")
remotes <- db[1, "Remotes"]
if (!is.na(remotes)) writeLines(trimws(strsplit(remotes, ",")[[1]]))
