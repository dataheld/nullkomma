# R and its packages come from nixpkgs (inputs.nixpkgs-r, defaulting to nullkomma's nixpkgs).
# pak's lockfile decides which packages; with `allowOffNixpkgs`, those nixpkgs
# cannot provide are built from the sources the lockfile pins.
{ inputs, ... }:
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
      rlib = import ../../../lib/r.nix { inherit lib; };
    in
    {
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        {
          pkgs,
          system,
          ...
        }:
        {
          options.nullkomma.r.browser = lib.mkOption {
            type = lib.types.nullOr lib.types.package;
            default =
              let
                usesChromote = lib.elem "chromote" (
                  map (p: p.package) (cfg.locked.packages or [ ]) ++ cfg.extraPackages
                );
              in
              if !usesChromote then
                null
              else if pkgs.stdenv.isLinux then
                pkgs.chromium
              else if system == "aarch64-darwin" then
                pkgs.writeShellScriptBin "chrome-for-testing" ''
                  exec "${
                    pkgs.fetchzip {
                      name = "chrome-for-testing-156.0.8078.48";
                      url = "https://storage.googleapis.com/chrome-for-testing-public/156.0.8078.48/mac-arm64/chrome-mac-arm64.zip";
                      hash = "sha256-rfSNnIWaC55c/XCH6xb9FspmdKMmqT84kywTjhRkeqs=";
                      stripRoot = true;
                    }
                  }/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing" "$@"
                ''
              else
                null;
            defaultText = lib.literalMD "Nixpkgs Chromium on Linux, or pinned Chrome for Testing on aarch64-darwin, when chromote is in pkg.lock or extraPackages; otherwise null";
            description = "Chrome-compatible browser for shinytest2/chromote. Nullkomma pins Chromium on Linux and Chrome for Testing on aarch64-darwin so sandboxed browser checks run without a host browser.";
          };
          options.nullkomma.r.packages = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            readOnly = true;
            description = "Names of the R packages in `nullkomma.r.package`: those of the lockfile and `nullkomma.r.extraPackages`, pak, pkgload, languageserver, httpgd, later and rstudioapi.";
          };
          options.nullkomma.r.buildInputs = lib.mkOption {
            type = lib.types.attrsOf (lib.types.listOf lib.types.package);
            default = { };
            example = lib.literalExpression "{ sf = [ pkgs.gdal ]; }";
            description = "System libraries to add to the build of an R package, for packages whose needs nixpkgs does not know (typically `Remotes:`).";
          };
          options.nullkomma.r.package = lib.mkOption {
            type = lib.types.package;
            readOnly = true;
            description = "R, Rscript and radian with every package of `nullkomma.r.packages`, and the locale, testthat and browser environment of nullkomma's R workflows.";
          };
        }
      );
      config.perSystem = lib.mkIf cfg.enable (
        {
          system,
          config,
          pkgs,
          ...
        }:
        let
          pcfg = config.nullkomma.r;
          browser =
            if pkgs.stdenv.isDarwin then
              pkgs.writeShellScript "r-chromium" ''
                if [[ -n "''${NIX_BUILD_TOP:-}" ]]; then
                  profile=$(mktemp -d "''${TMPDIR:-/tmp}/nullkomma-chrome.XXXXXX")
                  trap 'rm -rf "$profile"' EXIT
                  ${lib.getExe pcfg.browser} "$@" --no-sandbox --user-data-dir="$profile"
                else
                  exec ${lib.getExe pcfg.browser} "$@"
                fi
              ''
            else
              pkgs.writeShellScript "r-chromium" ''
                # Chromium's namespace sandbox cannot nest inside the Nix build sandbox.
                if [[ -n "''${NIX_BUILD_TOP:-}" ]]; then
                  exec ${lib.getExe pcfg.browser} --no-sandbox --disable-dev-shm-usage "$@"
                fi
                exec ${lib.getExe pcfg.browser} "$@"
              '';
          pkgsR = inputs.nixpkgs-r.legacyPackages.${system};
          base = pkgsR.rPackages;
          # Backport nixpkgs' current console fixes without changing the project's R.
          python = pkgsR.python3Packages.overrideScope (
            _: prev: {
              rchitect =
                if lib.versionAtLeast prev.rchitect.version "0.5.2" then
                  prev.rchitect
                else
                  (prev.rchitect.override { R = pkgsR.R; }).overridePythonAttrs {
                    version = "0.5.2";
                    src = pkgsR.fetchFromGitHub {
                      owner = "randy3k";
                      repo = "rchitect";
                      tag = "v0.5.2";
                      hash = "sha256-/p77OoEJWc7aME7itWkwZAHJW7sNEB1iAUwvbCis//U=";
                    };
                  };
            }
          );
          radian =
            (pkgsR.radian.override {
              R = pkgsR.R;
              python3Packages = python;
            }).overridePythonAttrs
              (
                old:
                lib.optionalAttrs (lib.versionOlder old.version "0.7.1") {
                  version = "0.7.1";
                  src = pkgsR.fetchFromGitHub {
                    owner = "randy3k";
                    repo = "radian";
                    tag = "v0.7.1";
                    hash = "sha256-M7NyL0arkM9VNnOf65Dt3ITWCmiwmXWwLGXc0/Td+iw=";
                  };
                  checkInputs = (old.checkInputs or [ ]) ++ [ pkgsR.rPackages.renv ];
                }
              );

          lock =
            if !builtins.pathExists (cfg.root + "/DESCRIPTION") then
              throw "nullkomma.r: `DESCRIPTION` is missing; R projects must be packages with a DESCRIPTION."
            else if cfg.locked == null then
              throw "nullkomma.r: the lockfile `pkg.lock` of DESCRIPTION is missing; create it with `nix run .#r-lock` (flakes only see files known to git)."
            else
              rlib.readLock {
                lock = cfg.locked;
                available = base;
                inherit (cfg) fields allowOffNixpkgs hashes;
              };

          lookup =
            name:
            final.${rlib.attrName name}
            or (throw "nullkomma.r: R package `${name}` is not in nixpkgs' `rPackages`; remove it from `nullkomma.r.extraPackages`.");
          # Unlike the rest of R's packages, the R package dependencies of these come from the lockfile.
          withoutRPackages = lib.filter (p: !(p ? rCommand));
          sourceOverrides = lib.mapAttrs' (
            name: s:
            let
              attr = rlib.attrName name;
              tree = fetchTree s.fetchTree;
              src =
                if s ? fetchurl then
                  pkgsR.fetchurl s.fetchurl
                else if s.subdir == "" then
                  tree
                else
                  "${tree}/${s.subdir}";
              deps = map lookup s.dependencies;
            in
            lib.nameValuePair attr (
              if base ? ${attr} then
                base.${attr}.overrideAttrs (old: {
                  pname = name;
                  name = "r-${name}-${s.version}";
                  inherit src;
                  inherit (s) version;
                  propagatedBuildInputs = deps ++ withoutRPackages (old.propagatedBuildInputs or [ ]);
                  nativeBuildInputs = deps ++ withoutRPackages (old.nativeBuildInputs or [ ]);
                })
              else
                base.buildRPackage {
                  pname = name;
                  inherit src;
                  inherit (s) version;
                  propagatedBuildInputs = deps;
                  nativeBuildInputs = deps;
                }
            )
          ) lock.sources;
          systemLibraries = lib.mapAttrs' (
            name: libs:
            let
              attr = rlib.attrName name;
            in
            lib.nameValuePair attr (
              (sourceOverrides.${attr} or base.${attr}).overrideAttrs (old: {
                buildInputs = (old.buildInputs or [ ]) ++ libs;
              })
            )
          ) pcfg.buildInputs;
          final = base.override {
            overrides =
              sourceOverrides
              // systemLibraries
              // lib.optionalAttrs cfg.pkgdown.enable {
                pkgdown =
                  (systemLibraries.pkgdown or (sourceOverrides.pkgdown or base.pkgdown)).overrideAttrs
                    (old: {
                      patches = (old.patches or [ ]) ++ [ ../../../patches/pkgdown.patch ];
                    });
              };
          };
        in
        {
          config.nullkomma.r = {
            packages = lib.unique (
              lock.nixpkgs
              ++ lib.attrNames lock.sources
              ++ cfg.extraPackages
              ++ [
                "httpgd"
                "languageserver"
                "later"
                "pak"
                "pkgload"
                "rstudioapi"
              ]
            );
            package = pkgs.symlinkJoin {
              name = "R-nullkomma";
              inherit (pkgsR.R) version;
              paths = [
                pkgsR.R
                radian
              ];
              # R's setup hook resolves the same transitive libraries as rWrapper.
              buildInputs = [ pkgsR.R ] ++ pkgsR.rWrapper.recommendedPackages ++ map lookup pcfg.packages;
              nativeBuildInputs = [ pkgs.makeWrapper ];
              postBuild = ''
                for bin in R Rscript radian; do
                  wrapProgram "$out/bin/$bin" --prefix R_LIBS_SITE : "$R_LIBS_SITE" ${
                    lib.escapeShellArgs (
                      lib.optionals pkgs.stdenv.isLinux [
                        "--set"
                        "LOCALE_ARCHIVE"
                        "${pkgs.glibcLocales}/lib/locale/locale-archive"
                      ]
                      ++ [
                        "--set-default"
                        "R_BROWSER"
                        (if pkgs.stdenv.isDarwin then "/usr/bin/open" else "${pkgs.xdg-utils}/bin/xdg-open")
                        "--set"
                        "LANG"
                        "en_US.UTF-8"
                        "--set"
                        "LC_ALL"
                        "en_US.UTF-8"
                        "--set"
                        "NOT_CRAN"
                        "true"
                        # Tells the r-non-nix startup files to stand aside.
                        "--set"
                        "NULLKOMMA_R_NIX"
                        "true"
                      ]
                      ++ lib.optionals (pcfg.browser != null) [
                        "--set-default"
                        "CHROMOTE_CHROME"
                        "${browser}"
                      ]
                    )
                  }
                done
              '';
            };
          };
        }
      );
    };
}
