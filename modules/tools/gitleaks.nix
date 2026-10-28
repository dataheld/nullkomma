{
  plugins.gitleaks =
    { config, lib, ... }:
    {
      config.nullkomma.lint.gitleaks.extend.useDefault = lib.mkIf config.nullkomma.gitleaks.enable (
        lib.mkDefault true
      );
      config.perSystem = lib.mkIf config.nullkomma.gitleaks.enable (
        { pkgs, ... }:
        let
          configFile = (pkgs.formats.toml { }).generate "gitleaks.toml" config.nullkomma.lint.gitleaks;
          flags = "--config ${configFile} --gitleaks-ignore-path ${pkgs.writeText "gitleaksignore" ""}";
        in
        {
          nullkomma.tasks.nk-secret-history = {
            description = "Scan Git history for secrets";
            packages = [ pkgs.gitleaks ];
            skip = true;
            command = "gitleaks git ${flags} --no-banner --redact .";
          };
          treefmt.settings.formatter.gitleaks = {
            command = lib.getExe (
              pkgs.writeShellApplication {
                name = "nullkomma-gitleaks";
                runtimeInputs = [ pkgs.gitleaks ];
                text = ''
                  for file in "$@"; do
                    gitleaks dir ${flags} --no-banner --no-color --redact --log-level=error "$file"
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
