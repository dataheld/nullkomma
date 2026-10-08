# R and its packages come from `nixpkgs-r`, which follows nullkomma's nixpkgs
# unless a consumer repoints it (e.g. at an rstats-on-nix date).
{ inputs, ... }:
{
  flake.flakeModules.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
      rlib = import ../../../lib/r.nix { inherit lib; };
      names = lib.unique (
        lib.optionals (cfg.description != null) (
          rlib.depsFromDescription {
            path = cfg.description;
            inherit (cfg) fields;
          }
        )
        ++ cfg.extraPackages
        ++ [ "languageserver" ]
      );
    in
    {
      perSystem =
        { system, ... }:
        let
          pkgsR = inputs.nixpkgs-r.legacyPackages.${system};
          lookup =
            name:
            pkgsR.rPackages.${rlib.attrName name}
            or (throw "nullkomma.r: R package `${name}` is not in `rPackages` of nixpkgs-r; pin a newer nixpkgs-r or drop it from DESCRIPTION/extraPackages.");
        in
        {
          options.nullkomma.r.package = lib.mkOption {
            type = lib.types.package;
            readOnly = true;
            description = "R with every package from DESCRIPTION and `nullkomma.r.extraPackages`.";
          };
          config.nullkomma.r.package = pkgsR.rWrapper.override { packages = map lookup names; };
        };
    };
}
