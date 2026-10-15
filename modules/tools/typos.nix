{
  plugins.typos =
    { config, lib, ... }:
    {
      config.perSystem = lib.mkIf config.nullkomma.typos.enable {
        treefmt.programs.typos.enable = lib.mkDefault true;
        # typos only knows English; skip translations named like privacy sections.
        treefmt.settings.formatter.typos.excludes = map (language: "*.${language.code}.md") (
          lib.filter (language: language.code != "en") config.nullkomma.privacy.languages
        );
      };
    };
}
