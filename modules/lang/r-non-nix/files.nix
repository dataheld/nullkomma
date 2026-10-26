{ config, ... }:
{
  flake.flakeModules.r-non-nix.imports = [ config.flake.flakeModules.r ];
  plugins.r =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      cfg = config.nullkomma.r;
      inherit (cfg) prefix;
      description = cfg.root + "/DESCRIPTION";
      # Native R then follows Config/Needs fields added to DESCRIPTION later, as Nix does.
      allConfigNeeds = lib.all (field: lib.elem field cfg.fields) (
        lib.optionals (builtins.pathExists description) (
          (import ../../../lib/r.nix { inherit lib; }).configNeedsFields (builtins.readFile description)
        )
      );
    in
    {
      imports = [
        (lib.mkRenamedOptionModule
          [ "nullkomma" "r-non-nix" "enable" ]
          [ "nullkomma" "r" "nonNix" "enable" ]
        )
      ];
      options.nullkomma.r.nonNix.enable =
        lib.mkEnableOption "R development without Nix using the same pinned dependencies";
      config = lib.mkMerge [
        {
          nullkomma.r.enable = lib.mkIf (
            options.nullkomma.r-non-nix.enable.isDefined && config.nullkomma.r-non-nix.enable
          ) true;
        }
        (lib.mkIf (cfg.enable && cfg.nonNix.enable) {
          nullkomma.gitignore = [ "${prefix}.R/library/" ];
          perSystem =
            { config, ... }:
            {
              nullkomma.files = {
                "${prefix}.Rprofile".text = builtins.readFile ./_assets/profile.R;
                "${prefix}.R/install.R".text = builtins.readFile ./_assets/install.R;
                "${prefix}.Renviron".text = ''
                  NULLKOMMA_R_VERSION=${builtins.toJSON config.nullkomma.r.package.version}
                  NULLKOMMA_PPM_SNAPSHOT=${builtins.toJSON cfg.snapshot}
                  NULLKOMMA_PPM_URL=${builtins.toJSON cfg.ppmUrl}
                  NULLKOMMA_R_DEPENDENCIES=${builtins.toJSON (lib.concatStringsSep "," cfg.fields)}
                  NULLKOMMA_R_ALL_CONFIG_NEEDS=${lib.boolToString allConfigNeeds}
                '';
                "${prefix}README.md" = {
                  commentPrefix = "<!--";
                  commentSuffix = " -->";
                  sections.r-development = builtins.readFile ./_assets/development.md;
                };
              };
            };
        })
      ];
    };
}
