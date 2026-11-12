{
  partitions.dev.module.perSystem =
    {
      harness,
      lib,
      pkgs,
      system,
      ...
    }:
    let
      inherit (harness)
        callFlakeWith
        fixtures
        perSystem
        root
        task
        rawAt
        nullkomma
        linkcheck
        ;
      themed = callFlakeWith {
        nullkomma.brand = lib.mkForce { lib.brand = root + "/tests/fixtures/r-brand/_brand.yml"; };
        nullkomma.privacy.languages = [
          {
            code = "en";
            label = "English";
          }
        ];
      } (root + "/tests/fixtures/quarto-branded");
      nkdocs = rawAt (root + "/tests/fixtures") {
        imports = [ nullkomma.flakeModules.default ];
        nullkomma.quarto = {
          enable = true;
          root = root + "/tests/fixtures/quarto-nkdocs";
          privacy.page = "legal/privacy.qmd";
        };
        nullkomma.privacy.sections.local.markdown = {
          en = root + "/tests/fixtures/quarto-branded/_privacy/local.en.md";
          de = root + "/tests/fixtures/quarto-branded/_privacy/local.de.md";
        };
      };
      linked = callFlakeWith {
        perSystem.nullkomma.quarto.package = pkgs.writeShellScriptBin "quarto" ''
          mkdir -p _site source-assets
          printf '%s\n' 'linked site resource' > source-assets/logo.svg
          ln -s ../source-assets _site/assets
          ln -s ../source-assets/logo.svg _site/logo.svg
        '';
      } (root + "/tests/fixtures/quarto");
    in
    {
      checks = {
        quarto-site-resources = pkgs.runCommand "quarto-site-resources" { } ''
          site=${linked.packages.${system}.site}
          test ! -L "$site/logo.svg"
          test ! -L "$site/assets"
          grep -Fx 'linked site resource' "$site/logo.svg"
          cmp "$site/logo.svg" "$site/assets/logo.svg"
          touch "$out"
        '';
        quarto-nkdocs = linkcheck "quarto-nkdocs" nkdocs.packages.${system}.site;
        quarto-site = pkgs.runCommand "nullkomma-quarto-site" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          test ! -e ${fixtures.quarto.packages.${system}.site}/privacy.html
          grep -qi '#123456' ${themed.packages.${system}.site}/site_libs/bootstrap/*.css
          cmp ${(perSystem themed).nullkomma.files."_brand".source}/assets/brand.svg ${
            root + "/tests/fixtures/r-brand/assets/brand.svg"
          }
          python - ${fixtures.quarto.packages.${system}.site} ${
            fixtures.quarto-branded.packages.${system}.site
          } ${themed.packages.${system}.site} <<'PY'
          from html.parser import HTMLParser
          from pathlib import Path
          import re
          import sys

          class Document(HTMLParser):
              def handle_data(self, data):
                  self.text.append(data)

          class Stylesheets(HTMLParser):
              def __init__(self, html):
                  super().__init__()
                  self.themes = {}
                  self.feed(html)

              def handle_starttag(self, tag, attrs):
                  attrs = dict(attrs)
                  if tag == "link" and attrs.get("id") == "quarto-bootstrap":
                      self.themes[attrs["class"]] = attrs["href"]

          def text(path):
              document = Document()
              document.text = []
              document.feed(Path(path).read_text())
              return " ".join("".join(document.text).split())

          plain, branded, themed = sys.argv[1:]
          assert "Fixture home" in text(f"{plain}/index.html")
          assert "{ answer = 42; }" in text(f"{plain}/index.html")
          html = Path(f"{branded}/index.html").read_text()
          assert 'class="console"' in html and "Plain console output" in html
          assert "Related steps" in html and "mermaid" in html
          assert 'name="mermaid-theme"' not in html
          assert 'name="mermaid-theme" content="forest"' in Path(f"{branded}/forest.html").read_text()
          themes = Stylesheets(html).themes
          assert len(themes) == 2, themes
          for mode in ["quarto-color-scheme", "quarto-color-scheme quarto-color-alternate"]:
              css = Path(branded, themes[mode]).read_text()
              assert "--bs-primary: #6f42c1" in css, mode
              assert "--mermaid-edge-color: var(--bs-secondary-color)" in css, mode
              assert 'html:not(:has(meta[name=mermaid-theme])) svg.mermaid-js .labelBkg' in css, mode
              if mode.endswith("quarto-color-alternate"):
                  pre = re.search(r"(?:^|})pre\{([^}]*)\}", css).group(1)
                  assert re.search(r"(?:^|;)color:#dee2e6(?:;|$)", pre), pre
          left, right = html.split('<div class="nav-footer-right">')
          assert "Shared fixture footer" in left
          assert "Imprint" not in left
          assert "Imprint" in right and "Privacy" in right and "bi-envelope" in right
          assert "Hello from an extension" in text(f"{branded}/index.html")
          privacy = text(f"{branded}/privacy.html")
          assert "Privacy Policy" in privacy
          assert "Generated by nullkomma" not in privacy
          assert "nav-tabs" in Path(f"{branded}/privacy.html").read_text()
          assert privacy.index("English") < privacy.index("Deutsch") < privacy.index("Local section in English") < privacy.index("Lokaler Abschnitt auf Deutsch")
          english = Path(f"{themed}/privacy.html").read_text()
          assert "Local section in English" in english and "nav-tabs" not in english
          PY
          touch $out
        '';
        # Quarto logs, rather than fails on, filter errors, so walk a table with
        # its AST walker on the Pandoc it actually runs. Keep this after
        # https://github.com/dataheld/nullkomma/issues/212 drops the patch.
        quarto-pandoc =
          let
            quarto = (perSystem fixtures.quarto).nullkomma.quarto.package;
          in
          pkgs.runCommand "nullkomma-quarto-pandoc" { nativeBuildInputs = [ quarto ]; } ''
            cat > walk.lua <<'LUA'
            package.path = "${quarto}/share/filters/modules/?.lua;" .. package.path
            require 'jog'(pandoc.read("| a |\n|---|\n| 1 |\n", "markdown"), { Str = function() end })
            LUA
            HOME=$TMPDIR quarto pandoc lua walk.lua
            touch $out
          '';
        # Real quarto, since the opener depends on the exact line it logs.
        quarto-preview-opens =
          let
            fixture = root + "/tests/fixtures/quarto";
            flake = callFlakeWith {
              perSystem.nullkomma.browse.command = "${pkgs.writeShellScript "browser" ''echo "$1" > "$TMPDIR/opened"''}";
            } fixture;
          in
          pkgs.runCommand "nullkomma-quarto-preview-opens"
            {
              nativeBuildInputs = [
                pkgs.curl
                pkgs.lsof
              ];
              __darwinAllowLocalNetworking = true;
            }
            ''
              ${harness.project fixture}
              set -m
              PC_DISABLE_TUI=1 ${task flake "quarto-preview"} > "$TMPDIR/preview.log" 2>&1 &
              pid=$!
              trap 'kill "$pid"; wait "$pid" || true' EXIT
              logs=("$TMPDIR/preview.log")
              awaiting 'test -s "$TMPDIR/opened"' "$pid"
              curl --noproxy '*' --fail --silent --show-error "$(cat "$TMPDIR/opened")" > index.html || {
                cat -v "$TMPDIR/opened" "$TMPDIR/preview.log" >&2
                exit 1
              }
              grep -qF 'Fixture home' index.html
              touch $out
            '';
        quarto-preview =
          let
            quarto = pkgs.writeShellScriptBin "quarto" ''
              printf '%s\n' "$PWD" "$@" > "$CALLED"
              if [[ "$1" == preview ]]; then
                echo 'Browse at http://localhost:4200/'
                exec ${pkgs.python3}/bin/python3 -m http.server --bind 127.0.0.1 --directory "$SERVED" 0 2>> "$REQUESTS"
              fi
            '';
            flake = callFlakeWith (
              { self, ... }:
              {
                nullkomma.quarto.root = self.outPath + "/docs";
                perSystem.nullkomma = {
                  quarto.package = quarto;
                  browse.command = "${pkgs.coreutils}/bin/true";
                };
              }
            ) (root + "/tests/fixtures/quarto");
          in
          pkgs.runCommand "nullkomma-quarto-preview"
            {
              # process-compose finds ports with lsof on macOS, which has it outside the sandbox.
              nativeBuildInputs = [
                pkgs.git
                pkgs.lsof
              ];
              __darwinAllowLocalNetworking = true;
            }
            ''
              export CALLED=$PWD/called REQUESTS=$PWD/requests SERVED=$PWD/served
              render=90B3C9E8-0DBC-4BC0-B164-AA2D5C031B28/index.qmd
              mkdir -p "$SERVED/''${render%/*}" && echo rendered > "$SERVED/$render"
              mkdir -p repo/docs/sub && cd repo/docs/sub && git init -q ../..
              echo '{{< include ../README.md >}}' > ../index.qmd
              # A stopped process-compose signals its whole process group, so the builder needs its own.
              set -m
              PC_DISABLE_TUI=1 ${task flake "quarto-preview"} > preview.log 2>&1 &
              pid=$!
              trap 'kill "$pid"; wait "$pid" || true' EXIT
              # Quarto re-renders pages whose included files changed only when asked to.
              for attempt in {1..60}; do
                echo "edit $attempt" >> ../../README.md
                if grep -qF "GET /$render " "$REQUESTS" 2>/dev/null; then
                  break
                fi
                sleep 1
              done
              grep -qF "GET /$render " "$REQUESTS" || { cat preview.log >&2; exit 1; }
              kill "$pid"
              wait "$pid" || true
              trap - EXIT
              printf '%s\n' "$(cd ../.. && pwd)/docs" preview --no-browser > expected
              cmp expected "$CALLED"
              ${task flake "quarto-render"} --to html
              printf '%s\n' "$(cd ../.. && pwd)/docs" render --to html > expected
              cmp expected "$CALLED"
              touch $out
            '';
      };
    };
}
