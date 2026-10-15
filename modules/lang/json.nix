{
  plugins.json =
    { config, lib, ... }:
    {
      config.perSystem =
        { pkgs, ... }:
        lib.mkIf config.nullkomma.json.enable {
          nullkomma.editor.languageServers.jsonls = {
            package = pkgs.vscode-langservers-extracted;
            command = [
              "vscode-json-language-server"
              "--stdio"
            ];
            filetypes = [
              "json"
              "jsonc"
            ];
          };
          treefmt.programs.jsonfmt.enable = lib.mkDefault true;
        };
    };
}
