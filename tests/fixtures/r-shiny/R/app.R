#' Create the fixture app
#'
#' @return A Shiny app object.
#' @export
app <- function() {
  shiny::shinyApp(
    ui = shiny::fluidPage(
      shiny::h1("nullkomma Shiny fixture"),
      shiny::numericInput("number", "Number", value = 1),
      shiny::textOutput("doubled")
    ),
    server = function(input, output, session) {
      output$doubled <- shiny::renderText(input$number * 2)
    }
  )
}

#' Create the fixture app, failing if development packages are visible
#'
#' @return A Shiny app object.
#' @export
isolated_app <- function() {
  stopifnot(system.file(package = "pkgload") == "")
  stopifnot(system.file(package = "testthat") == "")
  app()
}

#' Return an invalid app for launcher tests
#'
#' @return A string.
#' @export
not_an_app <- function() {
  "not an app"
}

internal_app <- app
