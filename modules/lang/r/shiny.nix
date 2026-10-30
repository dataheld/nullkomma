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
                  cp -R ${config.nullkomma.src} source
                  chmod -R u+w source
                  cd ${lib.escapeShellArg "source/${cfg.prefix}"}
                  Rscript --vanilla -e 'roxygen2::roxygenise(roclets = "namespace")'
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
            app = setup: ''
              ${setup}
              entrypoint <- getExportedValue(package, ${builtins.toJSON cfg.shiny.function})
              if (!is.function(entrypoint)) {
                stop("nullkomma.r.shiny.function must name an exported function")
              }
              app <- entrypoint()
              if (!inherits(app, "shiny.appobj")) {
                stop("nullkomma.r.shiny.function must return a shiny.appobj")
              }
            '';
            run = appDir: ''
              shiny::runApp(
                appDir = ${appDir},
                host = ${builtins.toJSON cfg.shiny.host},
                port = ${if cfg.shiny.port == null then "NULL" else toString cfg.shiny.port},
                launch.browser = FALSE
              )
            '';
            script = setup: pkgs.writeText "shiny.R" (app setup + run "app");
            pkgload = dir: ''
              pkgload::load_all(${dir}, export_all = FALSE)
              package <- pkgload::pkg_name(${dir})
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
            process-compose.dev.settings.processes.shiny = {
              namespace = "r";
              description = "Serve the working-tree Shiny app with pkgload";
              working_dir = "./${cfg.prefix}";
              # r-namespace's watch restarts the server on R changes.
              depends_on.r-namespace.condition = "process_completed_successfully";
              command = pkgs.writeShellApplication {
                name = "shiny";
                runtimeInputs = [ config.nullkomma.r.package ];
                text = ''exec Rscript --vanilla ${script (pkgload ''"."'')} "$@"'';
              };
              readiness_probe = lib.mkIf (cfg.shiny.port != null) {
                http_get = {
                  host = if cfg.shiny.host == "0.0.0.0" then "127.0.0.1" else cfg.shiny.host;
                  inherit (cfg.shiny) port;
                };
              };
            };
          };
      };
    };
}
