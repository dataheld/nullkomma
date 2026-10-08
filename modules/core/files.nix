# Initialize repository files once; existing files belong to the user.
{
  flake.flakeModules.default =
    { lib, ... }:
    {
      perSystem =
        { config, pkgs, ... }:
        let
          files = lib.filterAttrs (_: f: f.enable) config.nullkomma.files;
          fileModule =
            { name, config, ... }:
            {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to initialize `${name}` if absent.";
                };
                text = lib.mkOption {
                  type = lib.types.nullOr lib.types.lines;
                  default = null;
                  description = "File content; sets `source`.";
                };
                source = lib.mkOption {
                  type = lib.types.path;
                  description = "Store path whose content is written to `${name}`.";
                };
              };
              config.source = lib.mkIf (config.text != null) (
                pkgs.writeText "nullkomma-${lib.replaceStrings [ "/" ] [ "-" ] name}" config.text
              );
            };
        in
        {
          options.nullkomma.files = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule fileModule);
            default = { };
            description = "Files, keyed by path relative to the repo root, that nullkomma initializes if absent. Existing files are never overwritten or checked for drift.";
          };
          config = {
            nullkomma.tasks.write-files = {
              description = "Initialize missing repository files (.gitignore, .envrc, CI stubs, …), preserving existing files";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.git
              ];
              command = ''
                root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
              ''
              + lib.concatStrings (
                lib.mapAttrsToList (path: f: ''
                  target="$root"/${lib.escapeShellArg path}
                  if [ -e "$target" ] || [ -L "$target" ]; then
                    echo "kept ${path}"
                  else
                    mkdir -p "$(dirname "$target")"
                    cp --no-clobber ${f.source} "$target"
                    chmod u+w "$target"
                    echo "initialized ${path}"
                  fi
                '') files
              );
            };
          };
        };
    };
}
