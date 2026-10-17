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
            type = lib.types.nullOr (
              lib.types.addCheck (lib.types.strMatching "(pkgdown/)?[^/\n]+[.]md") (
                page:
                !(lib.elem (baseNameOf page) [
                  "index.md"
                  "README.md"
                  "LICENSE.md"
                  "LICENCE.md"
                  "LICENSE-text.md"
                  "LICENCE-text.md"
                  "NEWS.md"
                  "authors.md"
                  "404.md"
                  "issue_template.md"
                  "pull_request_template.md"
                  "cran-comments.md"
                ])
              )
            );
            default = "pkgdown/privacy.md";
            description = "Generated Markdown page rendering nullkomma.privacy.sections, in pkgdown/ or the package root; null to supply your own. Its basename determines the root-level HTML URL. Reserved pkgdown page names are rejected.";
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
          default = { };
          description = "Sandbox-only native pkgdown overrides merged over pkgdown.config. The metadata-generated sidebar works offline by default; home.sidebar = false or home.sidebar.html retain pkgdown's usual behavior.";
        };
        lintr.enable = lib.mkOption {
          type = lib.types.bool;
          default =
            lib.elem "lintr" locked
            || builtins.pathExists (cfg.root + "/.lintr")
            || builtins.pathExists (cfg.root + "/.lintr.R");
          defaultText = lib.literalMD "whether lintr is locked or .lintr/.lintr.R exists";
          description = "Load the package and run lintr through treefmt and r-lint, failing on lints. Native .lintr/.lintr.R files retain discovery and exclusions; linters_with_defaults extends the shared policy.";
        };
        lintr.linters = lib.mkOption {
          type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
          default = { };
          example = {
            line_length_linter = "lintr::line_length_linter(100L)";
          };
          description = "Additional named R linter expressions; null disables a rule. Object-name and object-length rules are disabled by default. Native .lintr/.lintr.R files using linters_with_defaults extend these defaults; an explicit list() or defaults argument replaces them.";
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
            lintr.package = lib.mkOption {
              type = lib.types.package;
              internal = true;
              description = "Shared selected-file/package lintr runner.";
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
        nullkomma.lint.markdown = {
          MD013 = lib.mkDefault false;
          MD033 = lib.mkDefault false;
        };
        nullkomma.lint.typos.type.r-description = {
          extend-glob = [ "DESCRIPTION" ];
          extend-words.fnd = lib.mkDefault "fnd";
        };
        nullkomma.generatedPaths =
          lib.optional cfg.document.enable "${root}man/*.Rd"
          ++ lib.optional cfg.pkgdown.enable "${root}docs/**"
          ++ lib.optional cfg.coverage.enable "${root}coverage.xml";
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
            privacySource = pkgs.writeText "pkgdown-privacy.md" (
              "<!-- Generated by nullkomma. DO NOT EDIT; change the Nix configuration. -->\n" + privacyPage
            );
            stagePrivacy = lib.optionalString hasPrivacyPage ''
              privacy_page=${lib.escapeShellArg cfg.pkgdown.privacy.page}
              if [ -L "$privacy_page" ] || { [[ "$privacy_page" == pkgdown/* ]] && [ -L pkgdown ]; }; then
                echo "Refusing symlinked privacy source: $privacy_page" >&2
                exit 1
              fi
              if [ -e "$privacy_page" ] && { [ ! -f "$privacy_page" ] || ! head -n 1 -- "$privacy_page" | grep -q '^<!-- Generated by nullkomma'; }; then
                echo "$privacy_page is generated from nullkomma.privacy.sections; remove it or set nullkomma.r.pkgdown.privacy.page = null." >&2
                exit 1
              fi
              privacy_name="$(basename -- "$privacy_page")"
              for candidate in "$privacy_name" ".github/$privacy_name" "pkgdown/assets/''${privacy_name%.md}.html"; do
                if [ "$candidate" != "$privacy_page" ] && { [ -e "$candidate" ] || [ -L "$candidate" ]; }; then
                  echo "Privacy output collision: $candidate also produces ''${privacy_name%.md}.html; remove it or set nullkomma.r.pkgdown.privacy.page = null." >&2
                  exit 1
                fi
              done
              ${lib.optionalString (cfg.pkgdown.assets != null) ''
                if [ -e ${lib.escapeShellArg "${cfg.pkgdown.assets}/${lib.removeSuffix ".md" (baseNameOf cfg.pkgdown.privacy.page)}.html"} ]; then
                  echo "Privacy output collision in nullkomma.r.pkgdown.assets" >&2
                  exit 1
                fi
              ''}
              mkdir -p "$(dirname -- "$privacy_page")"
              cp --remove-destination -- ${privacySource} "$privacy_page"
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
                    NULLKOMMA_R_WORKDIR="$PWD" ${lib.getExe pcfg.lintr.package}
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
            nullkomma.r.lintr.package = lib.mkIf cfg.lintr.enable (
              pkgs.writeShellScriptBin "r-lintr" ''
                ${pcfg.setup}
                export NULLKOMMA_LINTR_CONFIG=${
                  pkgs.writeText "lintr-config.R" (
                    "lintr::modify_defaults(\n"
                    + lib.concatStringsSep ",\n" (
                      lib.mapAttrsToList (name: value: "    ${name} = ${if value == null then "NULL" else value}") (
                        {
                          object_name_linter = null;
                          object_length_linter = null;
                        }
                        // cfg.lintr.linters
                      )
                    )
                    + ",\n    defaults = lintr::default_linters\n)\n"
                  )
                }
                export LINTR_ERROR_ON_LINT=true
                ${pcfg.package}/bin/Rscript --vanilla ${pkgs.writeText "lint.R" ''
                  files <- commandArgs(trailingOnly = TRUE)
                  root <- Sys.getenv("NULLKOMMA_R_WORKDIR", ${
                    builtins.toJSON (if root == "" then "." else lib.removeSuffix "/" root)
                  })
                  pkgload::load_all(root, quiet = TRUE)
                  if (length(files)) {
                    for (file in files) print(lintr::lint(file))
                  } else {
                    print(lintr::lint_package(root))
                  }
                ''} "$@"
              ''
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
