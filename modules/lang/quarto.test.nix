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
        ;
      englishCloudflare = callFlakeWith {
        nullkomma.cloudflare.enable = true;
        nullkomma.cloudflare.worker = "fixture-site";
        nullkomma.privacy.languages = [
          {
            code = "en";
            label = "English";
          }
        ];
      } (root + "/tests/fixtures/quarto-branded");
      themed = callFlakeWith {
        nullkomma.brand.lib.brand = root + "/tests/fixtures/r-brand/_brand.yml";
      } (root + "/tests/fixtures/quarto-branded");
      nestedDocs = rawAt (root + "/tests/fixtures") {
        imports = [ nullkomma.flakeModules.default ];
        nullkomma.quarto = {
          enable = true;
          root = root + "/tests/fixtures/quarto-docs";
          privacy.page = "legal/privacy.qmd";
        };
        nullkomma.brand.lib.brand = root + "/tests/fixtures/site-brand/brand.yml";
        nullkomma.privacy.sections.local.markdown = {
          en = root + "/tests/fixtures/quarto-branded/_privacy/local.en.md";
          de = root + "/tests/fixtures/quarto-branded/_privacy/local.de.md";
        };
      };
      unbrandedDocs = rawAt (root + "/tests/fixtures") {
        imports = [ nullkomma.flakeModules.default ];
        nullkomma.quarto = {
          enable = true;
          root = root + "/tests/fixtures/quarto-docs";
        };
      };
      docs = callFlakeWith {
        nullkomma.brand.lib.brand = root + "/tests/fixtures/site-brand/brand.yml";
        perSystem.nullkomma.files = {
          "index.qmd" = {
            mode = "generated";
            commentPrefix = "<!--";
            commentSuffix = " -->";
            text = ''
              ---
              title: Fixture home
              ---

              ## Getting started

              {{< greeting >}}

              ```nix
              { answer = 42; }
              ```
            '';
          };
          "_quarto.yml" = {
            mode = "generated";
            commentPrefix = "#";
            text = ''
              project:
                type: nullkomma-docs
              website:
                repo-url: https://github.com/example/docs
                sidebar:
                  contents:
                    - section: Guides
                      contents:
                        - guide.qmd
            '';
          };
          "guide.qmd" = {
            mode = "generated";
            commentPrefix = "<!--";
            commentSuffix = " -->";
            text = ''
              ---
              title: Fixture guide
              ---

              ## Usage

              A second page.
            '';
          };
        };
      } (root + "/tests/fixtures/quarto-branded");
    in
    {
      nullkomma.nix.unit.tests.testQuartoGeneratesExtensionsAndPrivacyPage =
        let
          inherit ((perSystem fixtures.quarto-branded).nullkomma) files;
          privacy = files."privacy.qmd";
        in
        {
          expr = {
            extension = {
              inherit (files."_extensions/greeting") mode directory;
              source = builtins.pathExists (files."_extensions/greeting".source + "/greeting.lua");
            };
            privacy = {
              inherit (privacy) mode commentPrefix commentSuffix;
              startsWithFrontMatter = lib.hasPrefix "\n---\ntitle: \"Privacy Policy\"\n---\n" privacy.text;
            };
            ignored = lib.filter (
              line:
              lib.elem line [
                "/_extensions/greeting"
                "/privacy.qmd"
              ]
            ) (lib.splitString "\n" files.".gitignore".text);
            plainQuarto = (perSystem fixtures.quarto).nullkomma.files ? "privacy.qmd";
          };
          expected = {
            extension = {
              mode = "generated";
              directory = true;
              source = true;
            };
            privacy = {
              mode = "generated";
              commentPrefix = "<!--";
              commentSuffix = " -->";
              startsWithFrontMatter = true;
            };
            ignored = [
              "/_extensions/greeting"
              "/privacy.qmd"
            ];
            plainQuarto = false;
          };
        };
      checks = {
        quarto-unbranded-docs = pkgs.runCommand "nullkomma-quarto-unbranded-docs" { } ''
          site=${unbrandedDocs.packages.${system}.site}
          grep -qF 'id="quarto-sidebar"' "$site/index.html"
          grep -qF 'role="main"' "$site/guides/intro.html"
          ! grep -qF 'Shared fixture footer' "$site/index.html"
          test ! -e "$site/privacy.html"
          touch $out
        '';
        quarto-nested-docs = pkgs.runCommand "nullkomma-quarto-nested-docs" { } ''
          site=${nestedDocs.packages.${system}.site}
          grep -qF 'href="../legal/privacy.html"' "$site/guides/intro.html"
          grep -qF 'role="main"' "$site/guides/intro.html"
          test "$(grep -o 'role="main"' "$site/guides/intro.html" | wc -l)" -eq 1
          ! grep -qF 'id="TOC"' "$site/index.html"
          ! grep -qF '<button title="Copy to Clipboard"' "$site/index.html"
          test -f "$site/legal/privacy.html"
          touch $out
        '';
        quarto-docs = pkgs.runCommand "nullkomma-quarto-docs" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          python - ${docs.packages.${system}.site} <<'PY'
          import json
          from pathlib import Path
          import sys

          site = Path(sys.argv[1])
          home = (site / "index.html").read_text()
          guide = (site / "guide.html").read_text()
          assert 'id="quarto-sidebar"' in home
          assert 'id="quarto-search"' in home
          assert 'id="TOC"' in home
          assert "code-copy-button" in home
          assert "Fixture guide" in home and "Fixture guide" in guide
          assert "breadcrumb" in guide and "pagination" in guide
          assert "https://github.com/example/docs/edit/main/guide.qmd" in guide
          for page in [home, guide]:
              assert "Shared fixture footer" in page
              assert 'href="mailto:hello@example.org"' in page
              assert 'href="./privacy.html"' in page or 'href="privacy.html"' in page
              assert page.count("<footer") == 1
          css = "\n".join(path.read_text() for path in (site / "site_libs/bootstrap").glob("*.css")).lower()
          for token in ["#123456", "#abcdee", "arial"]:
              assert token in css, token
          assert any(entry["href"].startswith("guide.html") for entry in json.loads((site / "search.json").read_text()))
          PY
          touch $out
        '';
        quarto-site = pkgs.runCommand "nullkomma-quarto-site" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          site=${fixtures.quarto.packages.${system}.site}
          python - "$site/index.html" <<'PY'
          from html.parser import HTMLParser
          from pathlib import Path
          import sys

          class Document(HTMLParser):
              def handle_data(self, data):
                  self.text.append(data)

          document = Document()
          document.text = []
          document.feed(Path(sys.argv[1]).read_text())
          text = "".join(document.text)
          assert "Fixture home" in text
          assert "{ answer = 42; }" in text
          PY
          cmp ${root + "/tests/fixtures/quarto/_headers"} "$site/_headers"
          cmp ${root + "/tests/fixtures/quarto/_redirects"} "$site/_redirects"
          test ! -e "$site/privacy.html"
          touch $out
        '';
        quarto-branded-site =
          pkgs.runCommand "nullkomma-quarto-branded-site" { nativeBuildInputs = [ pkgs.python3 ]; }
            ''
              grep -qi '#123456' ${themed.packages.${system}.site}/site_libs/bootstrap/*.css
              cmp ${(perSystem themed).nullkomma.files."_brand".source}/assets/brand.svg ${
                root + "/tests/fixtures/r-brand/assets/brand.svg"
              }
              python - ${fixtures.quarto-branded.packages.${system}.site} ${
                englishCloudflare.packages.${system}.site
              } <<'PY'
              from html.parser import HTMLParser
              from pathlib import Path
              import sys

              class Document(HTMLParser):
                  def handle_data(self, data):
                      self.text.append(data)

              def text(path):
                  document = Document()
                  document.text = []
                  document.feed(Path(path).read_text())
                  return " ".join("".join(document.text).split())

              branded, english = sys.argv[1:]
              assert 'id="quarto-sidebar"' not in Path(f"{branded}/index.html").read_text()
              assert "Hello from an extension" in text(f"{branded}/index.html")
              privacy = text(f"{branded}/privacy.html")
              assert "Privacy Policy" in privacy
              assert "Generated by nullkomma" not in privacy
              assert "nav-tabs" in Path(f"{branded}/privacy.html").read_text()
              assert privacy.index("English") < privacy.index("Deutsch") < privacy.index("Local section in English") < privacy.index("Lokaler Abschnitt auf Deutsch")
              assert "Cloudflare" not in privacy
              privacy = text(f"{english}/privacy.html")
              assert "Deutsch" not in privacy
              assert privacy.index("Hosting, delivery, security and web analytics by Cloudflare") < privacy.index("Local section in English")
              PY
              touch $out
            '';
        quarto-preview =
          let
            quarto = pkgs.writeShellScriptBin "quarto" ''
              set -e
              test -f generated.txt
              test -f _extensions/nullkomma-docs/_extension.yml
              test -f _extensions/nullkomma-brand/landmarks.lua
              test -f _nullkomma-brand.yml
              printf '%s\n' "$PWD" "$@" > "$CALLED"
            '';
            flake = callFlakeWith (
              { self, ... }:
              {
                nullkomma.quarto.root = self.outPath + "/docs";
                perSystem = {
                  nullkomma.quarto.package = quarto;
                  nullkomma.files."docs/generated.txt" = {
                    mode = "generated";
                    commentPrefix = "#";
                    text = "preview generation";
                  };
                };
              }
            ) (root + "/tests/fixtures/quarto");
          in
          pkgs.runCommand "nullkomma-quarto-preview" { nativeBuildInputs = [ pkgs.git ]; } ''
            export CALLED=$PWD/called
            mkdir -p repo/docs/sub && cd repo/docs/sub && git init -q ../..
            ${task flake "preview"} --no-browser
            printf '%s\n' "$(cd ../.. && pwd)/docs" preview --no-browser > expected
            cmp expected "$CALLED"
            touch $out
          '';
      };
    };
}
