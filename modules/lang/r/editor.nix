{
  plugins.r =
    { config, lib, ... }:
    {
      config.perSystem = lib.mkIf config.nullkomma.r.enable (
        { config, ... }:
        let
          r = "${config.nullkomma.r.package}/bin/R";
          radian = "${config.nullkomma.r.package}/bin/radian";
        in
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
            vscode.settings = lib.mapAttrs (_: lib.mkDefault) {
              # Supported by vscode-R 2.x and retained as aliases in 3.x.
              "r.rpath.linux" = r;
              "r.rpath.mac" = r;
              "r.rterm.linux" = radian;
              "r.rterm.mac" = radian;
              "r.bracketedPaste" = true;
              "r.plot.useHttpgd" = true;
              # nixpkgs' extension otherwise adds its own languageserver library.
              "r.libPaths" = [ ];
            };
          };
        }
      );
    };
}
