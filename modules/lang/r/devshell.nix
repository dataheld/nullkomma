{
  plugins.r =
    { config, lib, ... }:
    {
      config.perSystem = lib.mkIf config.nullkomma.r.enable (
        { config, pkgs, ... }:
        let
          r = config.nullkomma.r.package;
        in
        {
          # Interactive sessions start quietly from a clean slate; `R CMD` must stay the first argument.
          nullkomma.devHelpers = [
            (pkgs.symlinkJoin {
              name = "R-interactive";
              paths = [ r ];
              postBuild = ''
                ln -sf ${pkgs.writeShellScript "R" ''
                  if [ "''${1:-}" = CMD ]; then exec ${r}/bin/R "$@"; fi
                  exec ${r}/bin/R --quiet --no-save --no-restore "$@"
                ''} "$out/bin/R"
              '';
            })
          ];
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
