#' Create the fixture app
#'
#' @return A Shiny app object.
#' @export
app <- function() {
  stopifnot(system.file(package = "pkgload") == "")
  stopifnot(system.file(package = "testthat") == "")
  shiny::shinyApp(
    ui = shiny::fluidPage(shiny::h1("nullkomma Shiny fixture")),
    server = function(input, output, session) {}
  )
}

#' Return an invalid app for launcher tests
#'
#' @return A string.
#' @export
not_an_app <- function() {
  "not an app"
}

internal_app <- app
