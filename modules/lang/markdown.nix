{
  plugins.markdown =
    { config, lib, ... }:
    let
      rules = config.nullkomma.lint.markdown;
    in
    {
      config = lib.mkIf config.nullkomma.markdown.enable {
        nullkomma.lint.markdown.MD041 = lib.mkDefault false;
        perSystem =
          { config, pkgs, ... }:
          let
            ruleConfig = (pkgs.formats.toml { }).generate "rumdl.toml" (
              lib.filterAttrs (_: lib.isAttrs) rules
              // {
                global.disable = builtins.attrNames (lib.filterAttrs (_: v: v == false) rules);
              }
            );
          in
          {
            treefmt.programs.rumdl-check = {
              enable = lib.mkDefault true;
              priority = 1;
            };
            treefmt.settings.formatter.rumdl-check = lib.mkIf config.treefmt.programs.rumdl-check.enable {
              options = [
                "--no-cache"
                "--config"
                (toString ruleConfig)
              ];
            };
            nullkomma.editor.languageServers.rumdl = {
              package = pkgs.rumdl;
              command = [
                "rumdl"
                "server"
                "--config"
                (toString ruleConfig)
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
    };
}
