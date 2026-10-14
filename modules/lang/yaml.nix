{
  plugins.yaml =
    { config, lib, ... }:
    {
      config = lib.mkIf config.nullkomma.yaml.enable {
        nullkomma.editor.languageServers.yamlls = {
          command = [
            "yaml-language-server"
            "--stdio"
          ];
          filetypes = [ "yaml" ];
        };
        nullkomma.editor.vscode.extensions = [ "redhat.vscode-yaml" ];
        perSystem =
          { pkgs, ... }:
          {
            nullkomma.devshell.packages = [ pkgs.yaml-language-server ];
            treefmt.programs.yamlfmt.enable = lib.mkDefault true;
          };
      };
    };
}
