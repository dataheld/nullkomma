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
          treefmt.programs.yamllint = {
            enable = lib.mkDefault true;
            priority = 1;
            package = pkgs.writeShellScriptBin "yamllint" ''
              export YAMLLINT_CONFIG_FILE=${
                (pkgs.formats.yaml { }).generate "yamllint.yaml" {
                  extends = "relaxed";
                  rules.line-length = "disable";
                }
              }
              exec ${lib.getExe pkgs.yamllint} "$@"
            '';
          };
        };
    };
}
