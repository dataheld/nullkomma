{
  plugins.yaml =
    { config, lib, ... }:
    {
      config = lib.mkIf config.nullkomma.yaml.enable {
        perSystem =
          { pkgs, ... }:
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
            treefmt.settings.formatter.actionlint.options = [
              "-config-file"
              (toString ((pkgs.formats.yaml { }).generate "actionlint.yaml" config.nullkomma.lint.actionlint))
              "-shellcheck"
              (lib.getExe (
                pkgs.writeShellScriptBin "shellcheck" ''
                  exec ${lib.getExe pkgs.shellcheck} --norc "$@"
                ''
              ))
            ];
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
