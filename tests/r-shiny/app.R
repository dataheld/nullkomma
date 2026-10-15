shiny::shinyApp(
  ui = shiny::fluidPage(
    shiny::numericInput("number", "Number", value = 1),
    shiny::textOutput("doubled")
  ),
  server = function(input, output, session) {
    output$doubled <- shiny::renderText(input$number * 2)
  }
)
