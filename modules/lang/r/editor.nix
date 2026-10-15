{
  plugins.r =
    { config, lib, ... }:
    {
      config.perSystem = lib.mkIf config.nullkomma.r.enable (
        { config, ... }:
        {
          nullkomma.editor = {
            languageServers.r = {
              package = config.nullkomma.r.package;
              command = [
                "R"
                "--slave"
                "-e"
                "languageserver::run()"
              ];
              filetypes = [
                "r"
                "rmd"
              ];
              settings.r.lsp.server_capabilities = lib.optionalAttrs (config.nullkomma.editor.formatter != null) {
                documentFormattingProvider = false;
                documentRangeFormattingProvider = false;
              };
            };
            vscode.extensions = [
              "Posit.air-vscode"
              "REditorSupport.r"
            ];
          };
        }
      );
    };
}
