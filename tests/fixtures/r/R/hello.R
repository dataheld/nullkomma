#' Say hello
#'
#' @param name Who to greet.
#' @return A greeting.
#' @export
hello <- function(name = "world") {
  paste0("Hello, ", name, "!")
}
