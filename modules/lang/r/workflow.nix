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
      rlib = import ../../../lib/r.nix { inherit lib; };
      isPackage = cfg.description != null && rlib.hasPackageField (builtins.readFile cfg.description);
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
          default = isPackage;
          defaultText = lib.literalMD "whether DESCRIPTION has a `Package` field";
          description = "Generate roxygen2 documentation before package workflows; disable for hand-written manuals. Keep NAMESPACE committed; generated man/*.Rd files are Git-ignored.";
        };
        testthat.enable = lib.mkOption {
          type = lib.types.bool;
          default = isPackage && lib.elem "testthat" locked;
          defaultText = lib.literalMD "whether this is a package with testthat in pkg.lock";
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
        pkgdown.override = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default.home.sidebar = false;
          description = "pkgdown configuration overrides for the sandboxed site build. The default disables the network-dependent home sidebar; set home.sidebar.html to a local HTML file to supply your own.";
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
            nullkomma.r.setup = ''
              export NOT_CRAN=true
            ''
            + lib.optionalString pkgs.stdenv.isLinux ''
              export LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive
              export LANG=en_US.UTF-8
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
                  ];
                  command = ''
                    ${prepare}
                    Rscript --vanilla -e 'pkgdown::build_site(preview = FALSE, new_process = FALSE)'
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
                    export PKGDOWN_OUTPUT="$out"
                    Rscript --vanilla - <<'RS'
                    override <- jsonlite::fromJSON(${builtins.toJSON (builtins.toJSON cfg.pkgdown.override)}, simplifyVector = FALSE)
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
