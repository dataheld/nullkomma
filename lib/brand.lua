-- Render optional brand footer facts into each builder's native containers.
-- Runs under `pandoc lua`: Quarto and pkgdown already ship that pandoc, so this adds no dependency.
local M = {}

local function read(path)
  local file = assert(io.open(path))
  local content = file:read("a")
  file:close()
  return content
end

local function write(path, content)
  local file = assert(io.open(path, "w"))
  file:write(content)
  file:close()
end

-- pandoc reads YAML strings as Markdown; reject markup rather than silently dropping it.
local function text(value)
  local kind = pandoc.utils.type(value)
  if kind == "string" or kind == "boolean" or kind == "number" then
    return tostring(value)
  end
  if kind == "Inlines" then
    for _, inline in ipairs(value) do
      if inline.t ~= "Str" and inline.t ~= "Space" then
        error("brand strings must be plain text, found " .. inline.t .. " in: " .. pandoc.utils.stringify(value))
      end
    end
    return pandoc.utils.stringify(value)
  end
  error("expected a brand string, found " .. kind)
end

local function escape(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#x27;"))
end

function M.parse(yaml)
  return pandoc.read("---\n" .. yaml .. "\n---\n", "markdown-smart").meta
end

-- pkgdown ships Font Awesome, Quarto Bootstrap Icons; brand.yml names the latter.
local fontawesome = {
  envelope = "fa-regular fa-envelope",
  github = "fa-brands fa-github",
  linkedin = "fa-brands fa-linkedin",
  ["twitter-x"] = "fa-brands fa-x-twitter",
}

-- Returns Quarto's `page-footer` value (nil without a footer) and the equivalent HTML for pkgdown.
function M.render(brand, privacy_href)
  local footer = ((brand.defaults or {}).nullkomma or {}).footer
  if footer == nil then
    return nil, ""
  end
  if pandoc.utils.type(footer) ~= "table" then
    error("defaults.nullkomma.footer must be a mapping")
  end

  local meta = brand.meta
  local function link(item)
    if item.privacy then
      return privacy_href
    end
    return text(meta.link[text(item.link)])
  end
  local function anchor(label, href)
    return '<a href="' .. escape(href) .. '">' .. escape(label) .. "</a>"
  end

  local left = anchor(text(meta.name), text(meta.link.home))
  if footer.tagline then
    left = left .. " · " .. escape(text(footer.tagline))
  end
  local center, right = {}, {}
  for _, item in ipairs(footer.links or {}) do
    local href = link(item)
    if href then
      center[#center + 1] = { text = text(item.text), href = href }
    end
  end
  for _, item in ipairs(footer.social or {}) do
    right[#right + 1] = { icon = text(item.icon), href = link(item), ["aria-label"] = text(item.text) }
  end

  local links = {}
  for _, item in ipairs(center) do
    links[#links + 1] = anchor(item.text, item.href)
  end
  local icons = {}
  for _, item in ipairs(right) do
    local class = fontawesome[item.icon] or error("no Font Awesome equivalent of Bootstrap icon " .. item.icon)
    icons[#icons + 1] = '<a href="' .. escape(item.href) .. '" aria-label="' .. escape(item["aria-label"]) .. '"><i class="'
      .. class .. '" aria-hidden="true"></i></a>'
  end
  local html = '<div class="nullkomma-footer-left">' .. left .. '</div>\n<div class="nullkomma-footer-center">'
    .. table.concat(links, " · ") .. '</div>\n<div class="nullkomma-footer-right">' .. table.concat(icons, " ") .. "</div>"

  local record = { border = true, left = left }
  -- One line like the left column, not Quarto's stacked nav list.
  if #center > 0 then
    record.center = table.concat(links, " · ")
  end
  -- pandoc.json encodes empty tables as objects, so omit empty lists.
  if #right > 0 then
    record.right = right
  end
  return record, html
end

-- Arguments: brand.yml, privacy href, Quarto metadata JSON, docs project JSON, output directory.
-- The .yml outputs are JSON, which is valid YAML.
function M.main(brand_path, privacy_href, metadata, docs, output)
  local brand = brand_path ~= "" and M.parse(read(brand_path)) or {}
  local footer, html = M.render(brand, privacy_href ~= "" and privacy_href or nil)
  metadata = pandoc.json.decode(metadata, false)
  docs = pandoc.json.decode(docs, false)
  if footer ~= nil then
    metadata.website = metadata.website or {}
    metadata.website["page-footer"] = footer
    docs.website["page-footer"] = footer
  end
  pandoc.system.make_directory(output)
  write(output .. "/footer.html", html)
  write(output .. "/quarto.yml", next(metadata) and pandoc.json.encode(metadata) or "{}")
  write(
    output .. "/_extension.yml",
    pandoc.json.encode({ title = "nullkomma documentation", version = "0.1.0", contributes = { project = docs } })
  )
end

if arg and arg[0] and arg[0]:match("brand%.lua$") then
  M.main(table.unpack(arg))
end

return M
