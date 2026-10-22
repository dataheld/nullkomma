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
                runtimeInputs = [ pkgs.coreutils ];
                text = ''
                  reject_config() {
                    for name in jarl.toml .jarl.toml; do
                      if [[ -f "$1/$name" ]]; then
                        echo "nullkomma: $1/$name is unsupported; configure Jarl in treefmt.settings.formatter.jarl.options" >&2
                        exit 1
                      fi
                    done
                  }
                  # Jarl 0.5 has no explicit-config or isolation flag.
                  for path in "$@"; do
                    if [[ -f "$path" ]]; then
                      directory=$(dirname "$(realpath "$path")")
                      while :; do
                        reject_config "$directory"
                        [[ "$directory" != / ]] || break
                        directory=$(dirname "$directory")
                      done
                    fi
                  done
                  reject_config "''${XDG_CONFIG_HOME:-$HOME/.config}/jarl"
                  reject_config "$HOME/Library/Application Support/jarl"
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
