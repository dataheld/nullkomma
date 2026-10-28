#' Histogram of Old Faithful's waiting times, after Shiny's `01_hello` example
#'
#' @return A Shiny app object.
#' @export
app <- function() {
  shiny::shinyApp(
    ui = shiny::fluidPage(
      shiny::titlePanel("Hello Shiny!"),
      shiny::sidebarLayout(
        shiny::sidebarPanel(
          shiny::sliderInput(
            "bins",
            "Number of bins:",
            min = 1,
            max = 50,
            value = 30
          )
        ),
        shiny::mainPanel(shiny::plotOutput("distribution"))
      )
    ),
    server = function(input, output, session) {
      output$distribution <- shiny::renderPlot({
        waiting <- datasets::faithful$waiting
        graphics::hist(
          waiting,
          breaks = seq(min(waiting), max(waiting), length.out = input$bins + 1),
          col = "#007bc2",
          border = "white",
          xlab = "Waiting time to next eruption (in mins)",
          main = "Histogram of waiting times"
        )
      })
    }
  )
}
