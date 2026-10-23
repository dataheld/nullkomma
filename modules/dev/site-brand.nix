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
            pkgs.runCommand "nullkomma-site-brand-footer"
              { nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ]; }
              ''
                python - ${../../lib/brand.py} ${../../tests/fixtures/site-brand/brand.yml} <<'PY'
                from pathlib import Path
                import runpy
                import sys

                import yaml

                render = runpy.run_path(sys.argv[1])["render"]
                brand = yaml.safe_load(Path(sys.argv[2]).read_text())
                footer, html = render(brand, None, "")
                assert footer["center"] == [{"text": "Imprint", "href": "https://example.org/imprint"}]
                assert "Privacy" not in html
                assert 'href="mailto:hello@example.org"' in html
                brand["meta"]["name"] = "<Example>"
                footer, html = render(brand, "legal/privacy.html", "")
                assert "&lt;Example&gt;" in html and "<Example>" not in html
                assert footer["center"][-1] == {"text": "Privacy", "href": "legal/privacy.html"}
                assert render({}, None, "") == (None, "")
                brand["defaults"]["nullkomma"]["footer"] = "invalid"
                try:
                    render(brand, None, "")
                except ValueError as error:
                    assert "must be a mapping" in str(error)
                else:
                    raise AssertionError("invalid footer record was accepted")
                PY
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
