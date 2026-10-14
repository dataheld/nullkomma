{
  plugins.markdown =
    { config, lib, ... }:
    {
      config = lib.mkIf config.nullkomma.markdown.enable {
        nullkomma.editor.languageServers.marksman = {
          command = [
            "marksman"
            "server"
          ];
          filetypes = [ "markdown" ];
        };
        perSystem =
          { pkgs, ... }:
          {
            nullkomma.devshell.packages = [ pkgs.marksman ];
            treefmt.programs.mdformat = {
              enable = lib.mkDefault true;
              plugins = lib.mkDefault (ps: [
                ps.mdformat-footnote
                ps.mdformat-frontmatter
                ps.mdformat-gfm
                ps.mdformat-gfm-alerts
              ]);
            };
          };
      };
    };
}
