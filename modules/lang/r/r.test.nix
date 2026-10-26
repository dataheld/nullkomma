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
        brand
        fixtures
        legalcheck
        linkcheck
        nullkomma
        summary
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
      customDestination = callFlakeWith {
        nullkomma.r.pkgdown.config.destination = "public";
      } fixture;
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
          lib.privacy.controller = local.markdown;
        };
        nullkomma.r.pkgdown.brand.enable = true;
        nullkomma.r.pkgdown.assets = root + "/tests/fixtures/r-brand/assets";
        nullkomma.cloudflare = cloudflare;
        perSystem.nullkomma.tasks.r-document.command = lib.mkAfter ''
          mkdir -p pkgdown/assets
          printf 'shared R workflow\n' > pkgdown/assets/workflow.txt
        '';
      } fixture;
      # A package site as nullkomma's own brand publishes it.
      published = callFlakeWith {
        nullkomma.brand = brand;
        nullkomma.r.pkgdown.brand.enable = true;
        nullkomma.cloudflare = cloudflare;
      } fixture;
      declarativeBrand = callFlakeWith {
        nullkomma.brand.lib.brand = root + "/tests/fixtures/site-brand/brand.yml";
        nullkomma.r.pkgdown.brand.enable = true;
        nullkomma.privacy.sections.local = local;
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
        nullkomma.r.pkgdown.privacy.page = "legal.html";
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
      runtime = callFlakeWith {
        nullkomma.vscode.enable = false;
        nullkomma.neovim.enable = false;
        nullkomma.r = {
          extraPackages = [ "assertthat" ];
          check.enable = false;
          testthat.enable = false;
          pkgdown.enable = false;
        };
        # The runtime must come from nixpkgs-r, not the general-purpose package set.
        perSystem._module.args.pkgs = lib.mkForce (
          pkgs.extend (
            _: _: {
              R = throw "nullkomma.r used the general-purpose R";
              radian = throw "nullkomma.r used the general-purpose radian";
            }
          )
        );
      } fixture;
      rRuntime = (perSystem runtime).nullkomma.r.package;
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
        testRBrandFeature = {
          expr =
            let
              enabled = rawAt fixture {
                imports = [ nullkomma.flakeModules.r ];
                nullkomma.brand.lib.brand = root + "/tests/fixtures/r-brand/_brand.yml";
                nullkomma.r = {
                  enable = true;
                  pkgdown.brand.enable = true;
                };
              };
              inactive = rawAt fixture {
                imports = [ nullkomma.flakeModules.r ];
                nullkomma.r.pkgdown.brand.enable = true;
              };
              withoutSite = callFlakeWith {
                nullkomma.r.pkgdown = {
                  enable = false;
                  brand.enable = true;
                };
              } fixture;
            in
            {
              enabled = (perSystem enabled).nullkomma.r.pkgdown.libraries != [ ];
              noCompanionExport = !(nullkomma.flakeModules ? r-brand) && !(nullkomma.modules.flake ? r-brand);
              parentOff = summary inactive == summary (rawAt fixture { });
              optIn = (perSystem fixtures.r).nullkomma.r.pkgdown.libraries == [ ];
              siteOff =
                (perSystem withoutSite).nullkomma.r.pkgdown.libraries == [ ]
                && !lib.elem "brand.yml" (perSystem withoutSite).nullkomma.r.packages;
            };
          expected = {
            enabled = true;
            noCompanionExport = true;
            parentOff = true;
            optIn = true;
            siteOff = true;
          };
        };
        testRWatchDefaults = {
          expr =
            let
              defaults = (perSystem fixtures.r).nullkomma.tasks;
              custom = (perSystem customDestination).nullkomma.tasks;
            in
            {
              paths = defaults.r-document.watch.paths;
              contentPaths = defaults.r-document.watch.contentPaths;
              downstream = map (name: defaults.${name}.watch.paths) [
                "r-test"
                "r-check"
                "r-pkgdown"
              ];
              outputs = lib.all (path: lib.elem path custom.r-document.watch.outputs) [
                "/NAMESPACE"
                "/man/*.Rd"
                "/tests/testthat/_snaps/**/*.new.*"
                "/public"
                "/public/**"
              ];
              nestedOutputs =
                lib.all (path: lib.elem path (perSystem nested).nullkomma.tasks.r-document.watch.outputs)
                  [
                    "/r/tests/testthat/_snaps/**/*.new.*"
                  ];
              nestedContentPaths = (perSystem nested).nullkomma.tasks.r-document.watch.contentPaths;
              processOutputs = lib.all (
                process: lib.all (path: lib.elem path process.watch.ignore) defaults.r-document.watch.outputs
              ) (lib.attrValues (perSystem fixtures.r).processTrees.r-test.processes);
              ignore = lib.elem "/public/" customDestination.debug.config.nullkomma.gitignore;
              invalidDestination =
                (builtins.tryEval (
                  builtins.deepSeq
                    (perSystem (
                      callFlakeWith {
                        nullkomma.r.pkgdown.config.destination = "../site";
                      } fixture
                    )).nullkomma.tasks.r-document.watch.outputs
                    true
                )).success;
            };
          expected = {
            paths = [ "." ];
            contentPaths = [
              "man"
              "tests/testthat/_snaps"
            ];
            downstream = [
              [ ]
              [ ]
              [ ]
            ];
            outputs = true;
            nestedOutputs = true;
            nestedContentPaths = [
              "r/man"
              "r/tests/testthat/_snaps"
            ];
            processOutputs = true;
            ignore = true;
            invalidDestination = false;
          };
        };
        testRPackageDevelopmentSkill = {
          expr =
            let
              enabled = perSystem (
                callFlakeWith {
                  imports = [ nullkomma.flakeModules.default ];
                  nullkomma.r.enable = true;
                } fixture
              );
            in
            enabled.nullkomma.files ? ".agents/skills/nullkomma-r-package-development";
          expected = true;
        };
        testRDocumentationIsRequired = {
          expr =
            let
              minimal = perSystem (
                callFlakeWith {
                  nullkomma.r = {
                    check.enable = false;
                    testthat.enable = false;
                    pkgdown.enable = false;
                  };
                } fixture
              );
            in
            lib.elem "roxygen2" minimal.nullkomma.r.packages
            && minimal.nullkomma.tasks ? r-document
            && minimal.nullkomma.checks ? r-namespace;
          expected = true;
        };
        testRNamespaceTaskIsSeparate = {
          expr =
            let
              tasks = (perSystem (callFlakeWith { nullkomma.r.coverage.enable = true; } fixture)).nullkomma.tasks;
            in
            {
              namespace = tasks.r-namespace.after;
              namespaceOnly = lib.hasInfix ''roxygen2::roxygenise(roclets = "namespace")'' tasks.r-namespace.command;
              namespaceOutputs = tasks.r-namespace.watch.outputs;
              document = tasks.r-document.after;
              documentRoclets = lib.hasInfix ''setdiff(roxygen2::load_options()[["roclets"]], "namespace")'' tasks.r-document.command;
              test = tasks.r-test.after;
              coverage = tasks.r-coverage.after;
              check = tasks.r-check.after;
              pkgdown = tasks.r-pkgdown.after;
            };
          expected = {
            namespace = [ ];
            namespaceOnly = true;
            namespaceOutputs = [ "/NAMESPACE" ];
            document = [ "r-namespace" ];
            documentRoclets = true;
            test = [ "r-namespace" ];
            coverage = [ "r-namespace" ];
            check = [ "r-document" ];
            pkgdown = [ "r-document" ];
          };
        };
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
        testRInteractiveTools = {
          expr =
            let
              r = perSystem fixtures.r;
              withoutAir = perSystem (callFlakeWith { perSystem.treefmt.programs.air.enable = false; } fixture);
              customAir = perSystem (
                callFlakeWith { perSystem.treefmt.programs.air.package = pkgs.hello; } fixture
              );
              settings = r.nullkomma.editor.vscode.settings;
            in
            {
              httpgd = lib.elem "httpgd" r.nullkomma.r.packages;
              editorIndependent =
                lib.elem rRuntime (perSystem runtime).nullkomma.devShell.packages
                && !(perSystem runtime).nullkomma.files ? ".nvim.lua"
                && !(perSystem runtime).nullkomma.files ? ".vscode/settings.json";
              air = lib.elem r.treefmt.programs.air.package r.nullkomma.devShell.packages;
              noAir = lib.elem withoutAir.treefmt.programs.air.package withoutAir.nullkomma.devShell.packages;
              customAir = lib.elem pkgs.hello customAir.nullkomma.devShell.packages;
              console = settings."r.rterm.mac" == "${r.nullkomma.r.package}/bin/radian";
              background = settings."r.rpath.linux" == "${r.nullkomma.r.package}/bin/R";
              bracketedPaste = settings."r.bracketedPaste";
              plotting = settings."r.plot.useHttpgd";
              libraries = settings."r.libPaths";
              recommendations = lib.all (id: lib.elem id r.nullkomma.editor.vscode.extensions) [
                "Posit.air-vscode"
                "REditorSupport.r"
              ];
              override =
                (perSystem (
                  callFlakeWith {
                    perSystem.nullkomma.editor.vscode.settings."r.rterm.mac" = "custom-console";
                  } fixture
                )).nullkomma.editor.vscode.settings."r.rterm.mac";
            };
          expected = {
            httpgd = true;
            editorIndependent = true;
            air = true;
            noAir = false;
            customAir = true;
            console = true;
            background = true;
            bracketedPaste = true;
            plotting = true;
            libraries = [ ];
            recommendations = true;
            override = "custom-console";
          };
        };
        testRRuntimeUsesRInput = {
          expr = (lib.head rRuntime.buildInputs).drvPath;
          expected = nullkomma.inputs.nixpkgs-r.legacyPackages.${system}.R.drvPath;
        };
        testRLockBootstrapsWithoutLock = {
          expr = lib.isString withoutLock.apps.${system}.r-lock.program;
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
        r-watch =
          let
            flake = callFlakeWith {
              perSystem.nullkomma.tasks.r-test.command = lib.mkMerge [
                (lib.mkBefore ''echo started >> "$OBSERVED"'')
                (lib.mkAfter ''echo finished >> "$OBSERVED"'')
              ];
            } fixture;
          in
          check "r-watch" ''
            git init -q
            export OBSERVED="$TMPDIR/observed"
            ${lib.getExe pkgs.python3} ${./_watch.test.py} \
              ${
                lib.getExe (
                  lib.findFirst (p: lib.getName p == "watch-r-test") null
                    (perSystem flake).nullkomma.devShell.packages
                )
              } \
              || { cat "$TMPDIR/watcher.log"; exit 1; }
          '';
        r-console =
          pkgs.runCommand "nullkomma-r-console"
            {
              nativeBuildInputs = [
                rRuntime
                ((perSystem runtime).treefmt.programs.air.package)
                (pkgs.python3.withPackages (p: [ p.pexpect ]))
              ];
            }
            ''
              ${project fixture}
              air --version
              radian --version
              Rscript --vanilla - <<'RS'
              stopifnot(all(vapply(c("pkgload", "assertthat", "httpgd", "languageserver", "rstudioapi", "processx", "later", "jsonlite"), requireNamespace, TRUE, quietly = TRUE)))
              dput(list(home = R.home(), libraries = .libPaths()), file = "runtime.R")
              RS
              python - <<'PY'
              import pexpect
              import sys

              console = pexpect.spawn("radian", ["--vanilla", "--no-save"], encoding="utf-8", timeout=90)
              console.logfile = sys.stdout
              try:
                  console.expect(r"r\$>")
                  console.sendline('expected <- dget("runtime.R"); stopifnot(identical(R.home(), expected$home), identical(.libPaths(), expected$libraries), Sys.getenv("NULLKOMMA_R_NIX") == "true", Sys.getenv("NOT_CRAN") == "true", Sys.getenv("LC_ALL") == "en_US.UTF-8", all(vapply(c("pkgload", "assertthat", "httpgd", "languageserver", "rstudioapi"), requireNamespace, TRUE, quietly = TRUE))); cat(paste("NULLKOMMA", "RUNTIME", "OK", sep = "_"), "\\n")')
                  console.expect_exact("NULLKOMMA_RUNTIME_OK")
                  console.sendline('quit(save = "no")')
                  console.expect(pexpect.EOF)
                  console.close()
                  assert console.exitstatus == 0, console.exitstatus
              finally:
                  if console.isalive():
                      console.close(force=True)
              PY
              touch $out
            '';
        r-pkgdown-legal = legalcheck "r-pkgdown-legal" published.packages.${system}.site;
        r-declarative-brand = linkcheck "r-declarative-brand" declarativeBrand.packages.${system}.site;
        r-pkgdown-config = check "r-pkgdown-config" ''
          Rscript --vanilla - <<'RS'
          .libPaths(c(${
            lib.concatMapStrings (library: ''"${library}", '') (perSystem branded).nullkomma.r.pkgdown.libraries
          }.libPaths()))
          override <- jsonlite::fromJSON(${builtins.toJSON (builtins.toJSON branded.debug.config.nullkomma.r.pkgdown.config)}, simplifyVector = FALSE)
          testthat::expect_no_condition(pkgdown::as_pkgdown(override = override))
          RS
        '';
        r-pkgdown-site =
          pkgs.runCommand "nullkomma-r-pkgdown-site" { nativeBuildInputs = [ pkgs.python3 ]; }
            ''
              site=${branded.packages.${system}.site}
              epoch="$(date -u -d "@$SOURCE_DATE_EPOCH" +%Y-%m-%dT%H:%MZ)"
              grep -qF "last_built: $epoch" "$site/pkgdown.yml"
              test "$(grep -o '<footer' "$site/index.html" | wc -l)" -eq 1
              grep -qF '#123456' "$site"/deps/bootstrap-*/*.css
              cmp ${root + "/tests/fixtures/r-brand/assets/brand.svg"} "$site/brand.svg"
              grep -qxF 'shared R workflow' "$site/workflow.txt"
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
              policy = Page(branded / "privacy.html").text
              assert "Privacy Policy" in policy
              assert "Generated by nullkomma" not in policy and "/nix/store/" not in policy
              assert policy.index("Local section in English") < policy.index("Hosting, delivery, security and web analytics by Cloudflare")
              assert "Lokaler Abschnitt auf Deutsch" in policy
              assert "/privacy.html" in (branded / "search.json").read_text()
              legal = Page(english / "legal.html").text
              assert "Local section in English" in legal
              assert "Deutsch" not in legal
              PY
              touch $out
            '';
        r-pkgdown-local = check "r-pkgdown-local" ''
          export HTTPS_PROXY=http://127.0.0.1:1 HTTP_PROXY=http://127.0.0.1:1
          git init -q
          ${task branded "nk-write-files"}
          (${(perSystem branded).nullkomma.devShell.shellHook})
          # Language tasks must not overwrite files generated on shell entry.
          printf 'local asset\n' > pkgdown/assets/local-only.txt
          # Repeated builds must not trip over read-only assets copied from the store.
          ${task branded "r-pkgdown"}
          ${task branded "r-pkgdown"}
          cmp pkgdown/assets/local-only.txt docs/local-only.txt
          cmp pkgdown/assets/workflow.txt docs/workflow.txt
          grep -qxF 'shared R workflow' docs/workflow.txt
          grep -qF 'Lokaler Abschnitt auf Deutsch' docs/privacy.html
          cmp ${root + "/tests/fixtures/r-brand/assets/brand.svg"} docs/brand.svg
          test ! -e .github/privacy.md -a ! -e privacy.md
          git check-ignore -q pkgdown/assets
        '';
        r-pkgdown-preview = check "r-pkgdown-preview" ''
          export R_BROWSER=${pkgs.writeShellScript "browser" ''echo "$1" > "$TMPDIR/opened"''}
          git init -q
          printf 'destination: yaml-destination\n' >> _pkgdown.yml
          ${task customDestination "r-pkgdown-preview"}
          # browseURL doesn't wait for the browser.
          for _ in {1..50}; do test -f "$TMPDIR/opened" && break; sleep 0.1; done
          grep -qF "$PWD/public/index.html" "$TMPDIR/opened"
          test ! -e yaml-destination
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
        r-namespace-only = check "r-namespace-only" ''
          git init -q
          cp man/hello.Rd "$TMPDIR/hello.Rd"
          printf '# Generated by roxygen2: do not edit by hand\n' > NAMESPACE
          ${task fixtures.r "r-namespace"}
          grep -q '^export(hello)$' NAMESPACE
          grep -q '^importFrom(stats,setNames)$' NAMESPACE
          cmp "$TMPDIR/hello.Rd" man/hello.Rd
        '';
        r-test-namespace-only = check "r-test-namespace-only" ''
          git init -q
          mv man "$TMPDIR/man"
          ${task fixtures.r "r-test"}
          test ! -e man/hello.Rd
        '';
        r-document = check "r-document" ''
          git init -q
          rm -r man
          ${task fixtures.r "r-document"}
          grep -q '^export(hello)$' NAMESPACE
          test -s man/hello.Rd
        '';
        r-installed-is-not-development = check "r-installed-is-not-development" ''
          cat > tests/testthat/test-installed.R <<'RS'
          test_that("the installed namespace is tested", {
            expect_false(pkgload::is_dev_package("nullkommafixture"))
            expect_true(startsWith(find.package("nullkommafixture"), Sys.getenv("R_LIBS_USER")))
          })
          RS
          ${runCheck fixtures.r "r-testthat"} --installed
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
          ${task fixtures.r "nk-write-files"}
          grep -qxF '^project-only[.]txt$' .Rbuildignore
          mkdir -p nix .github/workflows .vscode .direnv .R/library docs .nullkomma/processes .agents/skills/demo
          touch flake.lock nix/helper.nix .github/workflows/ci.yml .vscode/settings.json .nvim.lua \
            .direnv/cache .R/library/sentinel .envrc project-only.txt docs/index.html coverage.xml .nullkomma/processes/r-document.ok \
            .agents/skills/demo/SKILL.md AGENTS.md
          R CMD build --no-build-vignettes --no-manual .
          tar -tf nullkommafixture_0.0.1.tar.gz > package-files
          if grep -E '([.]nix$|/(flake[.]lock|pkg[.]lock|[.]R|[.]envrc|[.]direnv|[.]github|[.]vscode|[.]nvim[.]lua|[.]nullkomma|[.]agents|AGENTS[.]md|docs|coverage[.]xml|project-only[.]txt)(/|$))' package-files; then
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
          printf '[lint]\nignore = ["any_is_na"]\n' > jarl.toml
          rejects 'configure Jarl in' R/lint.R
          rm jarl.toml
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
          ${task nested "nk-write-files"}
          grep -qxF '^project-only[.]txt$' r/.Rbuildignore
          ${runCheck nested "r-testthat"}
          ${runCheck nested "r-cmd-check"}
        '';
      };
    };
}
