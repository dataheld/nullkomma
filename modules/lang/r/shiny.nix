{ inputs, ... }:
{
  plugins.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
    in
    {
      options.nullkomma.r.shiny = {
        enable = lib.mkEnableOption "a runnable Shiny app as apps.shiny";
        function = lib.mkOption {
          type = lib.types.nonEmptyStr;
          default = "app";
          description = "Exported function in the project package, called without arguments to obtain a shiny.appobj.";
        };
        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address on which the Shiny server listens; set 0.0.0.0 to expose it beyond localhost.";
        };
        port = lib.mkOption {
          type = lib.types.nullOr lib.types.port;
          default = 3838;
          description = "Port on which the Shiny server listens; null lets Shiny choose an available port.";
        };
      };
      config = lib.mkIf (cfg.enable && cfg.shiny.enable) {
        nullkomma.r.extraPackages = [ "shiny" ];
        perSystem =
          {
            config,
            pkgs,
            system,
            ...
          }:
          let
            pkgsR = inputs.nixpkgs-r.legacyPackages.${system};
            installed =
              pkgs.runCommand "r-shiny-package"
                {
                  nativeBuildInputs = [ config.nullkomma.r.package ];
                }
                ''
                  export HOME="$TMPDIR"
                  cp -R ${cfg.root} source
                  chmod -R u+w source
                  cd source
                  Rscript --vanilla -e 'roxygen2::roxygenise()'
                  mkdir -p "$out/library"
                  R CMD INSTALL --library="$out/library" .
                '';
            dependencies =
              pkgs.runCommand "r-shiny-dependencies" { nativeBuildInputs = [ config.nullkomma.r.package ]; }
                ''
                  mkdir -p "$out/library"
                  export out
                  Rscript --vanilla - <<'RS'
                  .libPaths(c("${installed}/library", .libPaths()))
                  package <- list.dirs("${installed}/library", recursive = FALSE, full.names = FALSE)
                  db <- installed.packages()
                  roots <- c(package, "shiny")
                  deps <- tools::package_dependencies(roots, db = db, which = c("Depends", "Imports"), recursive = TRUE)
                  required <- setdiff(unique(c(roots, unlist(deps))), c(package, "R"))
                  for (name in required) {
                    if (db[name, "Priority"] %in% "base") next
                    source <- normalizePath(file.path(db[name, "LibPath"], name), mustWork = TRUE)
                    if (!file.symlink(source, file.path(Sys.getenv("out"), "library", name))) {
                      stop("Could not link Shiny runtime dependency: ", name)
                    }
                  }
                  RS
                '';
            script =
              setup:
              pkgs.writeText "shiny.R" ''
                ${setup}
                entrypoint <- getExportedValue(package, ${builtins.toJSON cfg.shiny.function})
                if (!is.function(entrypoint)) {
                  stop("nullkomma.r.shiny.function must name an exported function")
                }
                app <- entrypoint()
                if (!inherits(app, "shiny.appobj")) {
                  stop("nullkomma.r.shiny.function must return a shiny.appobj")
                }
                shiny::runApp(
                  appDir = app,
                  host = ${builtins.toJSON cfg.shiny.host},
                  port = ${if cfg.shiny.port == null then "NULL" else toString cfg.shiny.port},
                  launch.browser = FALSE
                )
              '';
            launcher = pkgs.writeShellScriptBin "shiny" ''
              exec ${pkgsR.R}/bin/Rscript --vanilla ${script ''
                .libPaths(c("${installed}/library", "${dependencies}/library"), include.site = FALSE)
                package <- list.dirs("${installed}/library", recursive = FALSE, full.names = FALSE)
              ''}
            '';
          in
          {
            apps.shiny = {
              type = "app";
              program = lib.getExe launcher;
              meta.description = "Run the project's exported Shiny app";
            };
            nullkomma.tasks.shiny = {
              skip = true;
              raw = true;
              description = "Serve the working-tree Shiny app with pkgload";
              packages = [
                pkgs.git
                config.nullkomma.r.package
              ];
              command = ''
                cd "$(git rev-parse --show-toplevel)"/${lib.escapeShellArg cfg.prefix}
                exec Rscript --vanilla ${script ''
                  pkgload::load_all(".", export_all = FALSE)
                  package <- pkgload::pkg_name(".")
                ''} "$@"
              '';
            };
          };
      };
    };
}
