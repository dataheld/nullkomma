{
  flake.framework =
    {
      config,
      flake-parts-lib,
      lib,
      ...
    }:
    let
      enabled = config.nullkomma.devshell.enable;
    in
    {
      options.nullkomma.devshell.enable = lib.mkEnableOption "the project development shell";
      options.perSystem = flake-parts-lib.mkPerSystemOption {
        options.nullkomma.devshell = {
          packages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            description = "Packages on `PATH` in `devShells.default`; every plugin appends here.";
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
            devShells = lib.mkIf enabled {
              default = lib.mkDefault (
                pkgs.mkShell {
                  inherit (cfg) packages env shellHook;
                }
              );
            };
          };
        };
    };
}
