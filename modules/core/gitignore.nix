{
  flake.framework =
    { lib, ... }:
    {
      options.nullkomma.gitignore = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Lines of the initial `.gitignore`; plugins append here.";
      };
    };
  flake.plugins.git =
    { config, lib, ... }:
    let
      ignores = lib.unique config.nullkomma.gitignore;
    in
    {
      options.nullkomma.git.enable = lib.mkEnableOption "Git project integration";
      config = lib.mkIf config.nullkomma.git.enable {
        # Initialized files are re-included last, so a global excludesFile (e.g. one ignoring
        # `.vscode/settings.json` or `.envrc`) can't keep them out of the flake source.
        perSystem =
          { config, pkgs, ... }:
          {
            nullkomma.devshell.packages = [ pkgs.git ];
            nullkomma.files.".gitignore".text = lib.concatLines (
              ignores
              ++ [ "# Initialized files" ]
              ++ map (path: "!/${path}") (lib.attrNames (lib.filterAttrs (_: f: f.enable) config.nullkomma.files))
            );
          };
      };
    };
}
