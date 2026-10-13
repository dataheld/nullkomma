# R and its packages come from nixpkgs (inputs.nixpkgs-r, defaulting to nullkomma's nixpkgs).
# pak's lockfile decides which packages; with `allowOffNixpkgs`, those nixpkgs
# cannot provide are built from the sources the lockfile pins.
{ inputs, ... }:
{
  flake.flakeModules.r =
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
      config.perSystem =
        { system, config, ... }:
        let
          pcfg = config.nullkomma.r;
          pkgsR = inputs.nixpkgs-r.legacyPackages.${system};
          base = pkgsR.rPackages;

          lock =
            if cfg.description == null then
              {
                nixpkgs = [ ];
                sources = { };
                refs = [ ];
              }
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
              tree = builtins.fetchTree s.fetchTree;
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
          final = base.override { overrides = sourceOverrides // systemLibraries; };
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
        };
    };
}
