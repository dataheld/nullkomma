{
  plugins.markdown =
    { config, lib, ... }:
    {
      config.nullkomma.lint.markdown = lib.mkIf config.nullkomma.markdown.enable {
        MD041 = lib.mkDefault false;
      };
      config.perSystem =
        { pkgs, ... }:
        let
          rules = config.nullkomma.lint.markdown;
          ruleConfig = (pkgs.formats.toml { }).generate "rumdl.toml" (
            lib.filterAttrs (_: lib.isAttrs) rules
            // {
              global.disable = builtins.attrNames (lib.filterAttrs (_: v: v == false) rules);
            }
          );
        in
        lib.mkIf config.nullkomma.markdown.enable {
          treefmt.programs.rumdl-check = {
            enable = lib.mkDefault true;
            priority = 1;
          };
          treefmt.settings.formatter.rumdl-check.options = [
            "--no-cache"
            "--config"
            (toString ruleConfig)
          ];
          nullkomma.editor.languageServers.marksman = {
            package = pkgs.marksman;
            command = [
              "marksman"
              "server"
            ];
            filetypes = [ "markdown" ];
          };
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
}
