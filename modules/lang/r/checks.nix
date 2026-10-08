{
  flake.flakeModules.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
      rlib = import ../../../lib/r.nix { inherit lib; };
      isPackage =
        cfg.description != null && (rlib.parseDCF (builtins.readFile cfg.description)) ? Package;
    in
    {
      options.nullkomma.r.check = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = isPackage;
          defaultText = lib.literalMD "whether DESCRIPTION has a `Package` field";
          description = "Whether to add `checks.r-cmd-check` (`R CMD build` + `R CMD check`).";
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
          description = "Least severe `R CMD check` finding that fails the check.";
        };
      };
      config.perSystem =
        { config, pkgs, ... }:
        let
          # nullkomma's own files are not part of the R package
          strip = [
            "flake.nix"
            "flake.lock"
          ]
          ++ lib.attrNames config.nullkomma.files;
          failOn =
            {
              error = null;
              warning = "WARNING";
              note = "WARNING|NOTE";
            }
            .${cfg.check.errorOn};
        in
        {
          # mkIf on `checks`, not on the lazy attribute, so the attribute disappears
          checks = lib.mkIf cfg.check.enable {
            r-cmd-check =
              pkgs.runCommand "r-cmd-check"
                {
                  src = cfg.root;
                  nativeBuildInputs = [ config.nullkomma.r.package ];
                  _R_CHECK_CRAN_INCOMING_ = "false";
                  _R_CHECK_FORCE_SUGGESTS_ = "false";
                  _R_CHECK_SYSTEM_CLOCK_ = "false";
                }
                ''
                  export HOME="$TMPDIR"
                  cp -r "$src" pkg
                  chmod -R u+w pkg
                  (cd pkg && rm -rf ${lib.escapeShellArgs strip})
                  R CMD build --no-build-vignettes --no-manual pkg
                  R CMD check ${lib.escapeShellArgs cfg.check.args} ./*.tar.gz
                  ${lib.optionalString (failOn != null) ''
                    if grep -Eq '^Status: .*(${failOn})' ./*.Rcheck/00check.log; then
                      echo "nullkomma: R CMD check found issues at or above errorOn = ${cfg.check.errorOn}" >&2
                      exit 1
                    fi
                  ''}
                  mkdir -p $out
                  cp -r ./*.Rcheck $out/
                '';
          };
        };
    };
}
