{ inputs, ... }:
{
  flake.flakeModules.r =
    {
      config,
      lib,
      self,
      ...
    }:
    let
      rlib = import ../../../lib/r.nix { inherit lib; };
      description = config.nullkomma.r.root + "/DESCRIPTION";
    in
    {
      imports = [ inputs.self.flakeModules.default ];
      options.nullkomma.r = {
        root = lib.mkOption {
          type = lib.types.path;
          default = self;
          defaultText = lib.literalExpression "self";
          example = lib.literalExpression "./pkg";
          description = "R project directory (containing `DESCRIPTION`); a path literal if not the repo root.";
        };
        description = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = if builtins.pathExists description then description else null;
          defaultText = lib.literalExpression ''root + "/DESCRIPTION" (if it exists)'';
          description = "R DESCRIPTION file: the single source of truth for R dependencies.";
        };
        fields = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = rlib.defaultFields;
          description = "DESCRIPTION fields whose packages are added to the R environment.";
        };
        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "devtools" ];
          description = "Extra CRAN/Bioconductor package names (e.g. dev tooling not in DESCRIPTION).";
        };
      };
    };
}
