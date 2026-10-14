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
        perSystem =
          { config, pkgs, ... }:
          {
            nullkomma.devshell.packages = [ pkgs.git ];
            nullkomma.files.".gitignore".text = lib.concatLines (
              ignores
              ++ map (path: "/${path}") (
                lib.attrNames (lib.filterAttrs (_: f: f.enable && f.gitignore) config.nullkomma.files)
              )
            );
          };
      };
    };
}
