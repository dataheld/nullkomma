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
    let
      enabled = config.nullkomma.treefmt.enable;
    in
    {
      config.perSystem =
        { config, ... }:
        lib.mkIf enabled {
          nullkomma.editor = {
            formatter = {
              package = config.treefmt.build.wrapper;
              command = [
                "treefmt"
                "--stdin"
                "{file}"
              ];
            };
            vscode.extensions = [ "ibecker.treefmt-vscode" ];
            vscode.settings."editor.defaultFormatter" = lib.mkDefault "ibecker.treefmt-vscode";
          };
          treefmt.settings.excludes = lib.attrNames (lib.filterAttrs (_: f: f.enable) config.nullkomma.files);
        };
    };
}
