{
  plugins.json =
    { config, lib, ... }:
    {
      config = lib.mkIf config.nullkomma.json.enable {
        nullkomma.editor.languageServers.jsonls = {
          command = [
            "vscode-json-language-server"
            "--stdio"
          ];
          filetypes = [
            "json"
            "jsonc"
          ];
        };
        perSystem =
          { pkgs, ... }:
          {
            nullkomma.devshell.packages = [ pkgs.vscode-langservers-extracted ];
            treefmt.programs.jsonfmt.enable = lib.mkDefault true;
          };
      };
    };
}
