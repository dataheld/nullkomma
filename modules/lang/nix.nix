{
  flake.plugins.nix =
    { config, lib, ... }:
    let
      cfg = config.nullkomma;
      format = cfg.editor.formatCommand;
    in
    {
      config = lib.mkIf cfg.nix.enable {
        nullkomma.gitignore = [
          "result"
          "result-*"
        ];
        nullkomma.editor.languageServers.nixd = {
          command = [ "nixd" ];
          filetypes = [ "nix" ];
          settings = lib.optionalAttrs (format != null) { nixd.formatting.command = format; };
        };
        nullkomma.editor.vscode = {
          extensions = [ "jnoortheen.nix-ide" ];
          settings = lib.mapAttrs (_: lib.mkDefault) (
            {
              "nix.enableLanguageServer" = true;
              "nix.serverPath" = "nixd";
              "nix.serverSettings" = cfg.editor.languageServers.nixd.settings;
            }
            // lib.optionalAttrs (format != null) { "nix.formatterPath" = format; }
          );
        };
        perSystem =
          { pkgs, ... }:
          {
            nullkomma.devshell.packages = [ pkgs.nixd ];
            treefmt.programs = {
              nixfmt.enable = lib.mkDefault true;
              deadnix.enable = lib.mkDefault true;
              nixf-diagnose.enable = lib.mkDefault true;
            };
            nullkomma.tasks = {
              check = {
                description = "Evaluate and build all checks (nix flake check)";
                command = ''exec nix flake check "$@"'';
              };
              flake-checker = {
                description = "Check flake.lock for outdated or non-upstream Nixpkgs";
                packages = [ pkgs.flake-checker ];
                command = ''exec flake-checker "$@"'';
              };
              update = {
                skip = true;
                raw = true;
                description = "Update flake.lock, then refresh written and generated files using the updated flake";
                command = ''
                  nix flake update "$@"
                  status=0
                  nix develop --command write-files || status=1
                  nix develop --command generate-files || status=1
                  exit "$status"
                '';
              };
            };
          };
      };
    };
}
