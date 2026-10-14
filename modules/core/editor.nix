{
  flake.framework =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.editor.vscode;
    in
    {
      options.flake.editor = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.raw;
        default = { };
        description = "Evaluated project editor integration data.";
      };
      options.nullkomma.editor.vscode = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to initialize workspace files when the editor plugin is enabled. Editor data remains available when disabled.";
        };
        extensions = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Project-relevant VS Code extension IDs; plugins append here. User installation belongs to the user environment.";
        };
        settings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Project-specific VS Code settings; plugins merge here. Personal preferences belong elsewhere.";
        };
      };
      config.flake.editor.vscode = {
        extensions = lib.sort lib.lessThan (lib.unique cfg.extensions);
        settings = cfg.settings;
      };
    };
  flake.plugins.editor =
    { config, lib, ... }:
    {
      options.nullkomma.editor.enable = lib.mkEnableOption "project editor integration";
      config.perSystem =
        { pkgs, ... }:
        let
          cfg = config.nullkomma.editor.vscode;
          json = pkgs.formats.json { };
        in
        {
          nullkomma.files = lib.mkIf (config.nullkomma.editor.enable && cfg.enable) {
            ".vscode/extensions.json" = {
              gitignore = lib.mkDefault true;
              source = json.generate "vscode-extensions.json" {
                recommendations = config.flake.editor.vscode.extensions;
              };
            };
            ".vscode/settings.json" = {
              gitignore = lib.mkDefault true;
              source = json.generate "vscode-settings.json" cfg.settings;
            };
          };
        };
    };
}
