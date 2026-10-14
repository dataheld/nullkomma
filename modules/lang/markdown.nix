{
  flake.plugins.markdown =
    { config, lib, ... }:
    {
      options.nullkomma.markdown.enable = lib.mkEnableOption "Markdown project integration";
      config.perSystem.treefmt.programs.mdformat = lib.mkIf config.nullkomma.markdown.enable {
        enable = lib.mkDefault true;
        plugins = lib.mkDefault (ps: [
          ps.mdformat-footnote
          ps.mdformat-frontmatter
          ps.mdformat-gfm
          ps.mdformat-gfm-alerts
        ]);
      };
    };
}
