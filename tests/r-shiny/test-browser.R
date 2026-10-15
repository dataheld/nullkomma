testthat::test_that("Chromium drives a real Shiny session", {
  app <- shinytest2::AppDriver$new(
    app_dir = Sys.getenv("SHINY_FIXTURE"),
    name = "nullkomma-browser",
    load_timeout = 60000,
    timeout = 20000
  )
  on.exit(app$stop(), add = TRUE)
  testthat::expect_equal(app$get_value(output = "doubled"), "2")
  app$set_inputs(number = 21)
  testthat::expect_equal(app$get_value(output = "doubled"), "42")
  agent <- app$get_chromote_session()$Runtime$evaluate("navigator.userAgent")
  testthat::expect_match(agent$result$value, "Chrome/")
})
