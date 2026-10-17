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
      options.perSystem = flake-parts-lib.mkPerSystemOption {
        options.nullkomma.r.lock = lib.mkOption {
          type = lib.types.raw;
          readOnly = true;
          description = "`nullkomma.r.lockfile`, as read by `nullkomma.lib.r.readLock` (empty without DESCRIPTION).";
        };
        options.nullkomma.r.packages = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          readOnly = true;
          description = "Names of the R packages in `nullkomma.r.package`: those of the lockfile and `nullkomma.r.extraPackages`, pak and languageserver.";
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
          description = "R with every package of `nullkomma.r.packages`.";
        };
      };
      config.perSystem = lib.mkIf cfg.enable (
        { system, config, ... }:
        let
          pcfg = config.nullkomma.r;
          pkgsR = inputs.nixpkgs-r.legacyPackages.${system};
          base = pkgsR.rPackages;

          lock =
            if !builtins.pathExists cfg.description then
              throw "nullkomma.r: `${baseNameOf cfg.description}` is missing; R projects must be packages with a DESCRIPTION."
            else if !builtins.pathExists cfg.lockfile then
              throw "nullkomma.r: the lockfile `${baseNameOf cfg.lockfile}` of DESCRIPTION is missing; create it with `nix run .#r-lock` (flakes only see files known to git)."
            else
              rlib.readLock {
                lock = lib.importJSON cfg.lockfile;
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
              // lib.optionalAttrs cfg.lintr.enable {
                lintr = (systemLibraries.lintr or (sourceOverrides.lintr or base.lintr)).overrideAttrs (old: {
                  postPatch = (old.postPatch or "") + ''
                    # Keep native discovery/evaluation; replace only its default linter list.
                    substituteInPlace R/with.R \
                      --replace-fail 'linters_with_defaults <- function(..., defaults = default_linters)' \
                      'linters_with_defaults <- function(..., defaults = { path <- Sys.getenv("NULLKOMMA_LINTR_CONFIG"); if (nzchar(path)) dget(path) else default_linters })'
                    substituteInPlace R/settings.R \
                      --replace-fail '  config <- read_config_file(config_file, call = call)' ${lib.escapeShellArg ''
                        path <- Sys.getenv("NULLKOMMA_LINTR_CONFIG")
                        if (nzchar(path)) default_settings$linters <- dget(path)
                        config <- read_config_file(config_file, call = call)''}
                  '';
                });
              }
              // lib.optionalAttrs cfg.pkgdown.enable {
                pkgdown =
                  (systemLibraries.pkgdown or (sourceOverrides.pkgdown or base.pkgdown)).overrideAttrs
                    (old: {
                      postPatch =
                        (old.postPatch or "")
                        + ''
                          # Keep pkgdown's metadata sidebar, without online CRAN/Bioconductor discovery.
                          substituteInPlace R/build-home-index.R \
                            --replace-fail 'repo <- cran_link(pkg$package)' 'repo <- NULL'
                        ''
                        +
                          lib.optionalString
                            (cfg.pkgdown.privacy.page != null && lib.hasPrefix "pkgdown/" cfg.pkgdown.privacy.page)
                            ''
                              # Extra home pages are normally discovered only in the root and .github/.
                              substituteInPlace R/build-home-md.R \
                                --replace-fail 'mds <- dir_ls(path, glob = "*.md")' ${lib.escapeShellArg ''
                                  mds <- dir_ls(path, glob = "*.md")
                                  extra <- file.path(path, ${builtins.toJSON cfg.pkgdown.privacy.page})
                                  if (file_exists(extra)) mds <- c(mds, extra)
                                ''}
                            '';
                    });
              };
          };
        in
        {
          config.nullkomma.r = {
            inherit lock;
            packages = lib.unique (
              lock.nixpkgs
              ++ lib.attrNames lock.sources
              ++ cfg.extraPackages
              ++ [
                "languageserver"
                "pak"
              ]
            );
            package = pkgsR.rWrapper.override { packages = map lookup pcfg.packages; };
          };
        }
      );
    };
}
