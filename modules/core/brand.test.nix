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
            assert(footer.center == '<a href="https://example.org/imprint">Imprint</a>', footer.center)
            assert(not html:find("Privacy", 1, true))
            assert(html:find('href="mailto:hello@example.org"', 1, true))
            footer, html = brand.render(brand.parse(fixture:gsub("name: [^\n]*", 'name: "A & B"', 1)), "legal/privacy.html")
            assert(html:find("A &amp; B", 1, true), html)
            assert(footer.center:find(' · <a href="legal/privacy.html">Privacy</a>$'), footer.center)
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
