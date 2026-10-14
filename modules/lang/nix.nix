{
  flake.plugins.nix =
    { config, lib, ... }:
    let
      cfg = config.nullkomma;
    in
    {
      options.nullkomma.nix.enable = lib.mkEnableOption "Nix project integration";
      config = lib.mkIf cfg.nix.enable {
        nullkomma.gitignore = [
          "result"
          "result-*"
        ];
        nullkomma.editor.vscode = lib.mkIf (cfg.editor.enable or false) {
          extensions = [ "jnoortheen.nix-ide" ];
          settings = lib.mapAttrs (_: lib.mkDefault) (
            {
              "nix.enableLanguageServer" = true;
              "nix.serverPath" = "nixd";
            }
            // lib.optionalAttrs (cfg.treefmt.enable or false) {
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
            }
          );
        };
        perSystem =
          { pkgs, ... }:
          {
            nullkomma.devshell.packages = [
              pkgs.nixd
              pkgs.flake-checker
            ];
            treefmt.programs = {
              nixfmt.enable = lib.mkDefault true;
              deadnix.enable = lib.mkDefault true;
            };
            nullkomma.tasks = {
              check = {
                description = "Evaluate and build all checks (nix flake check)";
                command = ''exec nix flake check "$@"'';
              };
              flake-checker = {
                description = "Check flake.lock for outdated or non-upstream Nixpkgs";
                runtimeInputs = [ pkgs.flake-checker ];
                command = ''exec flake-checker "$@"'';
              };
              update = {
                description = "Update flake.lock (prefer the scheduled maintenance workflow)";
                command = ''exec nix flake update "$@"'';
              };
            };
          };
      };
    };
}
