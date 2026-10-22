{
  plugins.typos =
    { config, lib, ... }:
    {
      config.perSystem =
        { pkgs, ... }:
        lib.mkIf config.nullkomma.typos.enable {
          treefmt.programs.typos = {
            enable = lib.mkDefault true;
            isolated = true;
            configFile = lib.mkDefault (
              toString ((pkgs.formats.toml { }).generate "nullkomma-typos.toml" config.nullkomma.lint.typos)
            );
          };
          # typos only knows English; skip translations named like privacy sections.
          treefmt.settings.formatter.typos.excludes = map (language: "*.${language.code}.md") (
            lib.filter (language: language.code != "en") config.nullkomma.privacy.languages
          );
        };
    };
}
