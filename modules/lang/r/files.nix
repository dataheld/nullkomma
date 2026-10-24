{
  plugins.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
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
        "^[.]nullkomma$"
        "^result(-.*)?$"
        "^docs$"
        "^pkgdown$"
        "^coverage[.]xml$"
        "^pkg[.]lock$"
      ];
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
        # R reads every line as a pattern; the markers match no file.
        perSystem.nullkomma.files."${cfg.prefix}.Rbuildignore" = {
          commentPrefix = "#";
          sections.r = cfg.buildIgnore;
        };
      };
    };
}
