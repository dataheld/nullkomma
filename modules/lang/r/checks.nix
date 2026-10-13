{
  flake.flakeModules.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
      rlib = import ../../../lib/r.nix { inherit lib; };
      isPackage = cfg.description != null && rlib.hasPackageField (builtins.readFile cfg.description);
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
            (lib.removePrefix "${toString cfg.root}/" (toString cfg.lockfile))
          ]
          ++ lib.attrNames config.nullkomma.files;
          rVector = list: "c(${lib.concatMapStringsSep ", " builtins.toJSON list})";
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
          checks = lib.mkMerge [
            (lib.mkIf (cfg.description != null) {
              # Is the lockfile up to date with DESCRIPTION, and do nixpkgs' versions meet its constraints?
              r-lock =
                pkgs.runCommand "r-lock"
                  {
                    description = builtins.path {
                      path = cfg.description;
                      name = "DESCRIPTION";
                    };
                    nativeBuildInputs = [ config.nullkomma.r.package ];
                  }
                  ''
                    export HOME="$TMPDIR"
                    Rscript --vanilla - <<'EOF'
                    fields <- ${rVector cfg.fields}
                    locked <- ${
                      rVector (config.nullkomma.r.lock.nixpkgs ++ lib.attrNames config.nullkomma.r.lock.sources)
                    }
                    refs <- ${rVector config.nullkomma.r.lock.refs}
                    d <- read.dcf(Sys.getenv("description"))
                    value <- function(field) if (field %in% colnames(d)) d[1, field] else character()
                    deps <- tools:::.split_dependencies(unlist(lapply(fields, value)))
                    remotes <- trimws(unlist(strsplit(value("Remotes"), ",")))
                    base <- c("R", rownames(installed.packages(priority = "base")))
                    stale <- c(
                      sprintf("DESCRIPTION depends on %s, which", setdiff(names(deps), c(base, locked))),
                      sprintf("DESCRIPTION has `Remotes: %s`, which", setdiff(remotes[remotes != ""], refs))
                    )
                    if (length(stale)) {
                      stop(paste(stale, "the lockfile lacks.", collapse = "\n"), "\nRun `nix run .#r-lock`.", call. = FALSE)
                    }
                    unmet <- Filter(Negate(is.null), lapply(deps, function(dep) {
                      if (is.null(dep$op)) return(NULL)
                      actual <- if (dep$name == "R") getRversion() else packageVersion(dep$name)
                      if (!do.call(dep$op, list(actual, dep$version))) {
                        sprintf("DESCRIPTION requires %s (%s %s), but the R environment has %s.", dep$name, dep$op, dep$version, actual)
                      }
                    }))
                    if (length(unmet)) {
                      stop(paste(unmet, collapse = "\n"), "\nRelax the constraint, or pin a version in `Remotes:` with `nullkomma.r.allowOffNixpkgs`.", call. = FALSE)
                    }
                    EOF
                    touch $out
                  '';
            })
            (lib.mkIf cfg.check.enable {
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
            })
          ];
        };
    };
}
