{ inputs, ... }:
{
  plugins.r =
    {
      config,
      lib,
      options,
      self,
      ...
    }:
    let
      cfg = config.nullkomma.r;
      relativeRoot = lib.removePrefix "${toString self}/" (toString cfg.root);
      profile = if toString cfg.root == toString self then ".Rprofile" else "${relativeRoot}/.Rprofile";
      prefix = if toString cfg.root == toString self then "" else "${relativeRoot}/";
      rlib = import ../../../lib/r.nix { inherit lib; };
      readme = cfg.root + "/README.md";
    in
    {
      config.nullkomma.gitignore = lib.mkIf (cfg.enable && cfg.nonNix.enable) [ "${prefix}.R/library/" ];
      config.perSystem = lib.mkIf cfg.enable (
        { system, ... }:
        {
          nullkomma.files = lib.mkIf cfg.nonNix.enable {
            ${profile}.text = builtins.readFile ./_non-nix/profile.R;
            "${prefix}.Renviron".text = ''
              NULLKOMMA_R_VERSION=${builtins.toJSON inputs.nixpkgs-r.legacyPackages.${system}.R.version}
              NULLKOMMA_PPM_SNAPSHOT=${builtins.toJSON cfg.snapshot}
              NULLKOMMA_PPM_URL=${builtins.toJSON cfg.ppmUrl}
              NULLKOMMA_R_DEPENDENCIES=${builtins.toJSON (lib.concatStringsSep "," cfg.fields)}
              NULLKOMMA_R_ALL_CONFIG_NEEDS=${
                if options.nullkomma.r.fields.highestPrio == 1500 then "true" else "false"
              }
            '';
            "${prefix}README.md" = {
              initialSource = if builtins.pathExists readme then readme else null;
              text = rlib.withNonNixDocumentation (
                if builtins.pathExists readme then builtins.readFile readme else ""
              );
            };
          };
          nullkomma.devshell.shellHook = ''
            if [ -z "''${R_LIBS_USER:-}" ]; then
              export R_LIBS_USER="''${XDG_DATA_HOME:-$HOME/.local/share}/nullkomma/R/$(Rscript --vanilla -e 'cat(as.character(getRversion()))')"
            fi
            mkdir -p "$R_LIBS_USER"
          '';
        }
      );
    };
}
