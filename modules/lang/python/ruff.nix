{
  plugins.python =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.python;
      inherit (config.nullkomma.lint) ruff;
    in
    {
      config = lib.mkIf cfg.enable {
        nullkomma.lint.ruff = {
          lint.extend-select = lib.mkDefault [ "I" ];
          # Ruff infers it from requires-python only without --config.
          target-version = lib.mkIf (cfg.minimum != null) (
            lib.mkDefault "py${lib.replaceStrings [ "." ] [ "" ] cfg.minimum}"
          );
        };
        perSystem =
          { config, pkgs, ... }:
          let
            programs = [
              "ruff-check"
              "ruff-format"
            ];
            options = [
              "--config"
              (toString ((pkgs.formats.toml { }).generate "ruff.toml" ruff))
            ];
          in
          {
            treefmt = {
              programs = lib.genAttrs programs (_: {
                enable = lib.mkDefault true;
              });
              settings.formatter = lib.genAttrs programs (
                name: lib.mkIf config.treefmt.programs.${name}.enable { inherit options; }
              );
            };
          };
      };
    };
}
