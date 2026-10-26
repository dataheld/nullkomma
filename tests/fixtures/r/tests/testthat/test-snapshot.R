test_that("saved text snapshot", {
  expect_snapshot(cat("hello\n"), cran = TRUE)
})

test_that("saved file snapshot", {
  path <- tempfile(fileext = ".txt")
  writeLines("hello", path)
  expect_snapshot_file(path, "example.txt", variant = "variant")
})
