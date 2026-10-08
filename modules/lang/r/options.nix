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
      rprofile = config.nullkomma.r.root + "/.Rprofile";
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
        rprofile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = if builtins.pathExists rprofile then rprofile else null;
          defaultText = lib.literalExpression ''root + "/.Rprofile" (if it exists)'';
          description = ''
            Project `.Rprofile`. If it sets a CRAN snapshot date, e.g.
            `options(repos = c(CRAN = "https://packagemanager.posit.co/cran/2026-01-05"))`,
            R and packages come from the shipped rstats-on-nix revision for that date,
            not directly from PPM; equivalence of the two package sets is not guaranteed.
            Plain R and tools honoring `getOption("repos")` see the PPM repository.
            The profile runs during evaluation in an isolated directory: keep it self-contained.
          '';
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
