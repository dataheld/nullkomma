{ config, inputs, ... }:
let
  rModule = config.flake.flakeModules.r;
in
{
  plugins.r-non-nix =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
      inherit (cfg) prefix;
      rlib = import ../../../lib/r-non-nix.nix { inherit lib; };
      readme = cfg.root + "/README.md";
      description = cfg.root + "/DESCRIPTION";
      # Native R then follows Config/Needs fields added to DESCRIPTION later, as Nix does.
      allConfigNeeds = lib.all (field: lib.elem field cfg.fields) (
        lib.optionals (builtins.pathExists description) (
          (import ../../../lib/r.nix { inherit lib; }).configNeedsFields (builtins.readFile description)
        )
      );
    in
    {
      imports = [ rModule ];
      config = lib.mkIf config.nullkomma.r-non-nix.enable {
        nullkomma.r.enable = true;
        nullkomma.gitignore = [ "${prefix}.R/library/" ];
        perSystem =
          { system, ... }:
          {
            nullkomma.files = {
              "${prefix}.Rprofile".text = builtins.readFile ./_assets/profile.R;
              "${prefix}.R/install.R".text = builtins.readFile ./_assets/install.R;
              "${prefix}.Renviron".text = ''
                NULLKOMMA_R_VERSION=${builtins.toJSON inputs.nixpkgs-r.legacyPackages.${system}.R.version}
                NULLKOMMA_PPM_SNAPSHOT=${builtins.toJSON cfg.snapshot}
                NULLKOMMA_PPM_URL=${builtins.toJSON cfg.ppmUrl}
                NULLKOMMA_R_DEPENDENCIES=${builtins.toJSON (lib.concatStringsSep "," cfg.fields)}
                NULLKOMMA_R_ALL_CONFIG_NEEDS=${lib.boolToString allConfigNeeds}
              '';
              "${prefix}README.md" = {
                initialSource = if builtins.pathExists readme then readme else null;
                text = rlib.withNonNixDocumentation (
                  if builtins.pathExists readme then builtins.readFile readme else ""
                );
              };
            };
          };
      };
    };
}
