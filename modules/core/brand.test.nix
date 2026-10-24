{
  partitions.dev.module.perSystem =
    { pkgs, ... }:
    {
      checks.brand-footer =
        pkgs.runCommand "nullkomma-brand-footer" { nativeBuildInputs = [ pkgs.pandoc ]; }
          ''
            cat > test.lua <<'LUA'
            local brand = dofile("${../../lib/brand.lua}")
            local fixture = io.open("${../../tests/fixtures/site-brand/brand.yml}"):read("a")
            local footer, html = brand.render(brand.parse(fixture), nil)
            local imprint = '<a class="text-reset" href="https://example.org/imprint" target="_blank" rel="noopener noreferrer">Imprint</a>'
            assert(footer.center == nil)
            assert(#footer.right == 2)
            assert(footer.right[1].text == "Imprint")
            assert(footer.right[1].target == "_blank" and footer.right[1].rel == "noopener noreferrer")
            assert(footer.right[2].icon == "envelope")
            assert(footer.right[2]["aria-label"] == "Email")
            assert(html:find('class="pkgdown-footer-left text-center text-sm-start"', 1, true), html)
            assert(html:find('class="pkgdown-footer-right text-center text-sm-end"', 1, true), html)
            assert(not html:find("footer-center", 1, true), html)
            assert(html:find(imprint, 1, true), html)
            assert(not html:find("Privacy", 1, true))
            assert(html:find('href="mailto:hello@example.org"', 1, true))
            footer, html = brand.render(brand.parse(fixture:gsub("name: [^\n]*", 'name: "A & B"', 1)), "legal/privacy.html")
            assert(html:find("A &amp; B", 1, true), html)
            assert(footer.center == nil and #footer.right == 3)
            assert(footer.right[2].text == "Privacy" and footer.right[2].href == "legal/privacy.html")
            assert(footer.right[3].icon == "envelope")
            assert(html:find('href="{{#site}}{{root}}{{/site}}legal/privacy.html"', 1, true), html)
            assert(not html:find('{{#site}}{{root}}{{/site}}https:', 1, true), html)
            local minimal = brand.parse(fixture)
            minimal.defaults.nullkomma.footer.links = nil
            minimal.defaults.nullkomma.footer.social = nil
            footer, html = brand.render(minimal, nil)
            assert(footer.center == nil and footer.right == nil)
            assert(html:find("Shared fixture footer", 1, true), html)
            assert(select("#", brand.render({}, nil)) == 2 and brand.render({}, nil) == nil)
            local ok, err = pcall(brand.render, brand.parse(fixture:gsub("name: [^\n]*", "name: \"*Example*\"", 1)), nil)
            assert(not ok and err:find("plain text", 1, true), err)
            ok, err = pcall(brand.render, brand.parse("defaults:\n  nullkomma:\n    footer: invalid"), nil)
            assert(not ok and err:find("must be a mapping", 1, true), err)
            LUA
            pandoc lua test.lua
            touch $out
          '';
    };
}
