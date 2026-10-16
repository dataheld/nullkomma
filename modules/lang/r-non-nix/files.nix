{ config, inputs, ... }:
let
  rModule = config.flake.flakeModules.r;
in
{
  plugins.r-non-nix =
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
      rlib = import ../../../lib/r-non-nix.nix { inherit lib; };
      readme = cfg.root + "/README.md";
      buildignore = cfg.root + "/.Rbuildignore";
      existingBuildignore = if builtins.pathExists buildignore then builtins.readFile buildignore else "";
      buildignoreLines = lib.splitString "\n" existingBuildignore;
      buildignoreRules = lib.filter (line: line != "") (
        lib.splitString "\n" (builtins.readFile ./_assets/Rbuildignore)
        ++ [ "^${lib.escapeRegex (lib.removePrefix "${toString cfg.root}/" (toString cfg.lockfile))}$" ]
      );
    in
    {
      imports = [
        rModule
        (lib.mkRenamedOptionModule
          [ "nullkomma" "r" "nonNix" "enable" ]
          [ "nullkomma" "r-non-nix" "enable" ]
        )
        (lib.mkRenamedOptionModule
          [ "nullkomma" "r" "rprofile" "enable" ]
          [ "nullkomma" "r-non-nix" "enable" ]
        )
      ];
      config = lib.mkIf config.nullkomma.r-non-nix.enable {
        nullkomma.r.enable = true;
        nullkomma.gitignore = [ "${prefix}.R/library/" ];
        perSystem =
          { system, ... }:
          {
            nullkomma.files = {
              ${profile}.text = builtins.readFile ./_assets/profile.R;
              "${prefix}.R/install.R".text = builtins.readFile ./_assets/install.R;
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
              "${prefix}.Rbuildignore" = {
                initialSource = if builtins.pathExists buildignore then buildignore else null;
                text =
                  existingBuildignore
                  + lib.optionalString (existingBuildignore != "" && !lib.hasSuffix "\n" existingBuildignore) "\n"
                  + lib.concatMapStrings (rule: lib.optionalString (!(lib.elem rule buildignoreLines)) "${rule}\n") (
                    lib.unique buildignoreRules
                  );
              };
            };
          };
      };
    };
}
