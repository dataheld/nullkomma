{
  flake.flakeModules.default =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.editor.vscode;
    in
    {
      options.nullkomma.editor.vscode = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to generate `.vscode/settings.json` and `.vscode/extensions.json`.";
        };
        extensions = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Recommended VS Code extensions; every aspect appends here.";
        };
        settings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "VS Code workspace settings; every aspect merges into these.";
        };
      };
      config = {
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
            "nix.hiddenLanguageServerErrors" = [
              "textDocument/definition"
              "textDocument/completion"
              "textDocument/documentHighlight"
            ];
            "editor.defaultFormatter" = "ibecker.treefmt-vscode";
            "notebook.defaultFormatter" = "ibecker.treefmt-vscode";
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
                recommendations = lib.sort lib.lessThan (lib.unique cfg.extensions);
              };
              ".vscode/settings.json".source = json.generate "vscode-settings.json" cfg.settings;
            };
          };
      };
    };
}
