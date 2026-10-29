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
          description = "Run testthat with `nk-r-test`: on the pkgload-loaded source in the dev loop and `nk-check`, on the installed package in nix flake check (or with `tasks nk-r-test --installed`).";
        };
        pkgdown.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Build a pkgdown website with nk-r-pkgdown (`--preview` opens it in a browser) and packages.site, both checked by nk-check.";
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
          description = "Provide nk-r-coverage, writing a local Cobertura coverage.xml report; no uploads or coverage threshold.";
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
        nullkomma.r.extraPackages = [
          "roxygen2"
        ]
        ++ lib.optional cfg.check.enable "rcmdcheck"
        ++ lib.optional cfg.testthat.enable "testthat"
        ++ lib.optional cfg.pkgdown.enable "pkgdown"
        ++ lib.optional (
          cfg.pkgdown.enable && cfg.pkgdown.config.template.bslib.brand or null != null
        ) "brand.yml"
        ++ lib.optionals cfg.coverage.enable [
          "covr"
          "xml2"
        ];
        # Bootstrap 3 templates load their assets from CDNs.
        nullkomma.r.pkgdown.config.template.bootstrap = lib.mkIf cfg.pkgdown.enable (lib.mkDefault 5);
        # Keep the writer and watcher on the same destination, including custom sites.
        nullkomma.r.pkgdown.config.destination = lib.mkIf cfg.pkgdown.enable (lib.mkDefault "docs");
        nullkomma.lint.markdown = {
          MD013 = lib.mkDefault false;
          MD033 = lib.mkDefault false;
        };
        nullkomma.lint.typos.type.r-description = {
          extend-glob = [ "DESCRIPTION" ];
          extend-words.fnd = lib.mkDefault "fnd";
        };
        nullkomma.generatedPaths = [
          # testthat compares snapshots byte for byte.
          "${prefix}tests/testthat/_snaps/**"
          "${prefix}man/*.Rd"
        ]
        ++ lib.optional cfg.pkgdown.enable "${prefix}${destinationGlob}/**"
        ++ lib.optional cfg.coverage.enable "${prefix}coverage.xml";
        nullkomma.gitignore = [
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
              disabled = true;
            };
            after = name: { ${name}.condition = "process_completed_successfully"; };
            rscript = "${pcfg.package}/bin/Rscript --vanilla";
            pkgdown = pkgs.writeShellApplication {
              name = "nk-r-pkgdown";
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
              name = "nk-r-test";
              runtimeInputs = [ pcfg.package ];
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
                Rscript --vanilla -e 'testthat::test_local(stop_on_failure = TRUE, stop_on_warning = TRUE, load_package = commandArgs(TRUE)[[1]])' "$load"
              '';
            };
            namespace = pkgs.writeShellApplication {
              name = "nk-r-namespace";
              runtimeInputs = [ pcfg.package ];
              text = ''
                if [[ "''${1-}" == --check ]]; then
                  original="$(mktemp)"
                  trap 'rm -f "$original"' EXIT
                  cp NAMESPACE "$original"
                fi
                Rscript --vanilla -e 'roxygen2::roxygenise(roclets = "namespace")'
                if [[ -v original ]] && ! diff -u "$original" NAMESPACE; then
                  echo "NAMESPACE is stale; run tasks nk-r-namespace and commit NAMESPACE." >&2
                  exit 1
                fi
              '';
            };
          in
          {
            process-compose.dev.settings.processes = lib.mkMerge [
              {
                nk-r-namespace = r // {
                  description = "Generate NAMESPACE with roxygen2; --check fails if it was stale";
                  command = namespace;
                  # The dev loop: R changes regenerate NAMESPACE, then restart its dependents.
                  disabled = false;
                  watch = {
                    paths = [ { path = "R"; } ];
                    cascade = true;
                  };
                };
                nk-r-document = r // {
                  description = "Generate R manuals and NAMESPACE with roxygen2";
                  depends_on = after "nk-r-namespace";
                  command = "${rscript} -e 'roxygen2::roxygenise(roclets = setdiff(roxygen2::load_options()[[\"roclets\"]], \"namespace\"))'";
                };
                nk-check.depends_on = after "nk-r-namespace";
              }
              (lib.mkIf cfg.testthat.enable {
                nk-r-test = r // {
                  description = "Run testthat on the working-tree package, loaded with pkgload; --installed tests the installed package";
                  depends_on = after "nk-r-namespace";
                  command = test;
                  disabled = false;
                  # testthat writes `_snaps/*.new.*` when snapshots fail.
                  watch.paths = [
                    {
                      path = "tests";
                      exclude = [ "_snaps" ];
                    }
                  ];
                };
                nk-check.depends_on = after "nk-r-test";
              })
              (lib.mkIf cfg.pkgdown.enable {
                nk-r-pkgdown = r // {
                  description = "Build the pkgdown website; --preview opens it in a browser";
                  depends_on = after "nk-r-document";
                  command = pkgdown;
                };
                nk-check.depends_on = after "nk-r-pkgdown";
              })
              (lib.mkIf cfg.coverage.enable {
                nk-r-coverage = r // {
                  description = "Write a Cobertura test coverage report to coverage.xml";
                  depends_on = after "nk-r-namespace";
                  command = "${rscript} -e 'covr::to_cobertura(covr::package_coverage(), filename = \"coverage.xml\")'";
                };
              })
            ];
            checks = {
              nk-r-namespace = config.nullkomma.sandbox {
                process = "nk-r-namespace";
                args = [ "--check" ];
              };
              nk-r-test = lib.mkIf cfg.testthat.enable (
                config.nullkomma.sandbox {
                  process = "nk-r-test";
                  args = [ "--installed" ];
                }
              );
              nk-r-pkgdown = lib.mkIf cfg.pkgdown.enable config.packages.site;
            };
            packages.site = lib.mkIf cfg.pkgdown.enable (
              lib.mkDefault (
                config.nullkomma.sandbox {
                  process = "nk-r-pkgdown";
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
