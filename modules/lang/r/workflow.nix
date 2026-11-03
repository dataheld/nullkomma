{
  plugins.r =
    {
      config,
      flake-parts-lib,
      lib,
      ...
    }:
    let
      cfg = config.nullkomma.r;
      inherit (cfg) prefix;
      destination =
        assert lib.assertMsg (
          builtins.isString cfg.pkgdown.config.destination
          && lib.all (
            part:
            !lib.elem part [
              ""
              "."
              ".."
            ]
          ) (lib.splitString "/" cfg.pkgdown.config.destination)
        ) "nullkomma.r.pkgdown.config.destination must be a normalized, package-relative directory.";
        cfg.pkgdown.config.destination;
      destinationGlob = lib.escape [ "\\" "[" "]" "*" "?" ] destination;
      generated = [
        # testthat compares snapshots byte for byte.
        "tests/testthat/_snaps/**"
        "man/*.Rd"
      ]
      ++ lib.optional cfg.pkgdown.enable "${destinationGlob}/**"
      ++ lib.optional cfg.coverage.enable "coverage.xml";
      inherit (config.nullkomma) privacy;
      privacyPage = (
        if lib.length privacy.languages == 1 then
          privacy.policy.${(lib.head privacy.languages).code}
        else
          lib.concatMapStrings (language: ''
            <details open lang="${lib.escapeXML language.code}">
            <summary>${lib.escapeXML language.label}</summary>

            ${privacy.policy.${language.code}}

            </details>

          '') privacy.languages
      );
    in
    {
      options.nullkomma.r = {
        testthat.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Run testthat with `r-test`: on the pkgload-loaded source in the dev loop and `check`, on the installed package in nix flake check (or with `nk r-test --installed`).";
        };
        pkgdown.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Build a pkgdown website with r-build-site (`--preview` opens it in a browser) and packages.site, both built by `all`, and serve it with live reload with r-preview-site.";
        };
        pkgdown.privacy.page = lib.mkOption {
          type = lib.types.nullOr (lib.types.strMatching "[^/\n]+[.]html");
          default = "privacy.html";
          description = "Page at the site root rendering `nullkomma.privacy`, built by pkgdown without writing to the project; null to supply your own.";
        };
        pkgdown.config = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Native pkgdown configuration merged over _pkgdown.yml in both local and sandboxed builds, e.g. template.bslib.brand and footer.components for shared branding.";
        };
        pkgdown.assets = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Directory generated into pkgdown/assets and copied by pkgdown to the website root in both local and sandboxed builds. Git-ignored; null keeps project-owned assets.";
        };
        coverage.enable = lib.mkOption {
          type = lib.types.bool;
          default = lib.any (p: p.package == "covr") (cfg.locked.packages or [ ]);
          defaultText = lib.literalMD "whether covr is in pkg.lock";
          description = "Provide r-test-coverage, writing a local Cobertura coverage.xml report; no uploads or coverage threshold.";
        };
      };
      options.perSystem = flake-parts-lib.mkPerSystemOption {
        options.nullkomma.r.pkgdown.libraries = lib.mkOption {
          type = lib.types.listOf lib.types.path;
          default = [ ];
          description = "R libraries pkgdown builds load packages from first, e.g. one holding a pkgdown template package selected by `template.package`.";
        };
      };
      config = lib.mkIf cfg.enable {
        nullkomma.agents.skills.nullkomma-r-package-development = ./_agents/nullkomma-r-package-development;
        nullkomma.r.extraPackages = [
          "roxygen2"
        ]
        ++ lib.optional cfg.check.enable "rcmdcheck"
        ++ lib.optional cfg.testthat.enable "testthat"
        ++ lib.optionals cfg.pkgdown.enable [
          "pkgdown"
          "servr"
        ]
        ++ lib.optional (
          cfg.pkgdown.enable && cfg.pkgdown.config.template.bslib.brand or null != null
        ) "brand.yml"
        ++ lib.optionals cfg.coverage.enable [
          "covr"
          "xml2"
        ];
        # Bootstrap 3 templates load their assets from CDNs.
        nullkomma.r.pkgdown.config.template.bootstrap = lib.mkIf cfg.pkgdown.enable (lib.mkDefault 5);
        # Keep local and sandboxed builds on the same destination, including custom sites.
        nullkomma.r.pkgdown.config.destination = lib.mkIf cfg.pkgdown.enable (lib.mkDefault "docs");
        nullkomma.lint.markdown = {
          MD013 = lib.mkDefault false;
          MD033 = lib.mkDefault false;
        };
        nullkomma.lint.typos.type.r-description = {
          extend-glob = [ "DESCRIPTION" ];
          extend-words.fnd = lib.mkDefault "fnd";
        };
        nullkomma.generatedPaths = map (path: prefix + path) generated;
        nullkomma.gitignore = [
          "*.Rcheck/"
          ".RData"
          ".Rhistory"
          ".Rproj.user/"
          ".Ruserdata"
          "/${prefix}man/*.Rd"
        ]
        ++ lib.optional cfg.pkgdown.enable "/${prefix}${destinationGlob}/"
        ++ lib.optional cfg.coverage.enable "/${prefix}coverage.xml";
        perSystem =
          { config, pkgs, ... }:
          let
            pcfg = config.nullkomma.r;
            privacyBody = lib.optionalString (cfg.pkgdown.privacy.page != null && privacy.policy != { }) (
              pkgs.runCommand "privacy.html" { nativeBuildInputs = [ pkgs.pandoc ]; } ''
                pandoc -f markdown+gfm_auto_identifiers-citations+emoji+autolink_bare_uris -t html4 \
                  --indented-code-classes=R --section-divs --wrap=none \
                  ${pkgs.writeText "privacy.md" privacyPage} -o "$out"
              ''
            );
            r = {
              namespace = "r";
              working_dir = "./${prefix}";
            };
            after = name: { ${name}.condition = "process_completed_successfully"; };
            # For tasks that read the whole package; R changes reach them through the cascade.
            packageWatch.paths = [
              {
                path = ".";
                exclude = [
                  "R"
                  "NAMESPACE"
                ]
                ++ generated;
              }
            ];
            rscript = "${pcfg.package}/bin/Rscript --vanilla";
            # shinytest2 skips tests whose Chrome fails to start, and testthat then deletes their file snapshots:
            # start Chrome first, so that this fails r-test instead, and give it time under the dev loop's start-up load.
            # Nix builds without a Nix browser (macOS) have no Chrome and work on a copy, so they still skip.
            chromote = lib.optionalString (lib.elem "chromote" pcfg.packages) ''options(chromote.timeout = 60); if (nzchar(Sys.getenv("CHROMOTE_CHROME")) || !nzchar(Sys.getenv("NIX_BUILD_TOP"))) invisible(chromote::default_chromote_object()$new_session()$close()); '';
            pkgdown = pkgs.writeShellApplication {
              name = "r-build-site";
              runtimeInputs = [
                pcfg.package
                pkgs.pandoc
              ];
              text = ''
                preview=FALSE
                if [[ "''${1-}" == --preview ]]; then
                  preview=TRUE
                  shift
                fi
                R_USER_CACHE_DIR="$(mktemp -d)"
                export R_USER_CACHE_DIR
                trap 'rm -rf "$R_USER_CACHE_DIR"' EXIT
                mkdir "$R_USER_CACHE_DIR/R"
                cp -R ${
                  pkgs.linkFarm "vendored-pkgdown" (
                    map (pin: {
                      inherit (pin) name;
                      path = pkgs.fetchurl { inherit (pin) url hash; };
                    }) (lib.importJSON ./_vendored-pkgdown.json)
                  )
                } "$R_USER_CACHE_DIR/R/pkgdown"
                chmod -R u+w "$R_USER_CACHE_DIR"
                Rscript --vanilla - "$preview" <<'RS'
                # Cached Sass paths make repeated Bootstrap copies overwrite read-only Nix assets.
                options(sass.cache = FALSE)
                override <- jsonlite::fromJSON(${builtins.toJSON (builtins.toJSON cfg.pkgdown.config)}, simplifyVector = FALSE)
                .libPaths(c(${
                  lib.concatMapStrings (library: ''"${library}", '') pcfg.pkgdown.libraries
                }.libPaths()))
                ${lib.optionalString (privacyBody != "") ''
                  # pkgdown only finds extra pages in the project; render this one before build_site indexes it.
                  pkg <- pkgdown::as_pkgdown(override = override)
                  pkgdown::init_site(pkg)
                  body <- paste(readLines("${privacyBody}", encoding = "UTF-8"), collapse = "\n")
                  pkgdown::render_page(pkg, "title-body", list(pagetitle = ${builtins.toJSON privacy.title}, body = body), "${cfg.pkgdown.privacy.page}")
                ''}
                pkgdown::build_site(override = override, preview = identical(commandArgs(TRUE)[[1]], "TRUE"), new_process = FALSE)
                if (nzchar(Sys.getenv("SOURCE_DATE_EPOCH"))) {
                  # pkgdown records wall-clock time even in otherwise reproducible builds.
                  metadata_path <- file.path(override$destination, "pkgdown.yml")
                  metadata <- yaml::read_yaml(metadata_path)
                  epoch <- as.POSIXct(as.numeric(Sys.getenv("SOURCE_DATE_EPOCH", "1")), origin = "1970-01-01", tz = "UTC")
                  metadata$last_built <- format(epoch, "%Y-%m-%dT%H:%MZ", tz = "UTC")
                  yaml::write_yaml(metadata, metadata_path)
                }
                RS
              '';
            };
            test = pkgs.writeShellApplication {
              name = "r-test";
              runtimeInputs = [ pcfg.package ];
              # `$` in the R code is R's, not the shell's.
              excludeShellChecks = [ "SC2016" ];
              text = ''
                load=source
                if [[ "''${1-}" == --installed ]]; then
                  shift
                  load=installed
                  scratch="$(mktemp -d)"
                  trap 'rm -rf "$scratch"' EXIT
                  export R_LIBS_USER="$scratch"
                  R CMD INSTALL --library="$R_LIBS_USER" .
                  # Like R CMD check: shinytest2 then runs apps from the installed package, not pkgload.
                  export TESTTHAT_IS_CHECKING=true
                fi
                Rscript --vanilla -e '${chromote}testthat::test_local(stop_on_failure = TRUE, stop_on_warning = TRUE, load_package = commandArgs(TRUE)[[1]])' "$load"
              '';
            };
            namespace = pkgs.writeShellApplication {
              name = "r-document-namespace";
              runtimeInputs = [ pcfg.package ];
              text = ''
                if [[ "''${1-}" == --check ]]; then
                  original="$(mktemp)"
                  trap 'rm -f "$original"' EXIT
                  cp NAMESPACE "$original"
                fi
                Rscript --vanilla -e 'roxygen2::roxygenise(roclets = "namespace")'
                if [[ -v original ]] && ! diff -u "$original" NAMESPACE; then
                  echo "NAMESPACE is stale; run nk r-document-namespace and commit NAMESPACE." >&2
                  exit 1
                fi
              '';
            };
          in
          {
            process-compose.dev.settings.processes = lib.mkMerge [
              {
                r-document-namespace = r // {
                  description = "Generate NAMESPACE with roxygen2; --check fails if it was stale";
                  command = namespace;
                  # The dev loop: R changes regenerate NAMESPACE, then restart its dependents.
                  watch = {
                    paths = [ { path = "R"; } ];
                    cascade = true;
                  };
                };
                r-document = r // {
                  description = "Generate R manuals and NAMESPACE with roxygen2";
                  depends_on = after "r-document-namespace";
                  command = "${rscript} -e 'roxygen2::roxygenise(roclets = setdiff(roxygen2::load_options()[[\"roclets\"]], \"namespace\"))'";
                };
                check.depends_on = after "r-document-namespace";
              }
              (lib.mkIf cfg.testthat.enable {
                r-test = r // {
                  description = "Run testthat on the working-tree package, loaded with pkgload; --installed tests the installed package";
                  depends_on = after "r-document-namespace";
                  command = test;
                  # testthat writes `_snaps/*.new.*` when snapshots fail.
                  watch.paths = [
                    {
                      path = "tests";
                      exclude = [ "_snaps" ];
                    }
                  ];
                };
                check.depends_on = after "r-test";
              })
              (lib.mkIf cfg.pkgdown.enable {
                r-build-site = r // {
                  description = "Build the pkgdown website; --preview opens it in a browser";
                  depends_on = after "r-document";
                  command = pkgdown;
                  watch = packageWatch;
                };
                # No dependency on r-build-site: its cascade restarts would close open pages.
                r-preview-site = r // {
                  description = "Serve the pkgdown website on localhost, reloading pages when r-build-site rewrites them";
                  command = "${rscript} -e ${lib.escapeShellArg ''
                    index <- file.path("${destination}", "index.html")
                    if (!file.exists(index)) message("Waiting for r-build-site to write ", index)
                    while (!file.exists(index)) Sys.sleep(1)
                    servr::httw("${destination}", browser = TRUE)
                  ''}";
                  ready_log_line = "Serving the directory";
                };
                all.depends_on = after "r-build-site";
              })
              (lib.mkIf cfg.coverage.enable {
                r-test-coverage = r // {
                  description = "Write a Cobertura test coverage report to coverage.xml";
                  # Installs the package, so it must not run while r-document writes man/.
                  depends_on = after "r-document";
                  command = "${rscript} -e 'covr::to_cobertura(covr::package_coverage(), filename = \"coverage.xml\")'";
                  watch = packageWatch;
                };
              })
              (lib.mkIf cfg.check.enable { r-check.watch = packageWatch; })
            ];
            checks = {
              r-document-namespace = config.nullkomma.sandbox {
                process = "r-document-namespace";
                args = [ "--check" ];
              };
              r-test = lib.mkIf cfg.testthat.enable (
                config.nullkomma.sandbox {
                  process = "r-test";
                  args = [ "--installed" ];
                }
              );
            };
            packages.site = lib.mkIf cfg.pkgdown.enable (
              lib.mkDefault (
                config.nullkomma.sandbox {
                  process = "r-build-site";
                  output = "${prefix}${destination}";
                }
              )
            );
            nullkomma.files = lib.mkIf (cfg.pkgdown.enable && cfg.pkgdown.assets != null) {
              "${prefix}pkgdown/assets" = {
                mode = "generated";
                directory = true;
                source = cfg.pkgdown.assets;
              };
            };
          };
      };
    };
}
