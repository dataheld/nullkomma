{
  plugins.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
    in
    {
      options.nullkomma.r.jarl.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Lint and auto-fix R code with jarl. Configure its CLI switches through perSystem.treefmt.settings.formatter.jarl.options; native config files are unsupported.";
      };
      config.perSystem = lib.mkIf cfg.enable (
        { pkgs, ... }:
        {
          treefmt.programs.air.enable = lib.mkDefault true;
          treefmt.settings.formatter.jarl = lib.mkIf cfg.jarl.enable {
            command = lib.getExe (
              pkgs.writeShellApplication {
                name = "nullkomma-jarl";
                # Jarl 0.5 cannot ignore config files, so refuse the project's and the user's.
                # shortcut: nested ones (e.g. R/jarl.toml) still apply; check every parent if that bites.
                text = ''
                  for config in {.,"''${XDG_CONFIG_HOME:-$HOME/.config}/jarl","$HOME/Library/Application Support/jarl"}/{,.}jarl.toml; do
                    if [[ -f "$config" ]]; then
                      echo "nullkomma: $config is unsupported; configure Jarl in treefmt.settings.formatter.jarl.options" >&2
                      exit 1
                    fi
                  done
                  exec ${
                    lib.getExe (
                      # shortcut: nixpkgs' jarl tests fail on Darwin; drop once Hydra builds it.
                      if pkgs.stdenv.hostPlatform.isDarwin then
                        pkgs.jarl.overrideAttrs { doCheck = false; }
                      else
                        pkgs.jarl
                    )
                  } "$@"
                '';
              }
            );
            options = [
              "check"
              "--fix"
              "--allow-dirty"
              "--allow-no-vcs"
              "--output-format=concise"
            ];
            includes = [
              "*.R"
              "*.r"
            ];
            # fix lints first, then let air format the result
            priority = -1;
          };
        }
      );
    };
}
