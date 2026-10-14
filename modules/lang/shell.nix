{
  flake.plugins.shell =
    { config, lib, ... }:
    {
      config = lib.mkIf config.nullkomma.shell.enable {
        nullkomma.editor.languageServers.bashls = {
          command = [
            "bash-language-server"
            "start"
          ];
          filetypes = [
            "bash"
            "sh"
          ];
        };
        nullkomma.editor.vscode.extensions = [ "mads-hartmann.bash-ide-vscode" ];
        perSystem =
          { pkgs, ... }:
          {
            nullkomma.devshell.packages = [ pkgs.bash-language-server ];
            treefmt.programs = {
              shellcheck.enable = lib.mkDefault true;
              shfmt.enable = lib.mkDefault true;
            };
          };
      };
    };
}
