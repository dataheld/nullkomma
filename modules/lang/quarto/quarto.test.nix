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
        summary
        linkcheck
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
        nullkomma.brand = lib.mkForce { lib.brand = root + "/tests/fixtures/r-brand/_brand.yml"; };
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
    in
    {
      nullkomma.nix.unit.tests.testQuartoBrandFeature = {
        expr =
          let
            enabled = rawAt (root + "/tests/fixtures/quarto") {
              imports = [ nullkomma.flakeModules.quarto ];
              nullkomma.brand.lib.brand = root + "/tests/fixtures/site-brand/brand.yml";
              nullkomma.quarto = {
                enable = true;
                brand.enable = true;
              };
            };
            inactive = rawAt (root + "/tests/fixtures/md") {
              imports = [ nullkomma.flakeModules.quarto ];
              nullkomma.quarto.brand.enable = true;
            };
            defaults = (perSystem fixtures.quarto).nullkomma.files;
          in
          {
            enabled = (perSystem enabled).nullkomma.files ? "_nullkomma-brand.yml";
            noCompanionExport =
              !(nullkomma.flakeModules ? quarto-website-brand)
              && !(nullkomma.modules.flake ? quarto-website-brand);
            parentOff = summary inactive == summary (rawAt (root + "/tests/fixtures/md") { });
            optIn = !(defaults ? "_nullkomma-brand.yml") && !(defaults ? "_extensions/nullkomma-brand");
            nkdocs = defaults ? "_extensions/nkdocs";
          };
        expected = {
          enabled = true;
          noCompanionExport = true;
          parentOff = true;
          optIn = true;
          nkdocs = true;
        };
      };
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
            mermaid = builtins.pathExists (files."_extensions/nullkomma-brand".source + "/mermaid.scss");
            privacy = {
              inherit (privacy) mode commentPrefix commentSuffix;
              startsWithFrontMatter = lib.hasPrefix "\n---\ntitle: \"Privacy Policy\"\nsidebar: false\n---\n" privacy.text;
            };
            ignored = lib.filter (
              line:
              lib.elem line [
                "/_extensions/greeting"
                "/privacy.qmd"
              ]
            ) (lib.splitString "\n" files.".gitignore".text);
            plainQuarto = (perSystem fixtures.quarto).nullkomma.files ? "privacy.qmd";
            plainQuartoBrand = (perSystem fixtures.quarto).nullkomma.files ? "_extensions/nullkomma-brand";
          };
          expected = {
            extension = {
              mode = "generated";
              directory = true;
              source = true;
            };
            mermaid = true;
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
            plainQuartoBrand = false;
          };
        };
      checks = {
        quarto-nkdocs = linkcheck "quarto-nkdocs" nkdocs.packages.${system}.site;
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
              } ${nkdocs.packages.${system}.site} ${themed.packages.${system}.site} <<'PY'
              from html.parser import HTMLParser
              from pathlib import Path
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

              branded, english, nkdocs, themed = sys.argv[1:]
              mappings = {
                  "--mermaid-edge-color": "--bs-secondary-color",
                  "--mermaid-label-fg-color": "--bs-body-color",
                  "--mermaid-node-bg-color": "--bs-primary-bg-subtle",
                  "--mermaid-fg-color--lightest": "--bs-tertiary-bg",
                  "--mermaid-fg-color--lighter": "--bs-border-color",
              }
              for site, primary in [(branded, "#6f42c1"), (themed, "#123456")]:
                  html = Path(f"{site}/index.html").read_text()
                  assert "Related steps" in html and "mermaid" in html
                  assert 'name="mermaid-theme"' not in html
                  assert 'name="mermaid-theme" content="forest"' in Path(f"{site}/forest.html").read_text()
                  themes = Stylesheets(html).themes
                  assert len(themes) == 2, themes
                  for mode in ["quarto-color-scheme", "quarto-color-scheme quarto-color-alternate"]:
                      css = Path(site, themes[mode]).read_text()
                      assert f"--bs-primary: {primary}" in css, primary
                      for mermaid, bootstrap in mappings.items():
                          assert f"{mermaid}: var({bootstrap})" in css, (mode, mermaid)
                      assert 'html:not(:has(meta[name=mermaid-theme])) svg.mermaid-js .labelBkg' in css
                      assert 'html:not(:has(meta[name=mermaid-theme])) svg.mermaid-js .edgeLabel p' in css
              left, right = Path(f"{branded}/index.html").read_text().split('<div class="nav-footer-right">')
              assert "Shared fixture footer" in left
              assert "Imprint" not in left
              assert "Imprint" in right and "Privacy" in right and "bi-envelope" in right
              # nkdocs alone is brand-free.
              assert "Imprint" not in Path(f"{nkdocs}/index.html").read_text()
              assert 'id="quarto-sidebar"' not in Path(f"{nkdocs}/legal/privacy.html").read_text()
              assert 'id="quarto-sidebar"' in Path(f"{nkdocs}/index.html").read_text()
              # Quarto's default floating sidebar keeps pages centred on wide screens.
              body = Path(f"{nkdocs}/index.html").read_text().split("<body", 1)[1].split(">", 1)[0]
              assert "floating" in body and "docked" not in body, body
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
        quarto-preview =
          let
            quarto = pkgs.writeShellScriptBin "quarto" ''
              set -e
              if [[ -z "''${CALLED-}" ]]; then
                test -e generated.txt
              else
                # Generating files is the dev shell's job, not the tasks'.
                test ! -e generated.txt
                printf '%s\n' "$PWD" "$@" > "$CALLED"
              fi
              if [[ "$1" == render ]]; then
                mkdir -p _site
                cp task-override.txt _site/
              fi
            '';
            flake = callFlakeWith (
              { self, ... }:
              {
                nullkomma.quarto.root = self.outPath + "/docs";
                perSystem = {
                  nullkomma.quarto.package = quarto;
                  process-compose.dev.settings.processes = {
                    task-override = {
                      working_dir = "./docs";
                      command = "echo 'shared Quarto workflow' > task-override.txt";
                    };
                    build-site.depends_on.task-override.condition = "process_completed_successfully";
                  };
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
            ${task flake "build-site"} --to html
            printf '%s\n' "$(cd ../.. && pwd)/docs" render --to html > expected
            cmp expected "$CALLED"
            grep -qxF 'shared Quarto workflow' ../task-override.txt
            cmp ../task-override.txt ${flake.packages.${system}.site}/task-override.txt
            touch $out
          '';
      };
    };
}
