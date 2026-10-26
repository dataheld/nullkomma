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
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#x27;"):gsub("{", "&#123;"))
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

-- Returns Quarto's `page-footer` value (nil without a footer) and the equivalent pkgdown footer template,
-- whose local links start at pkgdown's site root.
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
  local function href(url, root)
    local absolute = url:match("^%a[%w+.-]*:") or url:match("^[/#]")
    return (absolute and "" or root) .. escape(url)
  end
  local function anchor(label, url, root, target)
    local attributes = target and ' target="_blank" rel="noopener noreferrer"' or ""
    return '<a class="text-reset" href="' .. href(url, root) .. '"' .. attributes .. '>' .. escape(label) .. "</a>"
  end

  local tagline = footer.tagline and " · " .. escape(text(footer.tagline)) or ""
  local right = {}
  for _, item in ipairs(footer.links or {}) do
    local url = link(item)
    if url then
      local imprint = item.link and text(item.link) == "imprint"
      right[#right + 1] = {
        text = text(item.text),
        href = url,
        target = imprint and "_blank" or nil,
        rel = imprint and "noopener noreferrer" or nil,
      }
    end
  end
  for _, item in ipairs(footer.social or {}) do
    right[#right + 1] = { icon = text(item.icon), href = link(item), ["aria-label"] = text(item.text) }
  end
  local function left(root)
    return anchor(text(meta.name), text(meta.link.home), root) .. tagline
  end

  local links = {}
  local root = "{{#site}}{{root}}{{/site}}"
  for _, item in ipairs(right) do
    local content
    if item.icon then
      local class = fontawesome[item.icon] or error("no Font Awesome equivalent of Bootstrap icon " .. item.icon)
      content = '<a class="text-reset" href="' .. href(item.href, root) .. '" aria-label="'
        .. escape(item["aria-label"]) .. '"><i class="' .. class .. '" aria-hidden="true"></i></a>'
    else
      content = anchor(item.text, item.href, root, item.target)
    end
    links[#links + 1] = '<li class="list-inline-item">' .. content .. "</li>"
  end
  local html = '<div class="pkgdown-footer-left text-center text-sm-start">' .. left(root)
    .. '</div>\n<div class="pkgdown-footer-right text-center text-sm-end"><ul class="list-inline mb-0">'
    .. table.concat(links, "\n") .. "</ul></div>\n"

  local record = { border = true, left = left("") }
  -- pandoc.json encodes empty tables as objects, so omit empty lists.
  if #right > 0 then
    record.right = right
  end
  return record, html
end

-- Arguments: brand.yml, privacy href, Quarto metadata JSON, output directory.
-- quarto.yml is JSON, which is valid YAML.
function M.main(brand_path, privacy_href, metadata, output)
  local brand = brand_path ~= "" and M.parse(read(brand_path)) or {}
  local footer, html = M.render(brand, privacy_href ~= "" and privacy_href or nil)
  metadata = pandoc.json.decode(metadata, false)
  if footer ~= nil then
    metadata.website = metadata.website or {}
    metadata.website["page-footer"] = footer
  end
  pandoc.system.make_directory(output)
  write(output .. "/footer.html", html)
  write(output .. "/quarto.yml", next(metadata) and pandoc.json.encode(metadata) or "{}")
end

if arg and arg[0] and arg[0]:match("brand%.lua$") then
  M.main(table.unpack(arg))
end

return M
