{
  flake.flakeModules.default =
    { flake-parts-lib, lib, ... }:
    {
      options.perSystem = flake-parts-lib.mkPerSystemOption {
        options.nullkomma.devshell = {
          packages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            description = "Packages on `PATH` in `devShells.default`; every aspect appends here.";
          };
          env = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Environment variables set in `devShells.default`.";
          };
          shellHook = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = "Shell code run when entering `devShells.default`.";
          };
        };
      };
      config.perSystem =
        { config, pkgs, ... }:
        let
          cfg = config.nullkomma.devshell;
        in
        {
          config = {
            nullkomma.devshell.packages = [
              config.treefmt.build.wrapper
              pkgs.flake-checker
              pkgs.git
              pkgs.nixd
            ];
            devShells.default = lib.mkDefault (
              pkgs.mkShell {
                inherit (cfg) packages env shellHook;
              }
            );
          };
        };
    };
}
