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
        # watcher makes Shiny's autoreload event-based instead of polling.
        nullkomma.r.extraPackages = [
          "shiny"
          "watcher"
        ];
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
                  cd source
                  export NULLKOMMA_ROOT="$PWD"
                  ${lib.getExe config.nullkomma.tasks.r-namespace.package}
                  cd ${lib.escapeShellArg "./${cfg.prefix}"}
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
            run = appDir: launch: ''
              shiny::runApp(
                appDir = ${appDir},
                host = ${builtins.toJSON cfg.shiny.host},
                port = ${if cfg.shiny.port == null then "NULL" else toString cfg.shiny.port},
                launch.browser = ${launch}
              )
            '';
            script = setup: launch: pkgs.writeText "shiny.R" (app setup + run "app" launch);
            pkgload = dir: ''
              pkgload::load_all(${dir}, export_all = FALSE)
              package <- pkgload::pkg_name(${dir})
            '';
            # Sourced again by Shiny whenever it changes; returns the app.
            appR = pkgs.writeText "app.R" (app (pkgload ''Sys.getenv("NULLKOMMA_SHINY_PACKAGE")'') + "app\n");
            # The readiness probe reads the URL, which a port of null leaves to Shiny.
            autoreload = pkgs.writeText "autoreload.R" ''
              options(shiny.autoreload = TRUE)
              dir <- commandArgs(TRUE)[[1]]
              ${run "dir" ''
                function(url) {
                  writeLines(url, file.path(dir, "url"))
                  utils::browseURL(url)
                }''}
            '';
            launcher = pkgs.writeShellScriptBin "shiny" ''
              exec ${pkgsR.R}/bin/Rscript --vanilla ${script ''
                .libPaths(c("${installed}/library", "${dependencies}/library"), include.site = FALSE)
                package <- list.dirs("${installed}/library", recursive = FALSE, full.names = FALSE)
              '' "FALSE"}
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
              after = [ "r-namespace" ];
              # Shiny reloads in its own session; don't restart the server.
              watch.native = true;
              # Any HTTP response counts, so an app that errors after a reload stays ready.
              process.readiness_probe = {
                exec.command = ''
                  ${lib.getExe pkgs.curl} --silent --noproxy '*' --output /dev/null \
                    "$(cat "$NULLKOMMA_ROOT/$NULLKOMMA_PROCESSES/shiny/url")"
                '';
                period_seconds = 2;
                # Only report readiness: process-compose stops a process after this many failures in a row.
                failure_threshold = 1000000;
              };
              packages = [
                pkgs.git
                pkgs.watchexec
                config.nullkomma.r.package
              ];
              command = ''
                root="$(git rev-parse --show-toplevel)"
                # Nixpkgs' R leaves R_BROWSER empty, so browseURL() would fail.
                export R_BROWSER="''${R_BROWSER:-${if pkgs.stdenv.isDarwin then "/usr/bin/open" else "xdg-open"}}"
                # In a process tree: reload whenever r-namespace succeeds.
                if [[ -n "''${NULLKOMMA_PROCESSES-}" ]]; then
                  dir="$root/$NULLKOMMA_PROCESSES/shiny"
                  mkdir -p "$dir"
                  install -m 644 ${appR} "$dir/app.R"
                  rm -f "$dir/url"
                  export NULLKOMMA_SHINY_PACKAGE="$root"/${lib.escapeShellArg cfg.prefix}
                  # Touching app.R makes Shiny reload the package and every browser.
                  watchexec --quiet --postpone --watch "$root/$NULLKOMMA_PROCESSES/r-namespace.ok" -- touch "$dir/app.R" &
                  exec Rscript --vanilla ${autoreload} "$dir"
                fi
                cd "$root"/${lib.escapeShellArg cfg.prefix}
                exec Rscript --vanilla ${script (pkgload ''"."'') "TRUE"} "$@"
              '';
            };
            nullkomma.processTrees.r-shiny = {
              description = "Keep r-pkg current and serve the Shiny app, reloaded in the browser after each r-namespace";
              tasks = config.nullkomma.processTrees.r-pkg.tasks ++ [ "shiny" ];
            };
          };
      };
    };
}
