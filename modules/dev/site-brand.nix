{
  partitions.dev.module =
    { inputs, ... }:
    {
      perSystem =
        {
          harness,
          pkgs,
          system,
          ...
        }:
        let
          branded = harness.callFlakeWith {
            nullkomma.brand = inputs.brand;
          } (harness.root + "/tests/fixtures/r");
        in
        {
          checks.site-brand-footer =
            pkgs.runCommand "nullkomma-site-brand-footer" { nativeBuildInputs = [ pkgs.pandoc ]; }
              ''
                cat > test.lua <<'LUA'
                local brand = dofile("${../../lib/brand.lua}")
                local fixture = io.open("${../../tests/fixtures/site-brand/brand.yml}"):read("a")
                local footer, html = brand.render(brand.parse(fixture), nil, "")
                assert(#footer.center == 1)
                assert(footer.center[1].text == "Imprint" and footer.center[1].href == "https://example.org/imprint")
                assert(not html:find("Privacy", 1, true))
                assert(html:find('href="mailto:hello@example.org"', 1, true))
                footer, html = brand.render(brand.parse(fixture:gsub("name: [^\n]*", 'name: "A & B"', 1)), "legal/privacy.html", "")
                assert(html:find("A &amp; B", 1, true), html)
                assert(footer.center[#footer.center].text == "Privacy")
                assert(footer.center[#footer.center].href == "legal/privacy.html")
                assert(select("#", brand.render({}, nil, "")) == 2 and brand.render({}, nil, "") == nil)
                local ok, err = pcall(brand.render, brand.parse(fixture:gsub("name: [^\n]*", "name: \"*Example*\"", 1)), nil, "")
                assert(not ok and err:find("plain text", 1, true), err)
                ok, err = pcall(brand.render, brand.parse("defaults:\n  nullkomma:\n    footer: invalid"), nil, "")
                assert(not ok and err:find("must be a mapping", 1, true), err)
                LUA
                pandoc lua test.lua
                touch $out
              '';
          checks.site-brand-pkgdown = pkgs.runCommand "nullkomma-site-brand-pkgdown" { } ''
            site=${branded.packages.${system}.site}
            grep -qF 'href="https://www.maxheld.de/imprint.html"' "$site/index.html"
            grep -qF 'href="../privacy.html"' "$site/reference/hello.html"
            grep -qF 'data-bs-theme' "$site/index.html"
            test "$(grep -o '<footer' "$site/reference/hello.html" | wc -l)" -eq 1
            grep -qFi '#453aa4' "$site"/deps/bootstrap-*/*.css
            grep -qF '#212529' "$site"/deps/bootstrap-*/*.css
            grep -qF '#dee2e6' "$site"/deps/bootstrap-*/*.css
            grep -qF 'system-ui' "$site"/deps/bootstrap-*/*.css
            touch $out
          '';
        };
    };
}
