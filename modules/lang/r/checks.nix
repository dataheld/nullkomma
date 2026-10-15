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
      rlib = import ../../../lib/r.nix { inherit lib; };
      isPackage = cfg.description != null && rlib.hasPackageField (builtins.readFile cfg.description);
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
          default = isPackage;
          defaultText = lib.literalMD "whether DESCRIPTION has a `Package` field";
          description = "Whether to add the `r-cmd-check` test (`R CMD build` + `R CMD check`).";
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
      config.perSystem = lib.mkIf cfg.enable (
        { config, pkgs, ... }:
        let
          strip = [
            "flake.nix"
            "flake.lock"
            (lib.removePrefix "${toString cfg.root}/" (toString cfg.lockfile))
          ]
          ++ lib.filter (path: baseNameOf path != ".Rbuildignore") (lib.attrNames config.nullkomma.files);
          failOn =
            {
              error = null;
              warning = "WARNING";
              note = "WARNING|NOTE";
            }
            .${cfg.check.errorOn};
        in
        {
          nullkomma.tests = lib.mkMerge [
            (lib.mkIf (cfg.description != null) {
              r-lock = {
                packages = [ config.nullkomma.r.package ];
                command = ''
                  Rscript --vanilla - <<'EOF'
                  fields <- ${rVector cfg.fields}
                  locked <- ${
                    rVector (config.nullkomma.r.lock.nixpkgs ++ lib.attrNames config.nullkomma.r.lock.sources)
                  }
                  refs <- ${rVector config.nullkomma.r.lock.refs}
                  d <- read.dcf(${builtins.toJSON (relative cfg.description)})
                  value <- function(field) if (field %in% colnames(d)) d[1, field] else character()
                  config_fields <- fields[startsWith(fields, "Config/Needs/")]
                  deps <- tools:::.split_dependencies(unlist(lapply(setdiff(fields, config_fields), value)))
                  remotes <- trimws(unlist(strsplit(paste(c(value("Remotes"), unlist(lapply(config_fields, value))), collapse = ","), ",")))
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
                '';
              };
            })
            (lib.mkIf cfg.check.enable {
              r-cmd-check = {
                packages = [ config.nullkomma.r.package ];
                command = ''
                  scratch="$(mktemp -d)"
                  trap 'rm -rf "$scratch"' EXIT
                  cp -r ${lib.escapeShellArg root} "$scratch/pkg"
                  chmod -R u+w "$scratch/pkg"
                  cd "$scratch"
                  (cd pkg && rm -rf ${lib.escapeShellArgs strip})
                  ${lib.optionalString pkgs.stdenv.isLinux ''
                    export LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive
                    export LANG=en_US.UTF-8
                  ''}
                  export _R_CHECK_CRAN_INCOMING_=false _R_CHECK_FORCE_SUGGESTS_=false _R_CHECK_SYSTEM_CLOCK_=false
                  R CMD build --no-build-vignettes --no-manual pkg
                  if R CMD check ${lib.escapeShellArgs cfg.check.args} "$@" ./*.tar.gz; then
                    :
                  else
                    status=$?
                    for log in ./*.Rcheck/*.out; do
                      if [[ -f "$log" ]]; then cat "$log" >&2; fi
                    done
                    exit "$status"
                  fi
                  ${lib.optionalString (failOn != null) ''
                    if grep -Eq '^Status: .*(${failOn})' ./*.Rcheck/00check.log; then
                      cat ./*.Rcheck/00check.log >&2
                      echo "nullkomma: R CMD check found issues at or above errorOn = ${cfg.check.errorOn}" >&2
                      exit 1
                    fi
                  ''}
                '';
              };
            })
          ];
        }
      );
    };
}
