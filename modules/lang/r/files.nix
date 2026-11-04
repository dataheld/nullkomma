{
  plugins.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
      rules = [
        "[.]nix$"
        "^flake[.]lock$"
        "^[.]agents$"
        "^AGENTS[.]md$"
        "^[.]envrc$"
        "^[.]Renviron$"
        "^[.]Rprofile$"
        "^[.]R$"
        "^[.]direnv$"
        "^[.]git$"
        "^[.]github$"
        "^[.]vscode$"
        "^[.]nvim[.]lua$"
        "^[.]mcp[.]json$"
        "^[.]nullkomma$"
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
          "${cfg.prefix}.Rprofile" = {
            mode = lib.mkDefault "generated";
            commentPrefix = "#";
            text = lib.mkMerge [
              # R skips the user's profile when a project has one.
              (lib.mkBefore ''if (file.exists("~/.Rprofile")) source("~/.Rprofile")'')
              (lib.mkAfter (builtins.readFile ./_load-all.R))
            ];
          };
        };
      };
    };
}
