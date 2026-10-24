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
          description = "Whether to add the `r-cmd-check` check (build and check the package with rcmdcheck).";
        };
        args = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "--no-manual"
            "--ignore-vignettes"
          ];
          description = "Arguments to `R CMD check`.";
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
          nullkomma.checks.r-cmd-check = {
            packages = [ config.nullkomma.r.package ];
            command = ''
              scratch="$(mktemp -d)"
              trap 'rm -rf "$scratch"' EXIT
              cp -r ./${lib.escapeShellArg cfg.prefix} "$scratch/pkg"
              chmod -R u+w "$scratch/pkg"
              cd "$scratch/pkg"
              # Share write-files' exclusions without discarding working-tree rules.
              printf '\n' >> .Rbuildignore
              cat ${pkgs.writeText "Rbuildignore" cfg.buildIgnore} >> .Rbuildignore
              export _R_CHECK_CRAN_INCOMING_=false _R_CHECK_FORCE_SUGGESTS_=false _R_CHECK_SYSTEM_CLOCK_=false
              Rscript --vanilla -e 'roxygen2::roxygenise()'
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
        }
      );
    };
}
