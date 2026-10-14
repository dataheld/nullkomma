{
  flake.plugins.direnv =
    { config, lib, ... }:
    {
      options.nullkomma.direnv.enable = lib.mkEnableOption "direnv project integration";
      config = lib.mkIf config.nullkomma.direnv.enable {
        nullkomma.gitignore = [ ".direnv/" ];
        nullkomma.editor.vscode = lib.mkIf (config.nullkomma.editor.enable or false) {
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
