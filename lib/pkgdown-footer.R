brand_footer <- function(path) {
  html <- paste(readLines(path, warn = FALSE), collapse = "\n")
  if (!nzchar(html)) return("")
  document <- xml2::read_html(html)
  links <- xml2::xml_find_all(document, ".//a[@href]")
  href <- xml2::xml_attr(links, "href")
  local <- !grepl("^([[:alpha:]][[:alnum:]+.-]*:|/|#)", href)
  xml2::xml_set_attr(links[local], "data-nullkomma-root-href", href[local])
  paste(as.character(xml2::xml_children(xml2::xml_find_first(document, ".//body"))), collapse = "\n")
}

relativize_brand_footer <- function(destination) {
  for (page in list.files(destination, pattern = "\\.html$", recursive = TRUE)) {
    path <- file.path(destination, page)
    document <- xml2::read_html(path)
    links <- xml2::xml_find_all(document, ".//footer//a[@data-nullkomma-root-href]")
    if (!length(links)) next
    directories <- strsplit(dirname(page), "/", fixed = TRUE)[[1]]
    prefix <- paste(rep("../", sum(directories != ".")), collapse = "")
    xml2::xml_set_attr(links, "href", paste0(prefix, xml2::xml_attr(links, "data-nullkomma-root-href")))
    xml2::write_html(document, path)
  }
}
