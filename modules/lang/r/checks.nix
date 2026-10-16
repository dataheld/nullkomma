{
  plugins.r =
    {
      config,
      lib,
      self,
      ...
    }:
    let
      cfg = config.nullkomma.r;
      rVector = list: "c(${lib.concatMapStringsSep ", " builtins.toJSON list})";
      relative =
        path:
        if lib.hasPrefix "${toString self.outPath}/" (toString path) then
          lib.removePrefix "${toString self.outPath}/" (toString path)
        else
          "${path}";
      root = if toString cfg.root == toString self.outPath then "." else relative cfg.root;
    in
    {
      options.nullkomma.r.check = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to add the `r-cmd-check` test (build and check the package with rcmdcheck).";
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
          default = "warning";
          description = "Least severe `R CMD check` finding that fails the test.";
        };
      };
      config.perSystem = lib.mkIf (cfg.enable && cfg.check.enable) (
        { config, pkgs, ... }:
        {
          nullkomma.tests.r-cmd-check = {
            packages = [ config.nullkomma.r.package ];
            command = ''
              scratch="$(mktemp -d)"
              trap 'rm -rf "$scratch"' EXIT
              cp -r ${lib.escapeShellArg root} "$scratch/pkg"
              chmod -R u+w "$scratch/pkg"
              cd "$scratch/pkg"
              # Share write-files' exclusions without discarding working-tree rules.
              printf '\n' >> .Rbuildignore
              cat ${pkgs.writeText "Rbuildignore" cfg.buildIgnore} >> .Rbuildignore
              ${config.nullkomma.r.setup}
              export _R_CHECK_CRAN_INCOMING_=false _R_CHECK_FORCE_SUGGESTS_=false _R_CHECK_SYSTEM_CLOCK_=false
              ${lib.optionalString cfg.document.enable ''
                Rscript --vanilla -e 'roxygen2::roxygenise()'
              ''}
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
