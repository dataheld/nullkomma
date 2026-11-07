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

#' Create a second fixture app, served next to the first
#'
#' Reads its greeting from an installed file when it creates the app.
#'
#' @return A Shiny app object.
#' @export
greeting_app <- function() {
  greeting <- readLines(system.file(
    "greeting.txt",
    package = "nullkommashinyfixture"
  ))
  shiny::shinyApp(
    ui = shiny::fluidPage(shiny::h1(greeting)),
    server = function(input, output, session) {}
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
