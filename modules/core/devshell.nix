# `devShells.default`, built from `nullkomma.devShell`: plugins and the framework
# (tasks, language servers) add packages, environment and shell hooks to it.
{
  framework =
    {
      config,
      flake-parts-lib,
      lib,
      ...
    }:
    let
      enabled = config.nullkomma.devShell.enable;
    in
    {
      options.nullkomma.devShell.enable = lib.mkEnableOption "the project development shell, `devShells.<system>.default`";
      options.perSystem = flake-parts-lib.mkPerSystemOption {
        options.nullkomma.devShell = {
          packages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            example = lib.literalExpression "[ pkgs.hello ]";
            description = "Packages on `PATH` in `devShells.default`, next to the tasks and language servers.";
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
          cfg = config.nullkomma.devShell;
        in
        {
          devShells = lib.mkIf enabled {
            default = lib.mkDefault (pkgs.mkShell { inherit (cfg) packages env shellHook; });
          };
        };
    };
}
