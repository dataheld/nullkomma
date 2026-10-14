{
  flake.plugins.direnv =
    { config, lib, ... }:
    {
      config = lib.mkIf config.nullkomma.direnv.enable {
        nullkomma.gitignore = [ ".direnv/" ];
        nullkomma.editor.vscode = {
          extensions = [ "arrterian.nix-env-selector" ];
          settings = lib.mapAttrs (_: lib.mkDefault) {
            "nixEnvSelector.nixFile" = "\${workspaceFolder}/flake.nix";
            "nixEnvSelector.useFlakes" = true;
            "nixEnvSelector.suggestion" = false;
          };
        };
        perSystem.nullkomma.files.".envrc".text = ''
          # shellcheck shell=bash
          use flake
        '';
      };
    };
}
