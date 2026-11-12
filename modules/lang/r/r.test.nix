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
        treefmt
        watching
        ;
      rlib = import (root + "/lib/r.nix") { inherit lib; };
      fixture = root + "/tests/fixtures/r";
      customDestination = callFlakeWith {
        nullkomma.r.pkgdown.config.destination = "public";
        perSystem.nullkomma.browse.command = "${pkgs.writeShellScript "browser" ''echo "$1" > "$TMPDIR/opened"''}";
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
        perSystem.process-compose.dev.settings.processes = {
          workflow-asset.command = "mkdir -p pkgdown/assets && echo 'shared R workflow' > pkgdown/assets/workflow.txt";
          r-build-site.depends_on.workflow-asset.condition = "process_completed_successfully";
        };
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
            ${task fixtures.r "write-files"}
            ${script}
            touch $out
          '';
      # `nk <task>` leaves the task in the caller's process group, so a closed terminal (SIGHUP)
      # or a timeout (SIGTERM, SIGKILL) signals R directly, not through process-compose.
      stoppedBy =
        signal:
        check "r-test-stopped-by-${lib.toLower signal}" ''
          git init -q
          export WORKERS="$TMPDIR/workers"
          cat > tests/testthat/test-wait-a.R <<'RS'
          test_that("the worker runs until r-test stops", {
            cat(Sys.getpid(), "\n", sep = "", file = Sys.getenv("WORKERS"), append = TRUE)
            Sys.sleep(600)
          })
          RS
          cp tests/testthat/test-wait-a.R tests/testthat/test-wait-b.R
          logs=(nk.log)
          set -m
          ${task fixtures.r "r-test"} > nk.log 2>&1 &
          group=$!
          set +m
          awaiting '[ -f "$WORKERS" ] && [ "$(wc -l < "$WORKERS")" -ge 2 ]' "$group"
          trap 'kill -KILL $(cat "$WORKERS") 2>/dev/null || true' EXIT
          kill -${signal} -- -"$group"
          for worker in $(cat "$WORKERS"); do
            awaiting "! kill -0 $worker 2>/dev/null"
          done
        '';
    in
    {
      nullkomma.nix.unit.tests = {
        testRBrandFeature = {
          expr =
            let
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
              parentOff = summary inactive == summary (rawAt fixture { });
              siteOff =
                (perSystem withoutSite).nullkomma.r.pkgdown.libraries == [ ]
                && !lib.elem "brand.yml" (perSystem withoutSite).nullkomma.r.packages;
            };
          expected = {
            parentOff = true;
            siteOff = true;
          };
        };
        testRDevLoop = {
          expr = {
            package = (perSystem fixtures.r).process-compose.dev.settings.processes.r-check.watch;
            ignore = lib.elem "/public/" customDestination.debug.config.nullkomma.gitignore;
          };
          expected = {
            # R changes reach the other tasks through the cascade.
            package.paths = [
              {
                path = ".";
                exclude = [
                  "{NAMESPACE,R/**}"
                  "*.o"
                  "*.so"
                  "*.dll"
                  "tests/testthat/_snaps/**"
                  "man/*.Rd"
                  "docs/**"
                ];
              }
            ];
            ignore = true;
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
        testRRejectsInvalidPkgdownDestination = {
          expr =
            (callFlakeWith {
              nullkomma.r.pkgdown.config.destination = "../site";
            } fixture).debug.config.nullkomma.gitignore;
          expectedError.msg = "normalized, package-relative";
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
        testRRuntimeIsEditorIndependent = {
          expr =
            lib.elem rRuntime (perSystem runtime).nullkomma.devShell.packages
            && !(perSystem runtime).nullkomma.files ? ".nvim.lua"
            && !(perSystem runtime).nullkomma.files ? ".vscode/settings.json";
          expected = true;
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
        testRRejectsLockedOffNixpkgsPackagesWhenDisabled = {
          expr =
            (perSystem (
              callFlakeWith {
                nullkomma.r.allowOffNixpkgs = false;
              } (root + "/tests/fixtures/r-off-nixpkgs")
            )).nullkomma.r.packages;
          expectedError.msg = "do not come from nixpkgs";
        };
      };
      checks = {
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
        r-test-watch = check "r-test-watch" ''
          cat > tests/testthat/test-side-effect.R <<'RS'
          test_that("files written by tests don't restart r-test", {
            writeLines("side effect", "side-effect.txt")
            Sys.sleep(1)
            unlink("side-effect.txt")
            succeed()
          })
          RS
          snapshot=tests/testthat/_snaps/snapshot.md
          touch -d @0 "$snapshot"
          mkdir inst
          echo data > inst/data.txt
          ${watching fixtures.r "r-test"}
          settled r-test 1
          test ! -e tests/testthat/side-effect.txt
          test "$(stat -c %Y "$snapshot")" -eq 0
          printf '\n' >> tests/testthat/test-hello.R
          settled r-test 2
          # A diverging snapshot fails r-test and reruns it once for its `.new` file.
          sed -i 's/      hello/      goodbye/' "$snapshot"
          settled r-test 4
          test -e tests/testthat/_snaps/snapshot.new.md
          # Edits to other files that R installs rerun it too.
          echo edited > inst/data.txt
          settled r-test 5
        '';
        r-pkgdown-legal = legalcheck "r-pkgdown-legal" published.packages.${system}.site;
        r-declarative-brand = linkcheck "r-declarative-brand" declarativeBrand.packages.${system}.site;
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
              # pkgdown looks up release dates for NEWS.md online.
              grep -qF 'nullkommafixture 0.0.1' "$site/news/index.html"
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
          ${task branded "write-files"}
          (${(perSystem branded).nullkomma.devShell.shellHook})
          # Language tasks must not overwrite files generated on shell entry.
          printf 'local asset\n' > pkgdown/assets/local-only.txt
          # Repeated builds must not trip over read-only assets copied from the store.
          ${task branded "r-build-site"}
          ${task branded "r-build-site"}
          cmp pkgdown/assets/local-only.txt docs/local-only.txt
          cmp pkgdown/assets/workflow.txt docs/workflow.txt
          grep -qxF 'shared R workflow' docs/workflow.txt
          grep -qF 'Lokaler Abschnitt auf Deutsch' docs/privacy.html
          cmp ${root + "/tests/fixtures/r-brand/assets/brand.svg"} docs/brand.svg
          test ! -e docs/.gitignore
          test ! -e .github/privacy.md -a ! -e privacy.md
          git check-ignore -q pkgdown/assets/brand.svg
        '';
        r-pkgdown-preview = check "r-pkgdown-preview" ''
          git init -q
          printf 'destination: yaml-destination\n' >> _pkgdown.yml
          ${task customDestination "r-build-site"} --preview
          # browseURL doesn't wait for the browser.
          awaiting 'test -s "$TMPDIR/opened"'
          grep -qF "$PWD/public/index.html" "$TMPDIR/opened"
          test ! -e yaml-destination
        '';
        r-pkgdown-live =
          (check "r-pkgdown-live" ''
            git init -q
            # A stopped `process-compose run` signals its whole process group, so the builder needs its own.
            set -m
            PC_DISABLE_TUI=1 ${task customDestination "r-preview-site"} > preview.log 2>&1 &
            preview=$!
            trap 'kill "$preview" 2>/dev/null; wait || true' EXIT
            logs=(preview.log)
            awaiting 'grep -qF "Waiting for r-build-site" preview.log' "$preview"
            if test -e "$TMPDIR/opened"; then
              echo 'The preview must wait for the first build, or it opens a page without reloads' >&2
              exit 1
            fi
            ${task customDestination "r-build-site"}
            awaiting 'test -s "$TMPDIR/opened"' "$preview"
            curl --noproxy '*' --fail --silent "$(cat "$TMPDIR/opened")" > index.html || { cat preview.log >&2; exit 1; }
            grep -qF servr:reload index.html
            grep -qF nullkommafixture index.html
            # Asks servr, as its pages do, whether they must reload.
            reload() {
              node -e 'const ws = new WebSocket(process.argv[1]); ws.onopen = () => ws.send("/"); ws.onmessage = (e) => { console.log(e.data); process.exit(0); };' \
                "$(sed 's|^http|ws|; s|/*$|/websocket/|' "$TMPDIR/opened")"
            }
            # The preview starts once index.html exists, while the first build may still write pages.
            reload > /dev/null
            test "$(reload)" = false
            printf '\nEdited.\n' >> README.md
            ${task customDestination "r-build-site"}
            test "$(reload)" = true
          '').overrideAttrs
            (old: {
              nativeBuildInputs = old.nativeBuildInputs ++ [
                pkgs.curl
                pkgs.nodejs
              ];
              __darwinAllowLocalNetworking = true;
            });
        r-test-coverage =
          let
            flake = callFlakeWith { nullkomma.r.coverage.enable = true; } fixture;
          in
          check "r-test-coverage" ''
            git init -q
            ${task flake "r-test-coverage"}
            grep -q '<coverage ' coverage.xml
            grep -q 'hello.R' coverage.xml
          '';
        r-namespace-only = check "r-namespace-only" ''
          git init -q
          cp man/hello.Rd "$TMPDIR/hello.Rd"
          printf '# Generated by roxygen2: do not edit by hand\n' > NAMESPACE
          ${task fixtures.r "r-document-namespace"}
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
        r-test-stops-workers = check "r-test-stops-workers" ''
          git init -q
          export WORKERS="$TMPDIR/workers" PC_NO_SERVER=1 PC_DISABLE_TUI=1
          cat > tests/testthat/test-wait.R <<'RS'
          test_that("the worker runs until r-test stops", {
            cat(Sys.getpid(), "\n", sep = "", file = Sys.getenv("WORKERS"), append = TRUE)
            Sys.sleep(600)
          })
          RS
          workers() { [ -f "$WORKERS" ] && [ "$(wc -l < "$WORKERS")" -ge "$1" ]; }
          stopped() { ! kill -0 "$(sed -n "$1p" "$WORKERS")" 2>/dev/null; }
          logs=(pc.log)
          ${lib.getExe (perSystem fixtures.r).process-compose.dev.outputs.package} up r-test > pc.log 2>&1 &
          pc=$!
          trap 'kill "$pc" 2>/dev/null || true' EXIT
          awaiting 'workers 1' "$pc"
          echo >> tests/testthat/test-wait.R
          awaiting 'workers 2' "$pc"
          awaiting 'stopped 1' "$pc"
          kill "$pc"
          wait "$pc" || true
          awaiting 'stopped 2'
        '';
        r-test-stopped-by-hup = stoppedBy "HUP";
        r-test-stopped-by-term = stoppedBy "TERM";
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
          ${task fixtures.r "r-test"} --installed
        '';
        r-rejects-drift = check "r-rejects-drift" ''
          cp NAMESPACE "$TMPDIR/NAMESPACE"
          printf '# Generated by roxygen2: do not edit by hand\n' > NAMESPACE
          fails 'NAMESPACE is stale' ${task fixtures.r "r-document-namespace"} --check
          cp "$TMPDIR/NAMESPACE" NAMESPACE
          # Tests check the working tree, not the flake's source.
          echo 'stop("local-r-source-marker")' >> R/hello.R
          fails local-r-source-marker ${task fixtures.r "r-check"}
        '';
        r-check-cran-bound = check "r-check-cran-bound" ''
          ${task fixtures.r "r-check"} 2>&1 | tee "$TMPDIR/r-check.log"
          grep -F -- --as-cran "$TMPDIR/r-check.log"
        '';
        r-check-not-cran-bound =
          let
            flake = callFlakeWith { nullkomma.r.cranBound = false; } fixture;
          in
          check "r-check-not-cran-bound" ''
            # Data that CRAN would want compressed.
            Rscript --vanilla -e 'x <- numeric(1e5); save(x, file = "R/sysdata.rda", compress = FALSE)'
            # Every request fails, so that a repository lookup leaves a warning.
            export http_proxy=http://127.0.0.1:9 https_proxy=http://127.0.0.1:9
            ${task flake "r-check"} 2>&1 | tee r-check.log
            if grep -F 'unable to access index' r-check.log; then
              echo "r-check looked up package repositories" >&2
              exit 1
            fi
          '';
        r-check-runtime-files = check "r-check-runtime-files" ''
          printf 'project-specific exclusion\n' > project-only.txt
          cp .Rbuildignore "$TMPDIR/Rbuildignore"
          cp .gitignore "$TMPDIR/gitignore"
          mkdir inst
          printf 'package file controlled by .Rbuildignore\n' > inst/local.nix
          substituteInPlace R/hello.R --replace-fail "#' @export" "#' @export
          #' @examples
          #' if (nzchar(system.file('local.nix', package = 'nullkommafixture'))) {
          #'   stop('local-buildignore-marker')
          #' }
          #' hello()"
          git worktree add --orphan -b runtime-check "$TMPDIR/worktree"
          cp -R ${fixture}/. "$TMPDIR/worktree"
          chmod -R u+w "$TMPDIR/worktree"
          (cd "$TMPDIR/worktree"; ${task fixtures.r "write-files"})
          mkdir -p .git/worktrees/linked .nullkomma "$TMPDIR/worktree/.nullkomma"
          mkfifo .git/runtime.fifo
          ${lib.getExe pkgs.python3} - "$TMPDIR/worktree" <<'PY'
          import contextlib
          import os
          from pathlib import Path
          import socket
          import subprocess
          import sys

          for directory in [str(Path.cwd()), sys.argv[1]]:
              os.chdir(directory)
              paths = [".nullkomma/runtime.sock"]
              if Path(".git").is_dir():
                  paths += [
                      ".git/fsmonitor--daemon.ipc",
                      ".git/worktrees/linked/fsmonitor--daemon.ipc",
                  ]
              with contextlib.ExitStack() as stack:
                  for path in paths:
                      endpoint = stack.enter_context(socket.socket(socket.AF_UNIX))
                      endpoint.bind(path)
                  subprocess.run(
                      ["${lib.getExe (perSystem fixtures.r).taskRunners.default}", "r-check"],
                      check=True,
                  )
          PY
          cmp .Rbuildignore "$TMPDIR/Rbuildignore"
          cmp .gitignore "$TMPDIR/gitignore"
          grep -vxF '[.]nix$' .Rbuildignore > "$TMPDIR/edited-Rbuildignore"
          cp "$TMPDIR/edited-Rbuildignore" .Rbuildignore
          fails local-buildignore-marker ${task fixtures.r "r-check"}
          cmp .Rbuildignore "$TMPDIR/edited-Rbuildignore"
          cp "$TMPDIR/Rbuildignore" .Rbuildignore
          printf 'R/hello.R\n' >> .gitignore
          git check-ignore -q R/hello.R
          substituteInPlace R/hello.R \
            --replace-fail '  paste0("Hello, ", name, "!")' '  stop("ignored-local-source-marker")'
          fails ignored-local-source-marker ${task fixtures.r "r-check"}
        '';
        r-files = check "r-files" ''
          git init -q
          ${task fixtures.r "write-files"}
          grep -qxF '^project-only[.]txt$' .Rbuildignore
          mkdir -p nix .github/workflows .vscode .direnv .R/library docs .nullkomma/cloudflare .agents/skills/demo
          touch flake.lock nix/helper.nix .github/workflows/ci.yml .vscode/settings.json .nvim.lua \
            .direnv/cache .R/library/sentinel .envrc project-only.txt docs/index.html coverage.xml .nullkomma/cloudflare/terraform.tfstate \
            .agents/skills/demo/SKILL.md AGENTS.md .mcp.json .Renviron .Rprofile
          mkdir -p .worktrees/branch .claude .aspell
          touch .worktrees/branch/DESCRIPTION .claude/settings.json .radian_history .aspell/defaults.R .Rinstignore
          # Git worktrees have a .git file, which R does not exclude itself.
          rm -rf .git
          printf 'gitdir: /unavailable/worktree\n' > .git
          R CMD build --no-build-vignettes --no-manual .
          tar -tf nullkommafixture_0.0.1.tar.gz > package-files
          if grep -E '([.]nix$|/(flake[.]lock|pkg[.]lock|AGENTS[.]md|docs|coverage[.]xml|project-only[.]txt)(/|$))' package-files ||
            grep '^nullkommafixture/[.]' package-files | grep -vE '^nullkommafixture/([.]aspell/|[.]Rinstignore$)'; then
            echo "Development-only files leaked into the package source" >&2
            exit 1
          fi
          grep -qx 'nullkommafixture/R/hello.R' package-files
          grep -qx 'nullkommafixture/[.]aspell/defaults[.]R' package-files
          grep -qx 'nullkommafixture/[.]Rinstignore' package-files
        '';
        # Interactive R loads the working tree above the default packages, after the user's profile.
        r-profile = check "r-profile" ''
          ${task fixtures.r "generate-files"}
          git check-ignore -q .Rprofile
          printf 'options(nullkomma.test.user = TRUE)\n' > "$HOME/.Rprofile"
          R --interactive --no-save <<'RS' 2>&1 | tee session.log
          if (isTRUE(getOption("nullkomma.test.user")) && match("package:nullkommafixture", search()) < match("package:stats", search())) cat(paste("PACKAGE", "LOADED", sep = "_"), "\n")
          RS
          grep -qF PACKAGE_LOADED session.log
          Rscript -e 'stopifnot(isTRUE(getOption("nullkomma.test.user")), !"package:nullkommafixture" %in% search())'
          printf 'broken <- function(\n' > R/broken.R
          R --interactive --no-save <<'RS' 2>&1 | tee session.log
          cat(paste("R", "STARTED", sep = "_"), "\n")
          RS
          grep -qF 'Could not load the package' session.log
          grep -qF R_STARTED session.log
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
          ${task nested "write-files"}
          grep -qxF '^project-only[.]txt$' r/.Rbuildignore
          ${task nested "r-test"}
          ${task nested "r-check"}
        '';
      }
      # Nothing on macOS can stop R's processx subprocesses after a SIGKILL to R.
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        r-test-stopped-by-kill = stoppedBy "KILL";
      };
    };
}
