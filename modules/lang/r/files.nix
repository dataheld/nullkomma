{
  plugins.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
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
        "^[.]git$"
        "^[.]github$"
        "^[.]vscode$"
        "^[.]nvim[.]lua$"
        "^result(-.*)?$"
        "^docs$"
        "^pkgdown$"
        "^coverage[.]xml$"
        "^pkg[.]lock$"
      ]
      ++ lib.optional (
        cfg.pkgdown.enable
        && cfg.pkgdown.privacy.page != null
        && !lib.hasPrefix ".github/" cfg.pkgdown.privacy.page
        && config.nullkomma.privacy.policy != { }
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
        perSystem.nullkomma.files."${cfg.prefix}.Rbuildignore" = {
          initialSource = if builtins.pathExists buildignore then buildignore else null;
          text = cfg.buildIgnore;
        };
      };
    };
}
