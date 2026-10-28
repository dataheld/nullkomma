test_that("the configured Chrome browser starts", {
  session <- chromote::ChromoteSession$new()
  on.exit(session$close(), add = TRUE)
  expect_true(session$is_active())
})

test_that("the exported app doubles its input", {
  driver <- tryCatch(
    shinytest2::AppDriver$new(app, name = "app", load_timeout = 60000),
    skip = function(condition) stop(condition$message)
  )
  on.exit(driver$stop(), add = TRUE)
  driver$set_inputs(number = 21)
  driver$expect_values(output = "doubled", screenshot_args = FALSE)
})
