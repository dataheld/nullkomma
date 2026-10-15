# `devShells.default`: every column contributes its tools (tasks, editor tools,
# dev helpers); `devHelpers` are tools no other column covers.
{
  framework =
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
        options.nullkomma = {
          devHelpers = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            example = lib.literalExpression "[ pkgs.hello ]";
            description = "Dev helpers: tools on `PATH` in `devShells.default` that are no task, test, formatter or editor tool.";
          };
          devshell = {
            packages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              internal = true;
              description = "Everything on `PATH` in `devShells.default`, collected from the frameworks.";
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
      };
      config.perSystem =
        { config, pkgs, ... }:
        let
          cfg = config.nullkomma.devshell;
        in
        {
          nullkomma.devshell.packages = config.nullkomma.devHelpers;
          devShells = lib.mkIf enabled {
            default = lib.mkDefault (pkgs.mkShell { inherit (cfg) packages env shellHook; });
          };
        };
    };
}
