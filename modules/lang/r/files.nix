{
  plugins.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
      rules = [
        # R CMD check accepts no other top-level hidden files.
        "^[.](?!aspell(/|$)|Rinstignore$)"
        "[.]nix$"
        "^flake[.]lock$"
        "^AGENTS[.]md$"
        "^result(-.*)?$"
        "^pkgdown$"
        "^coverage[.]xml$"
        "^pkg[.]lock$"
      ]
      ++ lib.optional cfg.pkgdown.enable "^${lib.escapeRegex cfg.pkgdown.config.destination}$";
    in
    {
      config = lib.mkIf cfg.enable {
        perSystem.nullkomma = {
          files."${cfg.prefix}.Rbuildignore".text = lib.concatLines rules;
          links."${cfg.prefix}.Rprofile".text = builtins.readFile ./_profile.R;
        };
      };
    };
}
