{ inputs, ... }:
{
  framework =
    { config, lib, ... }:
    {
      # Imported by the framework so any plugin can set `treefmt.programs`. Only the
      # `treefmt` plugin turns on `nix fmt` and the check; reading its option with
      # `or false` avoids priority tricks and works when the plugin isn't imported.
      imports = [ inputs.treefmt-nix.flakeModule ];
      perSystem.treefmt = {
        flakeFormatter = lib.mkDefault (config.nullkomma.treefmt.enable or false);
        flakeCheck = lib.mkDefault (config.nullkomma.treefmt.enable or false);
      };
    };
  plugins.treefmt =
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
