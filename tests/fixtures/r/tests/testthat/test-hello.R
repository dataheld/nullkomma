test_that("hello greets", {
  expect_equal(hello("you"), "Hello, you!")
  expect_equal(as.character(packageVersion("withr")), "3.0.3.9000")
})
