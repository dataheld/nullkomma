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
        "^docs$"
        "^pkgdown$"
        "^coverage[.]xml$"
        "^pkg[.]lock$"
      ]
      ++ lib.optional cfg.pkgdown.enable "^${lib.escapeRegex cfg.pkgdown.config.destination}$";
    in
    {
      options.nullkomma.r.buildIgnore = lib.mkOption {
        type = lib.types.lines;
        internal = true;
        readOnly = true;
        description = "Shared R build exclusions.";
      };
      config = lib.mkIf cfg.enable {
        nullkomma.r.buildIgnore = lib.concatLines rules;
        perSystem.nullkomma.files = {
          # R reads every line as a pattern; the markers match no file.
          "${cfg.prefix}.Rbuildignore" = {
            commentPrefix = "#";
            sections.r = cfg.buildIgnore;
          };
          "${cfg.prefix}.Rprofile" =
            let
              profile = lib.concatStringsSep "\n" (
                # R skips the user's profile when a project has one.
                [ ''if (file.exists("~/.Rprofile")) source("~/.Rprofile")'' ]
                # Without Nix, the profile is committed for collaborators, with their own lines.
                ++ lib.optional cfg.nonNix.enable (builtins.readFile ../r-non-nix/_assets/profile.R)
                ++ [ (builtins.readFile ./_load-all.R) ]
              );
            in
            {
              commentPrefix = "#";
            }
            // (
              if cfg.nonNix.enable then
                { sections.r = profile; }
              else
                {
                  mode = lib.mkDefault "generated";
                  text = profile;
                }
            );
        };
      };
    };
}
