{
  partitions.dev.module = {
    perSystem =
      {
        config,
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
          plugins
          project
          raw
          rawAt
          root
          summary
          task
          ;
        fixture = root + "/tests/fixtures/r";
        withProfile = callFlakeWith {
          nullkomma.r.nonNix.enable = true;
          nullkomma.neovim.enable = true;
        } fixture;
        # The fixture as a project would commit it after enabling non-Nix collaboration.
        nonNixProject =
          pkgs.runCommand "nullkomma-r-non-nix-project" { nativeBuildInputs = [ pkgs.git ]; }
            ''
              ${project fixture}
              git init -q
              ${task withProfile "write-files"}
              grep -qF 'Keep these project-specific development notes.' README.md
              ${task withProfile "generate-files"}
              mkdir $out
              cp -R DESCRIPTION pkg.lock R NAMESPACE man tests .R .Rprofile .Renviron .Rbuildignore .nvim.lua README.md flake.nix $out/
            '';
      in
      {
        nullkomma.nix.unit.tests = {
          testRNonNixFeature = {
            expr =
              let
                standalone = rawAt fixture {
                  imports = [ plugins.r ];
                  nullkomma.r = {
                    enable = true;
                    nonNix.enable = true;
                  };
                };
                withoutR = raw {
                  imports = [ plugins.r ];
                  nullkomma.r.nonNix.enable = true;
                  nullkomma.r.enable = false;
                };
                runtimeOnly = callFlakeWith {
                  nullkomma.r.nonNix.enable = true;
                  nullkomma.r.fields = [
                    "Depends"
                    "Imports"
                    "LinkingTo"
                  ];
                } fixture;
              in
              {
                enabled = (perSystem standalone).nullkomma.files.".Rprofile".mode == "source";
                optIn = (perSystem (callFlakeWith { } fixture)).nullkomma.files.".Rprofile".mode == "generated";
                disabledParent = summary withoutR == summary (raw { });
                # Native R must not install Config/Needs packages that Nix leaves out.
                runtimeFields =
                  lib.hasInfix "NULLKOMMA_R_ALL_CONFIG_NEEDS=false"
                    (perSystem runtimeOnly).nullkomma.files.".Renviron".sections.r;
              };
            expected = {
              enabled = true;
              optIn = true;
              disabledParent = true;
              runtimeFields = true;
            };
          };
        };
        checks = {
          r-non-nix-dev-shell =
            pkgs.runCommand "nullkomma-r-non-nix-dev-shell"
              {
                exportReferencesGraph = [
                  "closure"
                  (builtins.unsafeDiscardOutputDependency config.devShells.default.drvPath)
                ];
              }
              ''
                if grep -F ${nonNixProject.name} closure; then
                  echo "nix develop builds the R fixture" >&2
                  exit 1
                fi
                touch $out
              '';
          r-non-nix-files = nonNixProject;
          r-non-nix-package =
            (lib.findFirst (p: p.pname or "" == "withr") null
              (perSystem fixtures.r-off-nixpkgs).nullkomma.r.package.buildInputs
            ).overrideAttrs
              {
                src = nonNixProject;
                propagatedBuildInputs = [ pkgs.rPackages.assertthat ];
                postPatch = ''
                  substituteInPlace DESCRIPTION --replace-fail '    stats' '    stats, assertthat'
                  printf 'import(assertthat)\n' >> NAMESPACE
                  cat > configure <<'SH'
                  #!/bin/sh
                  Rscript -e 'stopifnot(requireNamespace("assertthat", quietly = TRUE), is.null(getOption("nullkomma.r.library")), !nzchar(Sys.getenv("NULLKOMMA_PPM_URL")))'
                  SH
                  chmod +x configure
                '';
                postInstall = ''
                  test -f .Rprofile
                  test ! -d .R/library
                  Rscript -e 'library(nullkommafixture)'
                '';
              };
          # Nix's own R ignores the native startup files, also in parallel workers.
          r-non-nix-nix-workflows = pkgs.runCommand "nullkomma-r-non-nix-nix-workflows" { } ''
            ${project nonNixProject}
            unset IN_NIX_SHELL R_PROFILE_USER R_ENVIRON_USER
            substituteInPlace DESCRIPTION --replace-fail '    stats' '    stats, assertthat'
            substituteInPlace R/hello.R \
              --replace-fail "#' @importFrom stats setNames" "#' @importFrom stats setNames
            #' @importFrom assertthat assert_that"
            for file in first second; do
              cat > "tests/testthat/test-nix-$file.R" <<'RS'
            test_that("Nix dependencies remain available in parallel workers", {
              expect_true(assertthat::assert_that(TRUE))
              expect_null(getOption("nullkomma.r.library"))
            })
            RS
            done
            ${task withProfile "r-test"} --installed
            ${task withProfile "r-test"}
            ${task withProfile "r-check"}
            # Keep NIX_BUILD_TOP for R CMD check: Nix's cc-wrapper needs it.
            unset NIX_BUILD_TOP
            rm .Renviron
            ${task withProfile "r-test"} --installed
            ${task withProfile "r-test"}
            test ! -d .R/library
            touch $out
          '';
          r-non-nix-profile =
            pkgs.runCommand "nullkomma-r-non-nix-profile" { nativeBuildInputs = [ pkgs.R ]; }
              ''
                ${project nonNixProject}
                unset NULLKOMMA_R_NIX R_LIBS_USER
                export R_LIBS_USER="$HOME/user-library" R_LIBS_SITE="$HOME/site-library"
                mkdir -p "$R_LIBS_USER" "$R_LIBS_SITE"
                R CMD INSTALL --library="$R_LIBS_USER" .
                R CMD INSTALL --library="$R_LIBS_SITE" .
                find "$HOME" -type f -exec sha256sum {} + | sort > "$TMPDIR/external-before"
                test -s "$TMPDIR/external-before"
                Rscript -e '
                  stopifnot(startsWith(.libPaths()[1], file.path(getwd(), ".R", "library")))
                  stopifnot(!any(file.path(Sys.getenv("HOME"), c("user-library", "site-library")) %in% .libPaths()))
                  stopifnot(!requireNamespace("nullkommafixture", quietly = TRUE))
                  stopifnot(getOption("repos")[["CRAN"]] == Sys.getenv("NULLKOMMA_PPM_URL"))
                  stopifnot(all(c("Config/Needs/development", "Config/Needs/website") %in% getOption("nullkomma.r.dependencies")))
                '
                Rscript -e '
                  install.packages(".", repos = NULL, type = "source")
                  stopifnot(startsWith(find.package("nullkommafixture"), getOption("nullkomma.r.library")))
                  remove.packages("nullkommafixture", lib = getOption("nullkomma.r.library"))
                '
                find "$HOME" -type f -exec sha256sum {} + | sort > "$TMPDIR/external-after"
                cmp "$TMPDIR/external-before" "$TMPDIR/external-after"
                fails 'with its .Rprofile enabled' Rscript --vanilla .R/install.R
                fails 'outside Nix' env NULLKOMMA_R_NIX=true Rscript .R/install.R
                Rscript - <<'RS'
                  local({
                    library <- getOption("nullkomma.r.library")
                    options(nullkomma.r.library = tempdir())
                    failure <- tryCatch(source(".R/install.R"), error = conditionMessage)
                    stopifnot(identical(failure, "The project library must be first in .libPaths(); restart R from the project directory."))
                    options(nullkomma.r.library = library)
                    on.exit(Sys.chmod(library, "0755"))
                    Sys.chmod(library, "0555")
                    failure <- tryCatch(source(".R/install.R"), error = conditionMessage)
                    stopifnot(identical(failure, paste0("The project R library is not writable: ", library)))
                  })
                RS
                env NULLKOMMA_R_NIX=true Rscript -e 'stopifnot(is.null(getOption("nullkomma.r.library")))'
                printf 'options(nullkomma.test.user = TRUE)\n.libPaths(tempdir())\n' > "$HOME/.Rprofile"
                Rscript -e 'stopifnot(isTRUE(getOption("nullkomma.test.user")), identical(.libPaths()[1], getOption("nullkomma.r.library")))'
                # Without pkgload in the project library, R still starts.
                R --interactive --no-save <<'RS' 2>&1 | tee session.log
                cat(paste("R", "STARTED", sep = "_"), "\n")
                RS
                grep -qF 'Could not load the package' session.log
                grep -qF R_STARTED session.log
                rm "$HOME/.Rprofile"
                rm .Renviron
                fails 'Missing project R settings' Rscript -e 'quit(status = 0)'
                touch $out
              '';
        };
        process-compose.dev.settings.processes.test-r-non-nix = {
          description = "Test Ubuntu R workflows without Nix in Docker, on macOS in the Colima VM nullkomma-r-test, left running for other runs (stop it with colima stop --profile nullkomma-r-test); args go to docker build";
          disabled = true;
          command = pkgs.writeShellApplication {
            name = "test-r-non-nix";
            runtimeInputs = [
              pkgs.docker-client
            ]
            ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
              pkgs.colima
              pkgs.jq
            ];
            text = ''
              scratch="$(mktemp -d)"
              trap 'rm -rf "$scratch"' EXIT
            ''
            + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
              profile=nullkomma-r-test
              # Colima edits Docker contexts; keep them away from the user's.
              export DOCKER_CONFIG="$scratch/docker"
              colima status --profile "$profile" > /dev/null 2>&1 ||
                colima start --profile "$profile" --vm-type vz --vz-rosetta
              DOCKER_HOST="$(colima status --profile "$profile" --json | jq -r .docker_socket)"
              export DOCKER_HOST
            ''
            + ''
              docker info > /dev/null
              project="$(nix build --no-link --print-out-paths .#checks.${system}.r-non-nix-files)"
              cp -R "$project" "$scratch/project"
              chmod -R u+w "$scratch/project"
              cp ${root + "/tests/r-non-nix/Dockerfile"} "$scratch/Dockerfile"
              cp ${root + "/tests/r-non-nix/run.sh"} "$scratch/run.sh"
              name="''${project##*/}"
              image="nullkomma-r-non-nix:''${name:0:12}"
              BUILDKIT_PROGRESS=plain docker build --platform linux/amd64 \
                --build-arg R_VERSION=${(perSystem withProfile).nullkomma.r.package.version} \
                --tag "$image" "$@" "$scratch"
              docker run --rm --platform linux/amd64 "$image" bash /test.sh
            '';
          };
        };
      };
  };
}
