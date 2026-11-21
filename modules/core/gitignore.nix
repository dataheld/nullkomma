{
  framework =
    { lib, ... }:
    {
      options.nullkomma.gitignore = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Lines nullkomma requires in `.gitignore`; plugins append here. Links are added automatically.";
      };
    };
  plugins.git =
    { config, lib, ... }:
    let
      ignores = lib.unique config.nullkomma.gitignore;
    in
    {
      config = lib.mkIf config.nullkomma.git.enable {
        perSystem =
          { config, pkgs, ... }:
          {
            nullkomma.devShell.packages = [ pkgs.git ];
            nullkomma.files.".gitignore".text = lib.concatLines (
              ignores
              ++ map (path: "/${path}") (
                lib.attrNames (lib.filterAttrs (_: link: link.enable) config.nullkomma.links)
              )
            );
          };
      };
    };
}
