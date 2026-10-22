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
      render =
        package: postRender:
        callFlakeWith {
          nullkomma.quarto.renderArgs = [ "--no-clean" ];
          perSystem.nullkomma.quarto = {
            inherit package postRender;
            runtimeInputs = [ pkgs.hello ];
          };
        } (root + "/tests/fixtures/quarto");
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
        quarto-r-site =
          let
            flake = callFlakeWith {
              nullkomma = {
                quarto.enable = true;
                r.pkgdown.enable = false;
                r.extraPackages = [ "rmarkdown" ];
              };
              perSystem =
                { config, ... }:
                {
                  nullkomma.quarto.runtimeInputs = [ config.nullkomma.r.package ];
                  nullkomma.files = {
                    "_quarto.yml" = {
                      mode = "generated";
                      commentPrefix = "#";
                      text = ''
                        project:
                          type: website
                      '';
                    };
                    "index.qmd" = {
                      mode = "generated";
                      commentPrefix = "<!--";
                      commentSuffix = " -->";
                      text = ''
                        # R rendering

                        ```{r}
                        stopifnot(l10n_info()[["UTF-8"]])
                        cat(paste0("Answer: ", 6 * 7, "; Grüße"))
                        ```
                      '';
                    };
                  };
                };
            } (root + "/tests/fixtures/r");
          in
          pkgs.runCommand "nullkomma-quarto-r-site" { } ''
            grep -q 'Answer: 42; Grüße' ${flake.packages.${system}.site}/index.html
            touch "$out"
          '';
        quarto-render-runtime =
          let
            quarto = pkgs.writeShellScriptBin "quarto" ''
              set -eu
              test "$*" = "render --no-clean --output-dir $out"
              hello
              mkdir "$out"
              echo rendered > "$out/index.html"
            '';
            flake = render quarto ''
              grep -q 'Hello, world!' render.log
              grep -q rendered "$out/index.html"
            '';
          in
          flake.packages.${system}.site;
        quarto-render-failure = pkgs.testers.testBuildFailure' {
          name = "nullkomma-quarto-render-failure";
          drv =
            (render (pkgs.writeShellScriptBin "quarto" ''
              echo 'render failed'
              exit 9
            '') "").packages.${system}.site;
          expectedBuilderExitCode = 9;
          expectedBuilderLogEntries = [ "render failed" ];
        };
        quarto-post-render-failure = pkgs.testers.testBuildFailure' {
          name = "nullkomma-quarto-post-render-failure";
          drv =
            (render (pkgs.writeShellScriptBin "quarto" "echo 'render succeeded'") ''
              grep -q 'render succeeded' render.log
              echo 'post-render failed'
              exit 8
            '').packages.${system}.site;
          expectedBuilderExitCode = 8;
          expectedBuilderLogEntries = [ "post-render failed" ];
        };
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
              test -f generated.txt
              hello > "$CALLED-runtime"
              printf '%s\n' "$PWD" "$@" > "$CALLED"
            '';
            flake = callFlakeWith (
              { self, ... }:
              {
                nullkomma.quarto.root = self.outPath + "/docs";
                perSystem = {
                  nullkomma.quarto = {
                    package = quarto;
                    runtimeInputs = [ pkgs.hello ];
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
            grep -q 'Hello, world!' "$CALLED-runtime"
            touch $out
          '';
      };
    };
}
