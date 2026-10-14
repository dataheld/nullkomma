{ inputs, ... }:
{
  flake.framework =
    { config, lib, ... }:
    {
      imports = [ inputs.treefmt-nix.flakeModule ];
      perSystem.treefmt = {
        flakeFormatter = lib.mkDefault (config.nullkomma.treefmt.enable or false);
        flakeCheck = lib.mkDefault (config.nullkomma.treefmt.enable or false);
      };
    };
  flake.plugins.treefmt =
    { config, lib, ... }:
    let
      enabled = config.nullkomma.treefmt.enable;
    in
    {
      options.nullkomma.treefmt.enable = lib.mkEnableOption "treefmt integration";
      config = {
        nullkomma.editor.vscode = lib.mkIf enabled {
          extensions = [ "ibecker.treefmt-vscode" ];
          settings."editor.defaultFormatter" = lib.mkDefault "ibecker.treefmt-vscode";
        };
        perSystem =
          { config, ... }:
          {
            treefmt = {
              settings.excludes = lib.attrNames (lib.filterAttrs (_: f: f.enable) config.nullkomma.files);
            };
            nullkomma.devshell.packages = lib.mkIf enabled [ config.treefmt.build.wrapper ];
          };
      };
    };
}
