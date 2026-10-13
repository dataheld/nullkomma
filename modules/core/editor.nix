{
  flake.flakeModules.default =
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
          description = "Whether to initialize project workspace files. Project editor data remains available through `editor.vscode` when disabled.";
        };
        extensions = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Project-relevant VS Code extension IDs; every aspect appends here. Installation and user preferences belong to the user environment.";
        };
        settings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Project-specific VS Code workspace settings; every aspect merges into these. Do not put personal editor preferences here.";
        };
      };
      config = {
        flake.editor.vscode = {
          extensions = lib.sort lib.lessThan (lib.unique cfg.extensions);
          settings = cfg.settings;
        };
        nullkomma.editor.vscode = {
          extensions = [
            "arrterian.nix-env-selector"
            "ibecker.treefmt-vscode"
            "jnoortheen.nix-ide"
          ];
          settings = lib.mapAttrs (_: lib.mkDefault) {
            "nixEnvSelector.nixFile" = "\${workspaceFolder}/flake.nix";
            "nixEnvSelector.useFlakes" = true;
            "nixEnvSelector.suggestion" = false;
            "nix.enableLanguageServer" = true;
            "nix.serverPath" = "nixd";
            "nix.serverSettings".nixd.formatting.command = [
              "treefmt"
              "--stdin"
              "{file}"
            ];
            "nix.formatterPath" = [
              "treefmt"
              "--stdin"
              "{file}"
            ];
            "editor.defaultFormatter" = "ibecker.treefmt-vscode";
          };
        };
        perSystem =
          { pkgs, ... }:
          let
            json = pkgs.formats.json { };
          in
          {
            nullkomma.files = lib.mkIf cfg.enable {
              ".vscode/extensions.json".source = json.generate "vscode-extensions.json" {
                recommendations = config.flake.editor.vscode.extensions;
              };
              ".vscode/settings.json".source = json.generate "vscode-settings.json" cfg.settings;
            };
          };
      };
    };
}
