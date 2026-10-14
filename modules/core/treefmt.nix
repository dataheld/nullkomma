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
    {
      config = lib.mkIf config.nullkomma.treefmt.enable {
        nullkomma.editor = {
          formatCommand = [
            "treefmt"
            "--stdin"
            "{file}"
          ];
          vscode.extensions = [ "ibecker.treefmt-vscode" ];
          vscode.settings."editor.defaultFormatter" = lib.mkDefault "ibecker.treefmt-vscode";
        };
        perSystem =
          { config, ... }:
          {
            treefmt.settings.excludes = lib.attrNames (lib.filterAttrs (_: f: f.enable) config.nullkomma.files);
            nullkomma.devshell.packages = [ config.treefmt.build.wrapper ];
          };
      };
    };
}
