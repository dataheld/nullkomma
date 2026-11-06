{
  framework =
    { lib, ... }:
    {
      options.nullkomma.gitignore = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Lines of nullkomma's section of `.gitignore`; plugins append here. Generated files are added automatically; generated directories ignore themselves.";
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
          let
            generated = lib.attrNames (
              lib.filterAttrs (_: f: f.enable && f.mode == "generated" && !f.directory) config.nullkomma.files
            );
          in
          {
            nullkomma.devShell.packages = [ pkgs.git ];
            # Sections, as the project and tools such as Quarto also add lines here.
            nullkomma.files.".gitignore" = {
              commentPrefix = "#";
              sections.git = lib.concatLines (ignores ++ map (path: "/${path}") generated);
            };
          };
      };
    };
}
