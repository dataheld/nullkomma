# R and its packages come from `nixpkgs-r`, which follows nullkomma's nixpkgs
# unless a consumer repoints it (e.g. at an rstats-on-nix date).
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
        options.nullkomma.r.dependencies = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          readOnly = true;
          description = "Package names `nullkomma.r.description` depends on in `nullkomma.r.fields`, as parsed by R itself (base packages excluded).";
        };
        options.nullkomma.r.package = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          description = "R with every package from DESCRIPTION and `nullkomma.r.extraPackages`.";
        };
      };
      config.perSystem =
        { system, ... }:
        let
          pkgsR = inputs.nixpkgs-r.legacyPackages.${system};
          # Import from derivation: R's own DESCRIPTION parser, from the pinned R.
          dependencies = lib.optionals (cfg.description != null) (
            lib.filter (n: n != "") (
              lib.splitString "\n" (
                builtins.readFile (
                  pkgsR.runCommandLocal "r-description-deps"
                    {
                      nativeBuildInputs = [ pkgsR.R ];
                      description = pkgsR.writeText "DESCRIPTION" (builtins.readFile cfg.description);
                    }
                    ''
                      export HOME="$TMPDIR"
                      Rscript ${../../../lib/description-deps.R} "$description" ${lib.escapeShellArgs cfg.fields} > $out
                    ''
                )
              )
            )
          );
          names = lib.unique (dependencies ++ cfg.extraPackages ++ [ "languageserver" ]);
          lookup =
            name:
            pkgsR.rPackages.${rlib.attrName name}
            or (throw "nullkomma.r: R package `${name}` is not in `rPackages` of nixpkgs-r; pin a newer nixpkgs-r or drop it from DESCRIPTION/extraPackages.");
        in
        {
          config.nullkomma.r = {
            inherit dependencies;
            package = pkgsR.rWrapper.override { packages = map lookup names; };
          };
        };
    };
}
