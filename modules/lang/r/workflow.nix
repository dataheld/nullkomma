{
  plugins.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
      inherit (cfg) prefix;
      inherit (config.nullkomma) privacy brand;
      privacyPage =
        "# ${privacy.title}\n\n"
        + (
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
          description = "Run testthat: on the pkgload-loaded source in the check task, on the installed package in nix flake check (or with `check r-testthat --installed`).";
        };
        pkgdown.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Build a pkgdown website with r-pkgdown and packages.site (also checked in nix flake check); r-pkgdown-preview builds and opens it in a browser.";
        };
        pkgdown.privacy.page = lib.mkOption {
          type = lib.types.nullOr (lib.types.strMatching "[.]github/[^/\n]+[.]md");
          default = ".github/privacy.md";
          description = "Generated page in `.github/` rendering `nullkomma.privacy`, which pkgdown publishes at the site root by its basename; null to supply your own.";
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
          description = "Provide r-coverage, writing a local Cobertura coverage.xml report; no uploads or coverage threshold.";
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
          cfg.pkgdown.enable && (brand != null || cfg.pkgdown.config.template.bslib.brand or null != null)
        ) "brand.yml"
        ++ lib.optionals cfg.coverage.enable [
          "covr"
          "xml2"
        ];
        # Bootstrap 3 templates load their assets from CDNs.
        nullkomma.r.pkgdown.config.template.bootstrap = lib.mkIf cfg.pkgdown.enable (lib.mkDefault 5);
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
        ++ lib.optional cfg.pkgdown.enable "${prefix}docs/**"
        ++ lib.optional cfg.coverage.enable "${prefix}coverage.xml";
        nullkomma.gitignore = [
          "/${prefix}man/*.Rd"
        ]
        ++ lib.optional cfg.pkgdown.enable "/${prefix}docs/"
        ++ lib.optional cfg.coverage.enable "/${prefix}coverage.xml";
        perSystem =
          { config, pkgs, ... }:
          let
            pcfg = config.nullkomma.r;
            siteBrand = import ../../../lib/brand.nix {
              inherit pkgs lib brand;
              privacyHref =
                if cfg.pkgdown.privacy.page != null && privacy.policy != { } then
                  lib.removeSuffix ".md" (baseNameOf cfg.pkgdown.privacy.page) + ".html"
                else
                  null;
            };
            templateConfig.template = {
              light-switch = true;
              bslib.brand = "${brand.lib.brand}";
            };
            # pkgdown's idiom for a shared look: a template package, here generated from the brand.
            template = pkgs.runCommand "r-nullkommabrand" { } ''
              mkdir -p src/inst/pkgdown/templates "$out"
              printf '%s\n' 'Package: nullkommabrand' 'Version: 0.0.0' 'Title: Brand pkgdown Template' \
                'Description: Generated by nullkomma.' 'License: MIT' > src/DESCRIPTION
              touch src/NAMESPACE
              cp ${pkgs.writeText "_pkgdown.yml" (builtins.toJSON templateConfig)} src/inst/pkgdown/_pkgdown.yml
              if [[ -s ${siteBrand}/footer.html ]]; then
                cp ${siteBrand}/footer.html src/inst/pkgdown/templates/footer.html
              fi
              ${pcfg.package}/bin/R CMD INSTALL --no-test-load --library="$out" src
            '';
            # Checks start at the project root; tasks may start anywhere in it.
            cd = lib.optionalString (prefix != "") "cd ${lib.escapeShellArg prefix}\n";
            top = ''
              cd "$(git rev-parse --show-toplevel)"
              ${cd}'';
            document = ''
              Rscript --vanilla -e 'roxygen2::roxygenise()'
            '';
            pkgdown = sandbox: preview: ''
              R_USER_CACHE_DIR="$(mktemp -d)"
              export R_USER_CACHE_DIR
              trap 'rm -rf "$R_USER_CACHE_DIR"' EXIT
              mkdir "$R_USER_CACHE_DIR/R"
              cp -R ${
                pkgs.linkFarm "pkgdown-dependencies" (
                  map (pin: {
                    inherit (pin) name;
                    path = pkgs.fetchurl { inherit (pin) url hash; };
                  }) (lib.importJSON ./_pkgdown-dependencies.json)
                )
              } "$R_USER_CACHE_DIR/R/pkgdown"
              chmod -R u+w "$R_USER_CACHE_DIR"
              Rscript --vanilla - <<'RS'
              # Cached Sass paths make repeated Bootstrap copies overwrite read-only Nix assets.
              options(sass.cache = FALSE)
              override <- jsonlite::fromJSON(${builtins.toJSON (builtins.toJSON cfg.pkgdown.config)}, simplifyVector = FALSE)
              ${lib.optionalString (brand != null) ''.libPaths(c("${template}", .libPaths()))''}
              ${lib.optionalString sandbox ''override$destination <- Sys.getenv("out")''}
              pkgdown::build_site(override = override, preview = ${lib.toUpper (lib.boolToString preview)}, new_process = FALSE)
              ${lib.optionalString sandbox ''
                # pkgdown records wall-clock time even in otherwise reproducible builds.
                metadata_path <- file.path(override$destination, "pkgdown.yml")
                metadata <- yaml::read_yaml(metadata_path)
                epoch <- as.POSIXct(as.numeric(Sys.getenv("SOURCE_DATE_EPOCH", "1")), origin = "1970-01-01", tz = "UTC")
                metadata$last_built <- format(epoch, "%Y-%m-%dT%H:%MZ", tz = "UTC")
                yaml::write_yaml(metadata, metadata_path)
              ''}
              RS
            '';
            pkgdownTask = description: preview: {
              skip = true;
              inherit description;
              packages = [
                pcfg.package
                pkgs.pandoc
                pkgs.git
              ];
              command = ''
                ${lib.getExe config.nullkomma.tasks.generate-files.package}
                ${top}${document}${pkgdown false preview}'';
            };
            testthat = {
              packages = [ pcfg.package ];
              # pkgload is fast for development; the sandbox tests what users install.
              sandboxArgs = [ "--installed" ];
              command = ''
                ${cd}${document}
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
          in
          {
            nullkomma.tasks = lib.mkMerge [
              {
                r-document = {
                  skip = true;
                  description = "Generate R manuals and NAMESPACE with roxygen2";
                  packages = [
                    pcfg.package
                    pkgs.git
                  ];
                  command = top + document;
                };
              }
              (lib.mkIf cfg.pkgdown.enable {
                r-pkgdown = pkgdownTask "Build the pkgdown website in docs/" false;
                r-pkgdown-preview = pkgdownTask "Build the pkgdown website and open it in a browser" true;
              })
              (lib.mkIf cfg.coverage.enable {
                r-coverage = {
                  skip = true;
                  description = "Write a Cobertura test coverage report to coverage.xml";
                  packages = [
                    pcfg.package
                    pkgs.git
                  ];
                  command = ''
                    ${top}${document}
                    Rscript --vanilla -e 'covr::to_cobertura(covr::package_coverage(), filename = "coverage.xml")'
                  '';
                };
              })
            ];
            nullkomma.checks = {
              r-testthat = lib.mkIf cfg.testthat.enable testthat;
              r-namespace = {
                packages = [ pcfg.package ];
                command = ''
                  ${cd}
                  original="$(mktemp)"
                  trap 'rm -f "$original"' EXIT
                  cp NAMESPACE "$original"
                  ${document}
                  if ! diff -u "$original" NAMESPACE; then
                    echo "NAMESPACE is stale; run r-document and commit NAMESPACE." >&2
                    exit 1
                  fi
                '';
              };
            };
            nullkomma.files = lib.mkIf cfg.pkgdown.enable (
              lib.optionalAttrs (cfg.pkgdown.privacy.page != null && privacy.policy != { }) {
                "${prefix}${cfg.pkgdown.privacy.page}" = {
                  mode = "generated";
                  commentPrefix = "<!--";
                  commentSuffix = " -->";
                  text = privacyPage;
                };
              }
              // lib.optionalAttrs (cfg.pkgdown.assets != null) {
                "${prefix}pkgdown/assets" = {
                  mode = "generated";
                  directory = true;
                  source = cfg.pkgdown.assets;
                };
              }
            );
            packages = lib.mkIf cfg.pkgdown.enable {
              site = lib.mkDefault (
                pkgs.runCommand "r-pkgdown-site"
                  {
                    nativeBuildInputs = [
                      pcfg.package
                      pkgs.pandoc
                    ];
                  }
                  ''
                    cp -R ${config.nullkomma.src} source
                    chmod -R u+w source
                    cd source
                    export HOME="$TMPDIR/home"
                    mkdir -p "$HOME"
                    ${cd}${document}${pkgdown true false}''
              );
            };
            checks = lib.mkIf cfg.pkgdown.enable { r-pkgdown = config.packages.site; };
          };
      };
    };
}
