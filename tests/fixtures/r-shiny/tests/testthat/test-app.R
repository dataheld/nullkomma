test_that("the exported app doubles its input", {
  driver <- shinytest2::AppDriver$new(app, name = "app", load_timeout = 60000)
  on.exit(driver$stop(), add = TRUE)
  driver$set_inputs(number = 21)
  driver$expect_values(output = "doubled", screenshot_args = FALSE)
})
