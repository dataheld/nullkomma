{
  plugins.yaml =
    { config, lib, ... }:
    {
      config.perSystem =
        { pkgs, ... }:
        lib.mkIf config.nullkomma.yaml.enable {
          nullkomma.editor.languageServers.yamlls = {
            package = pkgs.yaml-language-server;
            command = [
              "yaml-language-server"
              "--stdio"
            ];
            filetypes = [ "yaml" ];
          };
          nullkomma.editor.vscode.extensions = [ "redhat.vscode-yaml" ];
          treefmt.programs.yamlfmt.enable = lib.mkDefault true;
        };
    };
}
