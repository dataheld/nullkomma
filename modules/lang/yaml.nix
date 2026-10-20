{
  plugins.yaml =
    { config, lib, ... }:
    {
      config = lib.mkIf config.nullkomma.yaml.enable {
        nullkomma.lint.yaml = {
          extends = lib.mkDefault "relaxed";
          rules.line-length = lib.mkDefault "disable";
        };
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
            treefmt.programs.yamlfmt.enable = lib.mkDefault true;
            treefmt.programs.yamllint = {
              enable = lib.mkDefault true;
              priority = 1;
              package = pkgs.writeShellScriptBin "yamllint" ''
                export NULLKOMMA_YAMLLINT_CONFIG=${
                  (pkgs.formats.yaml { }).generate "nullkomma-yamllint.yaml" config.nullkomma.lint.yaml
                }
                exec ${
                  lib.getExe (
                    pkgs.yamllint.overrideAttrs (old: {
                      patches = (old.patches or [ ]) ++ [ ../../patches/yamllint.patch ];
                    })
                  )
                } "$@"
              '';
            };
          };
      };
    };
}
