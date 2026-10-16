{
  plugins.r =
    { config, lib, ... }:
    {
      config.perSystem = lib.mkIf config.nullkomma.r.enable (
        { config, ... }:
        {
          nullkomma.devHelpers = [ config.nullkomma.r.package ];
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
