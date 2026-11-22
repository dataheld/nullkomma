test_that("hello greets", {
  expect_equal(hello("you"), "Hello, you!")
})

test_that("remotes come from their pinned sources", {
  expect_equal(as.character(packageVersion("withr")), "3.0.3.9000")
  expect_equal(as.character(packageVersion("digest")), "0.6.37")
})

test_that("remotes without committed manuals have help pages", {
  expect_gt(length(tools::Rd_db("elf")), 0)
})
