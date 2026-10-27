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
        { pkgs, ... }:
        {
          options.nullkomma.r.browser = lib.mkOption {
            type = lib.types.nullOr lib.types.package;
            default =
              if
                pkgs.stdenv.isLinux
                && lib.elem "chromote" (map (p: p.package) (cfg.locked.packages or [ ]) ++ cfg.extraPackages)
              then
                pkgs.writeShellApplication {
                  name = "r-chromium-with-fonts";
                  text = ''
                    export FONTCONFIG_FILE=${
                      pkgs.makeFontsConf {
                        fontDirectories = [
                          pkgs.liberation_ttf
                          pkgs.dejavu_fonts
                        ];
                      }
                    }
                    exec ${lib.getExe pkgs.chromium} "$@"
                  '';
                }
              else
                null;
            defaultText = lib.literalMD "Chromium with Liberation and DejaVu fonts on Linux when chromote (e.g. via shinytest2) is in pkg.lock or extraPackages; otherwise null";
            description = "Chrome-compatible browser for shinytest2/chromote. On macOS, null uses chromote's locally installed Chrome discovery; sandboxed browser tests require Linux or a supplied Nix browser.";
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
          browser = pkgs.writeShellScript "r-chromium" ''
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
                  R_PROFILE_USER = "/dev/null";
                  R_ENVIRON_USER = "/dev/null";
                  propagatedBuildInputs = deps ++ withoutRPackages (old.propagatedBuildInputs or [ ]);
                  nativeBuildInputs = deps ++ withoutRPackages (old.nativeBuildInputs or [ ]);
                })
              else
                base.buildRPackage {
                  pname = name;
                  inherit src;
                  inherit (s) version;
                  R_PROFILE_USER = "/dev/null";
                  R_ENVIRON_USER = "/dev/null";
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
