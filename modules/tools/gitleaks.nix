{
  plugins.gitleaks =
    { config, lib, ... }:
    {
      config.perSystem = lib.mkIf config.nullkomma.gitleaks.enable (
        { pkgs, ... }:
        {
          nullkomma.tasks.secret-history = {
            description = "Scan Git history for secrets";
            packages = [ pkgs.gitleaks ];
            skip = true;
            command = "gitleaks git --no-banner --redact .";
          };
          treefmt.settings.formatter.gitleaks = {
            command = lib.getExe (
              pkgs.writeShellApplication {
                name = "nullkomma-gitleaks";
                runtimeInputs = [ pkgs.gitleaks ];
                text = ''
                  if [[ -f .gitleaks.toml && -z "''${GITLEAKS_CONFIG:-}" && -z "''${GITLEAKS_CONFIG_TOML:-}" ]]; then
                    export GITLEAKS_CONFIG="$PWD/.gitleaks.toml"
                  fi
                  for file in "$@"; do
                    gitleaks dir --no-banner --no-color --redact --log-level=error "$file"
                  done
                '';
              }
            );
            includes = [ "*" ];
            priority = -2;
          };
        }
      );
    };
}
