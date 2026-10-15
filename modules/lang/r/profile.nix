{
  plugins.r =
    {
      config,
      lib,
      self,
      ...
    }:
    let
      cfg = config.nullkomma.r;
      relativeRoot = lib.removePrefix "${toString self}/" (toString cfg.root);
      profile = if toString cfg.root == toString self then ".Rprofile" else "${relativeRoot}/.Rprofile";
    in
    {
      config.perSystem = lib.mkIf cfg.enable {
        nullkomma.files = lib.mkIf cfg.rprofile.enable {
          ${profile}.text = ''
            options(repos = c(CRAN = ${builtins.toJSON cfg.ppmUrl}))
          '';
        };
        nullkomma.devshell.shellHook = ''
          if [ -z "''${R_LIBS_USER:-}" ]; then
            export R_LIBS_USER="''${XDG_DATA_HOME:-$HOME/.local/share}/nullkomma/R/$(Rscript --vanilla -e 'cat(as.character(getRversion()))')"
          fi
          mkdir -p "$R_LIBS_USER"
        '';
      };
    };
}
