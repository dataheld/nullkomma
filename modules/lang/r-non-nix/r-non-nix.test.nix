{
  partitions.dev.module =
    { inputs, ... }:
    {
      perSystem =
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
            nullkomma
            perSystem
            plugins
            project
            raw
            rawAt
            root
            summary
            task
            test
            ;
          fixture = root + "/tests/fixtures/r";
          withProfile = callFlakeWith {
            nullkomma.r-non-nix.enable = true;
            nullkomma.neovim.enable = true;
          } fixture;
          # The fixture as a project would commit it after adopting r-non-nix.
          nonNixProject =
            pkgs.runCommand "nullkomma-r-non-nix-project" { nativeBuildInputs = [ pkgs.git ]; }
              ''
                ${project fixture}
                git init -q
                cp README.md "$TMPDIR/README.md"
                echo "Unseen working-tree edit" >> README.md
                fails 'Upstream conflict: README.md' ${task withProfile "write-files"}
                grep -qF 'Unseen working-tree edit' README.md
                cp "$TMPDIR/README.md" README.md
                ${task withProfile "write-files"}
                grep -qF 'Keep these project-specific development notes.' README.md
                cp README.md "$TMPDIR/expected"
                ${task withProfile "write-files"}
                cmp "$TMPDIR/expected" README.md
                ${task withProfile "generate-files"}
                mkdir $out
                cp -R DESCRIPTION pkg.lock R NAMESPACE man tests .R .Rprofile .Renviron .Rbuildignore .nvim.lua README.md flake.nix $out/
              '';
        in
        {
          nullkomma.nix.unit.tests = {
            testRNonNixPlugin = {
              expr =
                let
                  standalone = rawAt fixture {
                    imports = [ plugins.r-non-nix ];
                    nullkomma.r-non-nix.enable = true;
                  };
                  overlapping = rawAt fixture {
                    imports = [
                      plugins.r
                      plugins.r-non-nix
                      nullkomma.modules.flake.r-non-nix
                    ];
                    nullkomma.r-non-nix.enable = true;
                  };
                  withoutR = raw {
                    imports = [ plugins.r-non-nix ];
                    nullkomma.r-non-nix.enable = true;
                    nullkomma.r.enable = false;
                  };
                  runtimeOnly = callFlakeWith {
                    nullkomma.r-non-nix.enable = true;
                    nullkomma.r.fields = [
                      "Depends"
                      "Imports"
                      "LinkingTo"
                    ];
                  } fixture;
                in
                {
                  enablesR = standalone.debug.config.nullkomma.r.enable;
                  duplicateImports = summary standalone == summary overlapping;
                  requiresR = (builtins.tryEval withoutR.debug.config.nullkomma.r.enable).success;
                  # Native R must not install Config/Needs packages that Nix leaves out.
                  runtimeFields =
                    lib.hasInfix "NULLKOMMA_R_ALL_CONFIG_NEEDS=false"
                      (perSystem runtimeOnly).nullkomma.files.".Renviron".text;
                };
              expected = {
                enablesR = true;
                duplicateImports = true;
                requiresR = false;
                runtimeFields = true;
              };
            };
          };
          checks = {
            r-non-nix-files = nonNixProject;
            # Nix's own R ignores the native startup files, also in parallel workers.
            r-non-nix-nix-workflows = pkgs.runCommand "nullkomma-r-non-nix-nix-workflows" { } ''
              ${project nonNixProject}
              export NIX_BUILD_CORES=2
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
              for runner in \
                ${test withProfile "r-testthat-installed"} \
                ${test withProfile "r-testthat"} \
                ${test withProfile "r-cmd-check"}; do
                "$runner"
              done
              # Keep NIX_BUILD_TOP for R CMD check: Nix's cc-wrapper needs it.
              unset NIX_BUILD_TOP
              rm .Renviron
              ${test withProfile "r-testthat-installed"}
              ${test withProfile "r-testthat"}
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
                  touch .R/library/sentinel project-only.txt
                  # Git worktrees have a .git file, which R does not exclude itself.
                  printf 'gitdir: /unavailable/worktree\n' > .git
                  R CMD build --no-build-vignettes --no-manual .
                  tar -tf nullkommafixture_0.0.1.tar.gz > package-files
                  if grep -E '/(flake[.]nix|pkg[.]lock|[.]R|[.]Renviron|[.]Rprofile|[.]nvim[.]lua|[.]git|project-only[.]txt)(/|$)' package-files; then
                    echo "Development files leaked into the R source package" >&2
                    exit 1
                  fi
                  grep -qx 'nullkommafixture/R/hello.R' package-files
                  env NULLKOMMA_R_NIX=true Rscript -e 'stopifnot(is.null(getOption("nullkomma.r.library")))'
                  rm .Renviron
                  fails 'Missing project R settings' Rscript -e 'quit(status = 0)'
                  touch $out
                '';
          };
          nullkomma.tasks.test-r-non-nix = {
            description = "Test Ubuntu 24.04 R workflows without Nix (requires a running Docker daemon and network)";
            skip = true;
            packages = [
              pkgs.coreutils
              pkgs.docker-client
            ];
            command = ''
              docker info > /dev/null
              scratch="$(mktemp -d)"
              trap 'rm -rf "$scratch"' EXIT
              cp -R ${nonNixProject} "$scratch/project"
              chmod -R u+w "$scratch/project"
              cp ${root + "/tests/r-non-nix/Dockerfile"} "$scratch/Dockerfile"
              cp ${root + "/tests/r-non-nix/run.sh"} "$scratch/run.sh"
              image=nullkomma-r-non-nix:${builtins.substring 11 12 (toString nonNixProject)}
              docker build --platform linux/amd64 --progress=plain \
                --build-arg R_VERSION=${inputs.nixpkgs-r.legacyPackages.${system}.R.version} \
                --tag "$image" "$scratch"
              docker run --rm --platform linux/amd64 "$image" bash /test.sh
            '';
          };
        };
    };
}
