# The CRAN snapshot date set by a project's .Rprofile (e.g. a Posit Package
# Manager `repos` URL); prints nothing if there is none.
# Usage: R_PROFILE_USER=.Rprofile Rscript rprofile-snapshot.R
repo <- getOption("repos")[["CRAN"]]
if (!is.null(repo)) {
  pattern <- "^https://packagemanager[.]posit[.]co/cran/([0-9]{4}-[0-9]{2}-[0-9]{2})/?$"
  if (grepl(pattern, repo)) {
    date <- sub(pattern, "\\1", repo)
    if (is.na(as.Date(date))) stop("nullkomma.r: invalid PPM snapshot date")
    writeLines(date)
  } else if (grepl("[0-9]{4}-[0-9]{2}-[0-9]{2}", repo)) {
    stop("nullkomma.r: dated CRAN repository must use https://packagemanager.posit.co/cran/YYYY-MM-DD")
  }
}
