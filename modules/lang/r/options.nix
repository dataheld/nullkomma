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
      # Extract snapshot date directly from the flake input's sourceInfo.
      # If nixpkgs-r has an explicit date ref (e.g. rstats-on-nix/YYYY-MM-DD), use it.
      # Otherwise format the locked commit date (lastModifiedDate: "YYYYMMDDhhmmss" -> "YYYY-MM-DD").
      sourceInfo = inputs.nixpkgs-r.sourceInfo or { };
      defaultSnapshot =
        if sourceInfo ? ref && builtins.match "[0-9]{4}-[0-9]{2}-[0-9]{2}" sourceInfo.ref != null then
          sourceInfo.ref
        else if sourceInfo ? lastModifiedDate then
          let
            d = sourceInfo.lastModifiedDate;
          in
          "${builtins.substring 0 4 d}-${builtins.substring 4 2 d}-${builtins.substring 6 2 d}"
        else
          "latest";
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
        snapshot = lib.mkOption {
          type = lib.types.str;
          default = defaultSnapshot;
          defaultText = lib.literalExpression "CRAN snapshot date of nixpkgs-r";
          description = "CRAN snapshot date corresponding to the package set in `nixpkgs-r`, for PPM and non-Nix interop.";
        };
        ppmUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://packagemanager.posit.co/cran/${config.nullkomma.r.snapshot}";
          defaultText = lib.literalExpression ''"https://packagemanager.posit.co/cran/''${snapshot}"'';
          description = "Posit Package Manager (PPM) repository URL corresponding to `nullkomma.r.snapshot`.";
        };
        rprofile = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Whether to initialize a project `.Rprofile` via `write-files` setting
              `options(repos = c(CRAN = nullkomma.r.ppmUrl))`.
              Disabled by default: all-in-on-Nix projects do not need an `.Rprofile`.
              Enable this if non-Nix collaborators need to install packages from a matching PPM snapshot.
            '';
          };
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
