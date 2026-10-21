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
        callFlake
        callFlakeWith
        fixtures
        nullkomma
        perSystem
        project
        rawAt
        root
        task
        runCheck
        treefmt
        ;
      rlib = import (root + "/lib/r.nix") { inherit lib; };
      fixture = root + "/tests/fixtures/r";
      privacy = root + "/tests/fixtures/quarto-branded/_privacy";
      local = {
        order = 100;
        markdown = {
          en = privacy + "/local.en.md";
          de = privacy + "/local.de.md";
        };
      };
      cloudflare = {
        enable = true;
        worker = "r-fixture-site";
      };
      branded = callFlakeWith {
        nullkomma.brand = {
          lib.brand = root + "/tests/fixtures/r-brand/_brand.yml";
          lib.footer = builtins.toFile "fixture-footer.html" ''
            <footer id="shared-brand">Shared brand footer · 🌲 <a href="privacy.html">Privacy</a></footer>
          '';
          flakeModules.privacy.nullkomma.privacy.sections.brand = local;
        };
        nullkomma.r.pkgdown.assets = root + "/tests/fixtures/r-brand/assets";
        nullkomma.cloudflare = cloudflare;
      } fixture;
      english = callFlakeWith {
        nullkomma.cloudflare = cloudflare;
        nullkomma.privacy.sections.local = local;
        nullkomma.privacy.languages = [
          {
            code = "en";
            label = "English";
          }
        ];
        nullkomma.r.pkgdown.privacy.page = "legal.md";
      } fixture;
      withoutLock = callFlake (
        builtins.path {
          name = "r-without-lock";
          path = fixture;
          filter = path: _: baseNameOf path != "pkg.lock";
        }
      );
      nested = rawAt (root + "/tests/fixtures") {
        imports = [ nullkomma.flakeModules.default ];
        nullkomma.r = {
          enable = true;
          root = fixture;
        };
      };
      check =
        name: script:
        pkgs.runCommand "nullkomma-${name}"
          {
            nativeBuildInputs = [
              pkgs.git
              (perSystem fixtures.r).nullkomma.r.package
            ];
          }
          ''
            ${project fixture}
            ${script}
            touch $out
          '';
    in
    {
      nullkomma.nix.unit.tests = {
        testRAttributeNames = {
          expr = map rlib.attrName [
            "data.table"
            "import"
            "assert"
            "R6"
          ];
          expected = [
            "data_table"
            "r_import"
            "r_assert"
            "R6"
          ];
        };
        testRLockReader = {
          expr =
            let
              deps = {
                type = "deps";
                dep_types = rlib.defaultFields;
              };
              github = {
                type = "github";
                package = "withr";
                ref = "r-lib/withr@abc";
                version = "1.0";
                dependencies = [ ];
                metadata = {
                  RemoteUsername = "r-lib";
                  RemoteRepo = "withr";
                  RemoteSha = "abc";
                };
              };
              standard = {
                type = "standard";
                package = "data.table";
                ref = "data.table";
                version = "1.0";
                dependencies = [ ];
                metadata = { };
                sources = [ "https://example.org/data.table.tar.gz" ];
              };
              read =
                args: packages:
                rlib.readLock (
                  {
                    lock = {
                      lockfile_version = 1;
                      packages = [ deps ] ++ packages;
                    };
                    available.data_table = { };
                  }
                  // args
                );
              fails = args: packages: !(builtins.tryEval (builtins.deepSeq (read args packages) null)).success;
            in
            {
              standard = (read { } [ standard ]).nixpkgs;
              commit = (read { allowOffNixpkgs = true; } [ github ]).sources.withr.fetchTree.rev;
              rejects = [
                (fails { } [ github ])
                (fails { } [ (standard // { ref = "data.table@1.0"; }) ])
                (fails { available = { }; } [ standard ])
                (fails {
                  allowOffNixpkgs = true;
                  available = { };
                } [ standard ])
                (fails { allowOffNixpkgs = true; } [ (github // { type = "local"; }) ])
                (fails { fields = [ "Imports" ]; } [ ])
                (fails {
                  lock = {
                    lockfile_version = 2;
                    packages = [ deps ];
                  };
                } [ ])
              ];
            };
          expected = {
            standard = [ "data.table" ];
            commit = "abc";
            rejects = lib.replicate 7 true;
          };
        };
        testRRequiresDescription = {
          expr =
            (perSystem (callFlakeWith { nullkomma.r.enable = true; } (root + "/tests/fixtures/md")))
            .nullkomma.r.packages;
          expectedError.msg = "`DESCRIPTION` is missing";
        };
        testRRequiresLock = {
          expr = (perSystem withoutLock).nullkomma.r.packages;
          expectedError.msg = "lockfile `pkg.lock` of DESCRIPTION is missing";
        };
        testRIncludesPkgloadForDevelopment = {
          expr = lib.elem "pkgload" (perSystem fixtures.r).nullkomma.r.packages;
          expected = true;
        };
        testRLockBootstrapsWithoutLock = {
          expr = lib.isString withoutLock.packages.${system}.r-lock.drvPath;
          expected = true;
        };
        testRRejectsUnknownPackages = {
          expr =
            (perSystem (callFlakeWith { nullkomma.r.extraPackages = [ "notarealpackage" ]; } fixture))
            .nullkomma.r.package.drvPath;
          expectedError.msg = "`notarealpackage` is not in nixpkgs";
        };
      };
      checks = {
        r-pkgdown-site =
          pkgs.runCommand "nullkomma-r-pkgdown-site" { nativeBuildInputs = [ pkgs.python3 ]; }
            ''
              site=${branded.packages.${system}.site}
              epoch="$(date -u -d "@$SOURCE_DATE_EPOCH" +%Y-%m-%dT%H:%MZ)"
              grep -qF "last_built: $epoch" "$site/pkgdown.yml"
              test "$(grep -o '<footer' "$site/index.html" | wc -l)" -eq 1
              grep -qF '#123456' "$site"/deps/bootstrap-*/*.css
              cmp ${root + "/tests/fixtures/r-brand/assets/brand.svg"} "$site/brand.svg"
              python - "$site" ${english.packages.${system}.site} <<'PY'
              import sys
              from html.parser import HTMLParser
              from pathlib import Path
              from urllib.parse import urlparse

              class Page(HTMLParser):
                  def __init__(self, path):
                      super().__init__()
                      self.parts = []
                      self.feed(path.read_text())
                      self.text = " ".join("".join(self.parts).split())
                  def handle_starttag(self, tag, attrs):
                      attrs = dict(attrs)
                      url = attrs.get("src") if tag == "script" else attrs.get("href") if tag == "link" and attrs.get("rel") != "canonical" else None
                      assert not url or not urlparse(url).netloc, url
                  def handle_data(self, data):
                      self.parts.append(data)

              branded, english = map(Path, sys.argv[1:])
              for page in branded.rglob("*.html"):
                  Page(page)
              assert "Shared brand footer · 🌲" in Page(branded / "index.html").text
              policy = Page(branded / "privacy.html").text
              assert "Privacy Policy" in policy
              assert "Generated by nullkomma" not in policy
              assert policy.index("Local section in English") < policy.index("Hosting, delivery, security and web analytics by Cloudflare")
              assert "Lokaler Abschnitt auf Deutsch" in policy
              legal = Page(english / "legal.html").text
              assert "Local section in English" in legal
              assert "Deutsch" not in legal
              PY
              touch $out
            '';
        r-pkgdown-local = check "r-pkgdown-local" ''
          export HTTPS_PROXY=http://127.0.0.1:1 HTTP_PROXY=http://127.0.0.1:1
          git init -q
          ${task branded "write-files"}
          # Repeated builds must not trip over read-only assets copied from the store.
          ${task branded "r-pkgdown"}
          ${task branded "r-pkgdown"}
          grep -qF 'Shared brand footer' docs/index.html
          grep -qF 'Lokaler Abschnitt auf Deutsch' docs/privacy.html
          cmp ${root + "/tests/fixtures/r-brand/assets/brand.svg"} docs/brand.svg
          git check-ignore -q .github/privacy.md
          git check-ignore -q pkgdown/assets
        '';
        r-coverage =
          let
            flake = callFlakeWith { nullkomma.r.coverage.enable = true; } fixture;
          in
          check "r-coverage" ''
            git init -q
            ${task flake "r-coverage"}
            grep -q '<coverage ' coverage.xml
            grep -q 'hello.R' coverage.xml
          '';
        r-installed-is-not-development = check "r-installed-is-not-development" ''
          cat > tests/testthat/test-installed.R <<'RS'
          test_that("the installed namespace is tested", {
            expect_false(pkgload::is_dev_package("nullkommafixture"))
            expect_true(startsWith(find.package("nullkommafixture"), Sys.getenv("R_LIBS_USER")))
          })
          RS
          ${runCheck fixtures.r "r-testthat-installed"}
        '';
        r-rejects-drift = check "r-rejects-drift" ''
          cp NAMESPACE "$TMPDIR/NAMESPACE"
          printf '# Generated by roxygen2: do not edit by hand\n' > NAMESPACE
          fails 'NAMESPACE is stale' ${runCheck fixtures.r "r-namespace"}
          cp "$TMPDIR/NAMESPACE" NAMESPACE
          # Tests check the working tree, not the flake's source.
          echo 'stop("local-r-source-marker")' >> R/hello.R
          fails local-r-source-marker ${runCheck fixtures.r "r-cmd-check"}
        '';
        r-files = check "r-files" ''
          git init -q
          ${task fixtures.r "write-files"}
          grep -qxF '^project-only[.]txt$' .Rbuildignore
          mkdir -p nix .github/workflows .vscode .direnv .R/library docs
          touch flake.lock nix/helper.nix .github/workflows/ci.yml .vscode/settings.json .nvim.lua \
            .direnv/cache .R/library/sentinel .envrc project-only.txt docs/index.html coverage.xml
          R CMD build --no-build-vignettes --no-manual .
          tar -tf nullkommafixture_0.0.1.tar.gz > package-files
          if grep -E '([.]nix$|/(flake[.]lock|pkg[.]lock|[.]R|[.]envrc|[.]direnv|[.]github|[.]vscode|[.]nvim[.]lua|docs|coverage[.]xml|project-only[.]txt)(/|$))' package-files; then
            echo "Development-only files leaked into the package source" >&2
            exit 1
          fi
          grep -qx 'nullkommafixture/R/hello.R' package-files
        '';
        r-formatting = check "r-formatting" ''
          ${treefmt fixtures.r}
          printf 'x <- any(is.na(y))\n' > R/lint.R
          format R/lint.R
          grep -qx 'x <- anyNA(y)' R/lint.R
          # `fnd` (funder) is an Authors@R role, not a typo.
          printf 'Config/nullkomma/test: fnd teh\n' >> DESCRIPTION
          format --formatters typos DESCRIPTION
          grep -qx 'Config/nullkomma/test: fnd the' DESCRIPTION
        '';
        r-nested-root = check "r-nested-root" ''
          cd ..
          mkdir nested
          mv project nested/r
          cd nested
          git init -q
          ${task nested "write-files"}
          grep -qxF '^project-only[.]txt$' r/.Rbuildignore
          ${runCheck nested "r-testthat"}
          ${runCheck nested "r-cmd-check"}
        '';
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        r-shinytest2 =
          let
            flake = callFlakeWith { nullkomma.r.extraPackages = [ "shinytest2" ]; } fixture;
          in
          pkgs.runCommand "nullkomma-r-shinytest2"
            { nativeBuildInputs = [ (perSystem flake).nullkomma.r.package ]; }
            ''
              export HOME="$TMPDIR/home" SHINY_FIXTURE=${root + "/tests/r-shiny"}
              mkdir -p "$HOME"
              Rscript --vanilla - <<'RS'
              results <- testthat::test_file("${
                root + "/tests/r-shiny/test-browser.R"
              }", stop_on_failure = TRUE, stop_on_warning = TRUE)
              results <- as.data.frame(results)
              stopifnot(sum(results$passed) >= 3L, !any(results$skipped))
              RS
              touch $out
            '';
      };
    };
}
