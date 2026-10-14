{
  flake.framework =
    { lib, ... }:
    {
      options.nullkomma.gitignore = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Lines of the initial `.gitignore`; plugins append here. Generated files are added automatically.";
      };
    };
  flake.plugins.git =
    { config, lib, ... }:
    let
      ignores = lib.unique config.nullkomma.gitignore;
    in
    {
      config = lib.mkIf config.nullkomma.git.enable {
        perSystem =
          { config, pkgs, ... }:
          let
            generated = lib.attrNames (
              lib.filterAttrs (_: f: f.enable && f.mode == "generated") config.nullkomma.files
            );
          in
          {
            nullkomma.devshell.packages = [ pkgs.git ];
            nullkomma.files.".gitignore".text = lib.concatLines (ignores ++ map (path: "/${path}") generated);
          };
      };
    };
}
