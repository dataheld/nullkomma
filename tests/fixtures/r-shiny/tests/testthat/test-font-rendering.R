test_that("Chromium renders text with the configured font", {
  font_app <- shiny::shinyApp(
    shiny::fluidPage(
      shiny::tags$div(
        id = "font-fixture",
        style = paste(
          "width: 240px;",
          "height: 56px;",
          "background: white;",
          "font-family: 'Liberation Sans';",
          "font-size: 16px;"
        ),
        "Counter 0"
      )
    ),
    function(input, output, session) { }
  )
  driver <- shinytest2::AppDriver$new(
    font_app,
    name = "font-rendering",
    width = 300,
    height = 100,
    screenshot_args = FALSE
  )
  on.exit(driver$stop(), add = TRUE)

  rendering <- driver$get_js("
    (() => {
      const element = document.querySelector('#font-fixture');
      const bounds = element.getBoundingClientRect();
      const canvas = document.createElement('canvas');
      canvas.width = bounds.width;
      canvas.height = bounds.height;
      const context = canvas.getContext('2d');
      context.font = getComputedStyle(element).font;
      context.fillText(element.textContent, 0, 24);
      const pixels = context.getImageData(
        0,
        0,
        canvas.width,
        canvas.height
      ).data;
      return {
        width: bounds.width,
        height: bounds.height,
        renderedPixels: pixels.filter(
          (channel, index) => index % 4 === 3 && channel > 0
        ).length
      };
    })()
  ")

  expect_equal(rendering$width, 240)
  expect_equal(rendering$height, 56)
  expect_gt(rendering$renderedPixels, 0)
})
