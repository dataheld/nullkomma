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
          { pkgs, ... }:
          let
            options = [
              "--config"
              (toString ((pkgs.formats.toml { }).generate "ruff.toml" ruff))
            ];
          in
          {
            treefmt = {
              programs.ruff-check.enable = lib.mkDefault true;
              programs.ruff-format.enable = lib.mkDefault true;
              settings.formatter = {
                ruff-check = { inherit options; };
                ruff-format = { inherit options; };
              };
            };
          };
      };
    };
}
