-- German law (§ 5 DDG, Art. 13 GDPR) requires an imprint and a privacy policy
-- reachable from every page, so missing chunks must fail loudly.
-- Arguments: site root, then its HTML pages relative to it.
local function read(path)
  local file = assert(io.open(path))
  local content = file:read("a")
  file:close()
  return content
end
local site = arg[1]
local addresses = {}
local function links(html, path)
  local footer = html:match("<footer.-</footer>")
  assert(footer, path .. ": no footer")
  for address in footer:gmatch('href="mailto:([^"?]+)') do
    addresses[address] = true
  end
  local found = {}
  for href, label in footer:gmatch('<a[^>]-href="([^"]*)"[^>]*>(.-)</a>') do
    found[label:gsub("<[^>]*>", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")] = href
  end
  return found
end
for i = 2, #arg do
  local page = arg[i]
  local found = links(read(site .. "/" .. page), page)
  local imprint = found.Imprint or found.Impressum
  assert(imprint and imprint:match("^https://"), page .. ": no imprint link in footer")
  local privacy = found.Privacy or found.Datenschutz
  assert(privacy, page .. ": no privacy link in footer")
  local depth = select(2, page:gsub("/", ""))
  assert(privacy == ("../"):rep(depth) .. "privacy.html" or privacy == "./" .. ("../"):rep(depth) .. "privacy.html",
    page .. ": privacy link " .. privacy .. " does not reach privacy.html")
end
local policy = pandoc.utils.stringify(pandoc.read(read(site .. "/privacy.html"), "html"))
local required = {
  -- Art. 13(1)(a): controller identity and contact, in both languages.
  "Controller", "Verantwortlicher", "Germany", "Deutschland", "@",
  -- Art. 13(1)(c): legal basis.
  "Art. 6(1)", "Art. 6 Abs. 1",
  -- Art. 13(2)(b): data subject rights.
  "Art. 15 GDPR", "Art. 16 GDPR", "Art. 17 GDPR", "Art. 18 GDPR", "Art. 20 GDPR", "Art. 21 GDPR",
  "Art. 15 DSGVO", "Art. 16 DSGVO", "Art. 17 DSGVO", "Art. 18 DSGVO", "Art. 20 DSGVO", "Art. 21 DSGVO",
  -- Art. 13(2)(c): withdrawing consent.
  "withdraw", "widerrufen",
  -- Art. 13(2)(d): complaint to a supervisory authority.
  "Art. 77 GDPR", "Art. 77 DSGVO",
  -- Art. 13(2)(f): automated decision-making.
  "Art. 22 GDPR", "Art. 22 DSGVO",
}
-- Art. 13 also covers contact by email: offered addresses must be disclosed.
for address in pairs(addresses) do
  table.insert(required, address)
  table.insert(required, "email")
  table.insert(required, "E-Mail")
end
for _, text in ipairs(required) do
  assert(policy:find(text, 1, true), "privacy policy lacks: " .. text)
end
