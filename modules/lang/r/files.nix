{
  plugins.r =
    {
      config,
      lib,
      self,
      ...
    }:
    let
      cfg = config.nullkomma.r;
      prefix =
        if toString cfg.root == toString self then
          ""
        else
          "${lib.removePrefix "${toString self}/" (toString cfg.root)}/";
      buildignore = cfg.root + "/.Rbuildignore";
      existing = if builtins.pathExists buildignore then builtins.readFile buildignore else "";
      lines = lib.splitString "\n" existing;
      rules = [
        "[.]nix$"
        "^flake[.]lock$"
        "^[.]envrc$"
        "^[.]Renviron$"
        "^[.]Rprofile$"
        "^[.]R$"
        "^[.]direnv$"
        "^[.]github$"
        "^[.]vscode$"
        "^[.]idea$"
        "^result(-.*)?$"
        "^docs$"
        "^pkgdown$"
        "^coverage[.]xml$"
        "^${lib.escapeRegex (lib.removePrefix "${toString cfg.root}/" (toString cfg.lockfile))}$"
      ]
      ++ lib.optional (
        cfg.pkgdown.enable
        && cfg.pkgdown.privacy.page != null
        && lib.any (section: section.enable) (lib.attrValues config.nullkomma.privacy.sections)
      ) "^${lib.escapeRegex cfg.pkgdown.privacy.page}$";
    in
    {
      options.nullkomma.r.buildIgnore = lib.mkOption {
        type = lib.types.lines;
        internal = true;
        readOnly = true;
        description = "Shared R build exclusions, including the project's existing rules.";
      };
      config = lib.mkIf cfg.enable {
        nullkomma.r.buildIgnore =
          existing
          + lib.optionalString (existing != "" && !lib.hasSuffix "\n" existing) "\n"
          + lib.concatMapStrings (rule: lib.optionalString (!(lib.elem rule lines)) "${rule}\n") rules;
        # External package sources may be checked, but write-files only owns paths in this repo.
        perSystem.nullkomma.files =
          lib.mkIf
            (toString cfg.root == toString self || lib.hasPrefix "${toString self}/" (toString cfg.root))
            {
              "${prefix}.Rbuildignore" = {
                initialSource = if builtins.pathExists buildignore then buildignore else null;
                text = cfg.buildIgnore;
              };
            };
      };
    };
}
