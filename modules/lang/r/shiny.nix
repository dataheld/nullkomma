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
        devFunctions = lib.mkOption {
          type = lib.types.nonEmptyListOf lib.types.nonEmptyStr;
          default = [ cfg.shiny.function ];
          defaultText = lib.literalExpression "[ config.nullkomma.r.shiny.function ]";
          description = "Exported functions whose apps `r-run-app` serves side by side, the n-th on `port` + n.";
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
            script =
              {
                setup,
                function,
                port,
                dev ? false,
              }:
              pkgs.writeText "shiny.R" ''
                ${setup}
                ${lib.optionalString dev ''
                  # Rscript prints deferred warnings only once runApp() returns, which it never does.
                  # Restarts replace Shiny's autoreload, which devmode() would turn on.
                  options(warn = 1, shiny.autoreload = FALSE)
                  shiny::devmode()
                ''}
                entrypoint <- getExportedValue(package, ${builtins.toJSON function})
                if (!is.function(entrypoint)) {
                  stop("${function} must name an exported function")
                }
                app <- entrypoint()
                if (!inherits(app, "shiny.appobj")) {
                  stop("${function}() must return a shiny.appobj")
                }
                ${lib.optionalString dev ''
                  handler <- app$httpHandler
                  script <- paste(c("<script>", readLines("${./live-reload.js}"), "</script></head>"), collapse = "\n")
                  app$httpHandler <- function(req) {
                    response <- handler(req)
                    if (is.character(response$content)) {
                      response$content <- sub("</head>", script, response$content, fixed = TRUE)
                    }
                    response
                  }
                ''}
                shiny::runApp(
                  app,
                  host = ${builtins.toJSON cfg.shiny.host},
                  port = ${if port == null then "NULL" else toString port},
                  launch.browser = FALSE
                )
              '';
            pkgload = dir: ''
              pkgload::load_all(${dir}, export_all = FALSE)
              package <- pkgload::pkg_name(${dir})
            '';
            localHost = if cfg.shiny.host == "0.0.0.0" then "127.0.0.1" else cfg.shiny.host;
            launcher = pkgs.writeShellScriptBin "shiny" ''
              exec ${pkgsR.R}/bin/Rscript --vanilla ${
                script {
                  setup = ''
                    .libPaths(c("${installed}/library", "${dependencies}/library"), include.site = FALSE)
                    package <- list.dirs("${installed}/library", recursive = FALSE, full.names = FALSE)
                  '';
                  inherit (cfg.shiny) function port;
                }
              }
            '';
            devApps = lib.imap0 (i: function: {
              name = "r-shiny-${function}";
              value = {
                namespace = "r";
                disabled = true;
                working_dir = "./${cfg.prefix}";
                # r-document-namespace's watch restarts the app on R changes.
                depends_on.r-document-namespace.condition = "process_completed_successfully";
                depends_on.r-shiny-browser.condition = "process_started";
                command = pkgs.writeShellApplication {
                  name = "r-shiny-${function}";
                  runtimeInputs = [ config.nullkomma.r.package ];
                  text = "exec Rscript --vanilla ${
                    script {
                      setup = pkgload ''"."'';
                      inherit function;
                      port = if cfg.shiny.port == null then null else cfg.shiny.port + i;
                      dev = true;
                    }
                  }";
                };
                # An HTTP probe would stop apps that load slowly, or that block R while computing.
                ready_log_line = "Listening on http://";
                # The watch restarts only running apps, so a failed one retries until it starts.
                availability.restart = "on_failure";
                # Unlike SIGTERM, SIGINT lets Shiny run `onStop()` callbacks.
                shutdown.signal = 2;
              };
            }) cfg.shiny.devFunctions;
          in
          {
            apps.shiny = {
              type = "app";
              program = lib.getExe launcher;
              meta.description = "Run the project's exported Shiny app";
            };
            process-compose.dev.settings.processes = lib.listToAttrs devApps // {
              # A prerequisite of the apps, so that their restarts don't open more tabs.
              r-shiny-browser = {
                namespace = "r";
                disabled = true;
                command = pkgs.writeShellApplication {
                  name = "r-shiny-browser";
                  runtimeInputs = [
                    config.process-compose.dev.package
                    config.nullkomma.r.package
                  ];
                  text = ''
                    for app in ${lib.escapeShellArgs (map (a: a.name) devApps)}; do
                      for _ in {1..120}; do
                        if ports=$(process-compose process ports "$app" 2>&1) && [[ "$ports" =~ \[([0-9]+) ]]; then
                          Rscript --vanilla -e "utils::browseURL('http://${localHost}:''${BASH_REMATCH[1]}')"
                          continue 2
                        fi
                        sleep 1
                      done
                      echo "$ports" >&2
                      exit 1
                    done
                  '';
                };
              };
              # Groups the apps: watches restart all dependents, so this one must not open tabs.
              r-run-app = {
                namespace = "r";
                description = "Serve the working-tree Shiny apps with pkgload, open them in the browser, and reload them on changes";
                depends_on = lib.mapAttrs (_: _: { condition = "process_log_ready"; }) (lib.listToAttrs devApps);
                command = "true";
              };
            };
          };
      };
    };
}
