{
  plugins.r =
    {
      config,
      flake-parts-lib,
      lib,
      self,
      ...
    }:
    let
      cfg = config.nullkomma.r;
      inherit (config.nullkomma) privacy;
      sections = lib.sort (a: b: a.order < b.order) (
        lib.attrValues (lib.filterAttrs (_: section: section.enable) privacy.sections)
      );
      policy =
        code:
        lib.concatMapStringsSep "\n" (
          section:
          builtins.readFile (
            section.markdown.${code}
              or (throw "Privacy section is missing language `${code}`: ${toString (lib.attrValues section.markdown)}")
          )
        ) sections;
      hasPrivacyPage = cfg.pkgdown.privacy.page != null && sections != [ ];
      privacyPage = ''
        # ${cfg.pkgdown.privacy.title}

      ''
      + (
        if lib.length privacy.languages == 1 then
          policy (lib.head privacy.languages).code
        else
          lib.concatMapStrings (language: ''
            <details open lang="${lib.escapeXML language.code}">
            <summary>${lib.escapeXML language.label}</summary>

            ${policy language.code}

            </details>

          '') privacy.languages
      );
      locked =
        if builtins.pathExists cfg.lockfile then
          map (p: p.package) (lib.importJSON cfg.lockfile).packages
        else
          [ ];
      root =
        if toString cfg.root == toString self.outPath then
          ""
        else
          lib.removePrefix "${toString self.outPath}/" "${toString cfg.root}/";
    in
    {
      options.nullkomma.r = {
        document.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Generate roxygen2 documentation before package workflows; disable for hand-written manuals. Keep NAMESPACE committed; generated man/*.Rd files are Git-ignored.";
        };
        testthat.enable = lib.mkOption {
          type = lib.types.bool;
          default = lib.elem "testthat" locked;
          defaultText = lib.literalMD "whether testthat is in pkg.lock";
          description = "Run testthat against both the development source and an installed package.";
        };
        pkgdown.enable = lib.mkOption {
          type = lib.types.bool;
          default =
            lib.elem "pkgdown" locked
            || builtins.pathExists (cfg.root + "/_pkgdown.yml")
            || builtins.pathExists (cfg.root + "/pkgdown/_pkgdown.yml");
          defaultText = lib.literalMD "whether pkgdown is in pkg.lock or a pkgdown configuration exists";
          description = "Build a pkgdown website with the r-pkgdown task and packages.site (also checked in nix flake check).";
        };
        pkgdown.privacy = {
          page = lib.mkOption {
            type = lib.types.nullOr (lib.types.strMatching "[^/]+[.]md");
            default = "privacy.md";
            description = "Generated Markdown page in the package root rendering nullkomma.privacy.sections; null to supply your own. pkgdown renders it to HTML.";
          };
          title = lib.mkOption {
            type = lib.types.str;
            default = "Privacy Policy";
            description = "Title of the generated pkgdown privacy page.";
          };
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
        pkgdown.override = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default.home.sidebar = false;
          description = "Sandbox-only overrides merged over pkgdown.config. The default disables the network-dependent home sidebar; set home.sidebar.html to a local HTML file to supply your own.";
        };
        lintr.enable = lib.mkOption {
          type = lib.types.bool;
          default =
            lib.elem "lintr" locked
            || builtins.pathExists (cfg.root + "/.lintr")
            || builtins.pathExists (cfg.root + "/.lintr.R");
          defaultText = lib.literalMD "whether lintr is locked or .lintr/.lintr.R exists";
          description = "Load the package and run lintr, failing on lints. Uses the project's own linter configuration.";
        };
        coverage.enable = lib.mkOption {
          type = lib.types.bool;
          default = lib.elem "covr" locked;
          defaultText = lib.literalMD "whether covr is in pkg.lock";
          description = "Provide r-coverage, writing a local Cobertura coverage.xml report; no uploads or coverage threshold.";
        };
      };
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { pkgs, ... }:
        {
          options.nullkomma.r = {
            browser = lib.mkOption {
              type = lib.types.nullOr lib.types.package;
              default =
                if pkgs.stdenv.isLinux && lib.elem "shinytest2" (locked ++ cfg.extraPackages) then
                  pkgs.chromium
                else
                  null;
              defaultText = lib.literalMD "Chromium on Linux when shinytest2 is in pkg.lock or extraPackages; otherwise null";
              description = "Chrome-compatible browser for shinytest2/chromote. On macOS, null uses chromote's locally installed Chrome discovery; sandboxed browser tests require Linux or a supplied Nix browser.";
            };
            setup = lib.mkOption {
              type = lib.types.lines;
              internal = true;
              readOnly = true;
              description = "Shared locale and headless browser setup for R tasks and checks.";
            };
          };
        }
      );
      config = lib.mkIf cfg.enable {
        nullkomma.r.extraPackages =
          lib.optional cfg.check.enable "rcmdcheck"
          ++ lib.optional cfg.document.enable "roxygen2"
          ++ lib.optional cfg.testthat.enable "testthat"
          ++ lib.optional cfg.pkgdown.enable "pkgdown"
          ++ lib.optional (
            cfg.pkgdown.enable
            && (
              (cfg.pkgdown.config.template.bslib.brand or null) != null
              || (cfg.pkgdown.override.template.bslib.brand or null) != null
            )
          ) "brand.yml"
          ++ lib.optionals cfg.lintr.enable [
            "lintr"
            "pkgload"
          ]
          ++ lib.optionals cfg.coverage.enable [
            "covr"
            "xml2"
          ];
        nullkomma.gitignore =
          lib.optional cfg.document.enable "/${root}man/*.Rd"
          ++ lib.optionals cfg.pkgdown.enable [
            "/${root}docs/"
          ]
          ++ lib.optional cfg.coverage.enable "/${root}coverage.xml";
        perSystem =
          { config, pkgs, ... }:
          let
            pcfg = config.nullkomma.r;
            browser = pkgs.writeShellScript "r-chromium" ''
              # Chromium's namespace sandbox cannot nest inside the Nix build sandbox.
              if [[ -n "''${NIX_BUILD_TOP:-}" ]]; then
                exec ${lib.getExe pcfg.browser} --no-sandbox --disable-dev-shm-usage "$@"
              fi
              exec ${lib.getExe pcfg.browser} "$@"
            '';
            document = lib.optionalString cfg.document.enable ''
              Rscript --vanilla -e 'roxygen2::roxygenise()'
            '';
            enter = ''
              if [[ -n "''${NULLKOMMA_R_WORKDIR:-}" ]]; then
                cd "$NULLKOMMA_R_WORKDIR"
              else
                cd ${lib.escapeShellArg (if root == "" then "." else lib.removeSuffix "/" root)}
              fi
            '';
            prepare = ''
              ${enter}
              ${pcfg.setup}
              ${document}
            '';
            privacySource = pkgs.writeText "pkgdown-privacy.md" ''
              <!-- Generated by nullkomma. DO NOT EDIT; change the Nix configuration. -->
              ${privacyPage}
            '';
            stagePrivacy = lib.optionalString hasPrivacyPage ''
              privacy_page=${lib.escapeShellArg cfg.pkgdown.privacy.page}
              if { [ -e "$privacy_page" ] || [ -L "$privacy_page" ]; } && ! head -n 1 "$privacy_page" | grep -q '^<!-- Generated by nullkomma'; then
                echo "$privacy_page is generated from nullkomma.privacy.sections; remove it or set nullkomma.r.pkgdown.privacy.page = null." >&2
                exit 1
              fi
              cp --remove-destination ${privacySource} "$privacy_page"
            '';
            pkgdownDependencies = import ./_pkgdown-dependencies.nix { inherit pkgs; };
            pkgdownAssets = pkgs.runCommand "pkgdown-assets" { } ''
              cp -R ${cfg.pkgdown.assets} "$out"
              chmod -R u+w "$out"
              touch "$out/.nullkomma-generated"
            '';
            stagePkgdown =
              stagePrivacy
              + lib.optionalString (cfg.pkgdown.assets != null) ''
                if [ -L pkgdown ] || [ -L pkgdown/assets ] || { [ -e pkgdown/assets ] && [ ! -f pkgdown/assets/.nullkomma-generated ]; }; then
                  echo "pkgdown/assets is project-owned; remove it or set nullkomma.r.pkgdown.assets = null." >&2
                  exit 1
                fi
                mkdir -p pkgdown
                rm -rf pkgdown/assets
                cp -R ${pkgdownAssets} pkgdown/assets
                chmod -R u+w pkgdown/assets
              ''
              + ''
                pkgdown_cache="$(mktemp -d)"
                trap 'rm -rf "$pkgdown_cache"' EXIT
                export R_USER_CACHE_DIR="$pkgdown_cache"
                mkdir -p "$R_USER_CACHE_DIR/R/pkgdown"
                cp -R ${pkgdownDependencies}/. "$R_USER_CACHE_DIR/R/pkgdown/"
                chmod -R u+w "$R_USER_CACHE_DIR"
              '';
            pkgdownConfig = ''
              # Cached Sass paths make repeated Bootstrap copies overwrite read-only Nix assets.
              options(sass.cache = FALSE)
              override <- jsonlite::fromJSON(${builtins.toJSON (builtins.toJSON cfg.pkgdown.config)}, simplifyVector = FALSE)
            '';
            check =
              name:
              pkgs.runCommand name { } ''
                cp -R ${cfg.root} source
                chmod -R u+w source
                export HOME="$TMPDIR/home" NULLKOMMA_R_WORKDIR="$PWD/source"
                mkdir -p "$HOME"
                ${lib.getExe config.nullkomma.tests.${name}.package}
                touch "$out"
              '';
            test = installed: {
              packages = [ pcfg.package ];
              check = check "r-testthat${lib.optionalString installed "-installed"}";
              command = ''
                ${prepare}
                ${lib.optionalString installed ''
                  scratch="$(mktemp -d)"
                  trap 'rm -rf "$scratch"' EXIT
                  mkdir "$scratch/library"
                  export R_LIBS_USER="$scratch/library"
                  R CMD INSTALL --library="$R_LIBS_USER" .
                ''}
                Rscript --vanilla -e 'testthat::test_local(stop_on_failure = TRUE, stop_on_warning = TRUE${lib.optionalString installed ", load_package = \"installed\""})' "$@"
              '';
            };
          in
          {
            nullkomma.r.setup =
              lib.optionalString pkgs.stdenv.isLinux ''
                export LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive
              ''
              + ''
                export NOT_CRAN=true LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
              ''
              + lib.optionalString (pcfg.browser != null) ''
                export CHROMOTE_CHROME=${browser}
              '';
            nullkomma.devshell.shellHook = pcfg.setup;
            nullkomma.tasks = lib.mkMerge [
              (lib.mkIf cfg.check.enable {
                r-check = {
                  description = "Build and check the R package with rcmdcheck";
                  command = "exec ${lib.getExe config.nullkomma.tests.r-cmd-check.package} \"$@\"";
                };
              })
              (lib.mkIf cfg.document.enable {
                r-document = {
                  description = "Generate R manuals and NAMESPACE with roxygen2";
                  packages = [ pcfg.package ];
                  command = prepare;
                };
              })
              (lib.mkIf cfg.testthat.enable {
                r-test = {
                  description = "Run testthat against the development package";
                  command = "exec ${lib.getExe config.nullkomma.tests.r-testthat.package} \"$@\"";
                };
                r-test-installed = {
                  description = "Install the package in a temporary library and run testthat";
                  command = "exec ${lib.getExe config.nullkomma.tests.r-testthat-installed.package} \"$@\"";
                };
              })
              (lib.mkIf cfg.pkgdown.enable {
                r-pkgdown = {
                  skip = true;
                  description = "Build the pkgdown website in docs/";
                  packages = [
                    pcfg.package
                    pkgs.pandoc
                    pkgs.coreutils
                    pkgs.gnugrep
                  ];
                  command = ''
                    ${prepare}
                    ${stagePkgdown}
                    Rscript --vanilla - <<'RS'
                    ${pkgdownConfig}
                    pkgdown::build_site(override = override, preview = FALSE, new_process = FALSE)
                    RS
                  '';
                };
              })
              (lib.mkIf cfg.lintr.enable {
                r-lint = {
                  description = "Load and lint the R package with lintr";
                  command = "exec ${lib.getExe config.nullkomma.tests.r-lintr.package} \"$@\"";
                };
              })
              (lib.mkIf cfg.coverage.enable {
                r-coverage = {
                  skip = true;
                  description = "Write a Cobertura test coverage report to coverage.xml";
                  packages = [ pcfg.package ];
                  command = ''
                    ${prepare}
                    Rscript --vanilla -e 'covr::to_cobertura(covr::package_coverage(), filename = "coverage.xml")'
                  '';
                };
              })
            ];
            nullkomma.tests = lib.mkMerge [
              (lib.mkIf cfg.testthat.enable {
                r-testthat = test false;
                r-testthat-installed = test true;
              })
              (lib.mkIf cfg.document.enable {
                r-namespace = {
                  packages = [ pcfg.package ];
                  check = check "r-namespace";
                  command = ''
                    ${enter}
                    ${pcfg.setup}
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
              })
              (lib.mkIf cfg.lintr.enable {
                r-lintr = {
                  packages = [ pcfg.package ];
                  check = check "r-lintr";
                  command = ''
                    ${prepare}
                    export LINTR_ERROR_ON_LINT=true
                    Rscript --vanilla -e 'pkgload::load_all(); lintr::lint_package()'
                  '';
                };
              })
            ];
            nullkomma.files =
              lib.mkIf
                (
                  cfg.pkgdown.enable
                  && (toString cfg.root == toString self || lib.hasPrefix "${toString self}/" (toString cfg.root))
                )
                (
                  lib.optionalAttrs hasPrivacyPage {
                    "${root}${cfg.pkgdown.privacy.page}" = {
                      mode = "generated";
                      commentPrefix = "<!--";
                      commentSuffix = " -->";
                      text = privacyPage;
                    };
                  }
                  // lib.optionalAttrs (cfg.pkgdown.assets != null) {
                    "${root}pkgdown/assets" = {
                      mode = "generated";
                      directory = true;
                      source = pkgdownAssets;
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
                    cp -R ${cfg.root} source
                    chmod -R u+w source
                    cd source
                    export HOME="$TMPDIR/home"
                    mkdir -p "$HOME"
                    ${pcfg.setup}
                    ${document}
                    ${stagePkgdown}
                    export PKGDOWN_OUTPUT="$out"
                    Rscript --vanilla - <<'RS'
                    ${pkgdownConfig}
                    sandbox <- jsonlite::fromJSON(${builtins.toJSON (builtins.toJSON cfg.pkgdown.override)}, simplifyVector = FALSE)
                    override <- utils::modifyList(override, sandbox)
                    override$destination <- Sys.getenv("PKGDOWN_OUTPUT")
                    pkgdown::build_site(override = override, preview = FALSE, new_process = FALSE)
                    # pkgdown records wall-clock time even in otherwise reproducible builds.
                    metadata_path <- file.path(override$destination, "pkgdown.yml")
                    metadata <- yaml::read_yaml(metadata_path)
                    epoch <- as.POSIXct(as.numeric(Sys.getenv("SOURCE_DATE_EPOCH", "1")), origin = "1970-01-01", tz = "UTC")
                    metadata$last_built <- format(epoch, "%Y-%m-%dT%H:%MZ", tz = "UTC")
                    yaml::write_yaml(metadata, metadata_path)
                    RS
                  ''
              );
            };
            checks = lib.mkIf cfg.pkgdown.enable { r-pkgdown = config.packages.site; };
          };
      };
    };
}
