{
  partitions.dev.module.perSystem =
    { config, pkgs, ... }:
    {
      checks.site =
        pkgs.runCommand "nullkomma-documentation-site" { nativeBuildInputs = [ pkgs.python3 ]; }
          ''
            python - ${config.packages.site} <<'PY'
            from html.parser import HTMLParser
            from pathlib import Path
            from urllib.parse import unquote, urlsplit
            import json
            import sys

            class Document(HTMLParser):
                def __init__(self, path):
                    super().__init__()
                    self.ids = set()
                    self.links = []
                    self.feed(path.read_text())

                def handle_starttag(self, tag, attrs):
                    attrs = dict(attrs)
                    if "id" in attrs:
                        self.ids.add(attrs["id"])
                    if tag == "a" and "href" in attrs:
                        self.links.append(attrs["href"])

            site = Path(sys.argv[1])
            pages = {path: Document(path) for path in site.glob("*.html")}
            home = pages[site / "index.html"]
            assert {"getting-started", "plugins", "your-flake-outputs", "development", "quarto-search", "quarto-sidebar", "TOC"} <= home.ids
            assert "https://github.com/dataheld/nullkomma" in home.links
            assert "https://github.com/dataheld/nullkomma/edit/main/index.qmd" in home.links
            assert "https://github.com/dataheld/nullkomma/blob/main/index.qmd" in home.links
            assert any(link.startswith("https://github.com/dataheld/nullkomma/issues/new") for link in home.links)
            for path, page in pages.items():
                assert "https://www.maxheld.de/imprint.html" in page.links, path
                assert any(urlsplit(link).path.removeprefix("./") == "privacy.html" for link in page.links), path
                for link in page.links:
                    url = urlsplit(link)
                    if url.scheme or url.netloc:
                        continue
                    target = path.parent / unquote(url.path) if url.path else path
                    assert target.exists(), (path, link)
                    if url.fragment and target in pages:
                        assert unquote(url.fragment) in pages[target].ids, (path, link)
            search = json.loads((site / "search.json").read_text())
            assert any(entry["href"] == "index.html#getting-started" and "nix flake init" in entry["text"] for entry in search)
            css = "\n".join(path.read_text() for path in (site / "site_libs/bootstrap").glob("*.css"))
            assert "#453aa4" in css.lower()
            assert 'data-mode="dark"' in (site / "index.html").read_text()
            dark = next((site / "site_libs/bootstrap").glob("bootstrap-dark-*.css")).read_text()
            assert "nav.sidebar.sidebar-navigation:not(.rollup)" in dark and "background-color:var(--bs-body-bg)" in dark
            assert "background-color:var(--bs-tertiary-bg)" in dark
            PY
            touch $out
          '';
    };
}
