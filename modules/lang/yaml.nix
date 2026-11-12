{
  plugins.yaml =
    { config, lib, ... }:
    let
      inherit (config.nullkomma.lint) actionlint;
    in
    {
      config = lib.mkIf config.nullkomma.yaml.enable {
        perSystem =
          { config, pkgs, ... }:
          {
            nullkomma.editor.languageServers.yamlls = {
              package = pkgs.yaml-language-server;
              command = [
                "yaml-language-server"
                "--stdio"
              ];
              filetypes = [ "yaml" ];
            };
            nullkomma.editor.vscode.extensions = [ "redhat.vscode-yaml" ];
            treefmt.programs.actionlint.enable = lib.mkDefault true;
            treefmt.settings.formatter.actionlint = lib.mkIf config.treefmt.programs.actionlint.enable {
              options = [
                "-config-file"
                (toString ((pkgs.formats.yaml { }).generate "actionlint.yaml" actionlint))
                "-shellcheck"
                (lib.getExe (
                  pkgs.writeShellScriptBin "shellcheck" ''
                    exec ${lib.getExe pkgs.shellcheck} --norc "$@"
                  ''
                ))
              ];
            };
            treefmt.programs.yamlfmt.enable = lib.mkDefault true;
            treefmt.programs.yamllint = {
              enable = lib.mkDefault true;
              priority = 1;
              settings = {
                extends = lib.mkDefault "relaxed";
                rules.line-length = lib.mkDefault "disable";
              };
            };
          };
      };
    };
}
