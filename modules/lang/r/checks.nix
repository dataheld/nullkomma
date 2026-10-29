{
  plugins.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
      rVector = list: "c(${lib.concatMapStringsSep ", " builtins.toJSON list})";
    in
    {
      options.nullkomma.r.check = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to add the `nk-r-check` check (build and check the package with rcmdcheck).";
        };
        args = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "--no-manual"
            "--ignore-vignettes"
          ]
          ++ lib.optional cfg.testthat.enable "--no-tests";
          defaultText = lib.literalMD "`--no-manual --ignore-vignettes`, plus `--no-tests` while `nk-r-test` runs the tests";
          description = "Arguments to `R CMD check`. Set them without `--no-tests` to also run the tests inside `R CMD check`.";
        };
        errorOn = lib.mkOption {
          type = lib.types.enum [
            "error"
            "warning"
            "note"
          ];
          default = "note";
          description = "Least severe `R CMD check` finding that fails the check.";
        };
      };
      config.perSystem = lib.mkIf (cfg.enable && cfg.check.enable) (
        { config, pkgs, ... }:
        {
          process-compose.dev.settings.processes = {
            nk-r-check = {
              namespace = "r";
              description = "Run R CMD check";
              depends_on.nk-r-document.condition = "process_completed_successfully";
              working_dir = "./${cfg.prefix}";
              disabled = true;
              command = pkgs.writeShellApplication {
                name = "nk-r-check";
                runtimeInputs = [ config.nullkomma.r.package ];
                text = ''
                  scratch="$(mktemp -d)"
                  trap 'rm -rf "$scratch"' EXIT
                  cp -r . "$scratch/pkg"
                  chmod -R u+w "$scratch/pkg"
                  cd "$scratch/pkg"
                  # Share nk-write-files' exclusions without discarding working-tree rules.
                  printf '\n' >> .Rbuildignore
                  cat ${pkgs.writeText "Rbuildignore" cfg.buildIgnore} >> .Rbuildignore
                  export _R_CHECK_CRAN_INCOMING_=false _R_CHECK_FORCE_SUGGESTS_=false _R_CHECK_SYSTEM_CLOCK_=false
                  Rscript --vanilla - "$@" <<'EOF'
                  rcmdcheck::rcmdcheck(
                    path = ".",
                    build_args = c("--no-build-vignettes", "--no-manual"),
                    args = c(${rVector cfg.check.args}, commandArgs(TRUE)),
                    error_on = ${builtins.toJSON cfg.check.errorOn},
                    check_dir = "../check"
                  )
                  EOF
                '';
              };
            };
            nk-check.depends_on.nk-r-check.condition = "process_completed_successfully";
          };
        }
      );
    };
}
