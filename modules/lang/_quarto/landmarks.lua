-- Quarto's custom layout lacks a main landmark; pt-0 avoids extra content padding.
function Pandoc(doc)
  if quarto.doc.is_format("html") and pandoc.utils.stringify(doc.meta["page-layout"] or "") == "custom" then
    doc.blocks = pandoc.Blocks({ pandoc.Div(doc.blocks, pandoc.Attr("", { "pt-0" }, { role = "main" })) })
  end
  return doc
end
