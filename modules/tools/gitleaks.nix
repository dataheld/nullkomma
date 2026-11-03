{
  plugins.gitleaks =
    { config, lib, ... }:
    {
      config = lib.mkIf config.nullkomma.gitleaks.enable {
        nullkomma.lint.gitleaks.extend.useDefault = lib.mkDefault true;
        perSystem =
          { pkgs, ... }:
          let
            configFile = (pkgs.formats.toml { }).generate "gitleaks.toml" config.nullkomma.lint.gitleaks;
            flags = "--config ${configFile} --gitleaks-ignore-path ${pkgs.writeText "gitleaksignore" ""}";
          in
          {
            process-compose.dev.settings.processes = {
              gitleaks-git = {
                namespace = "gitleaks";
                description = "Scan Git history for secrets; treefmt scans the files";
                command = "${lib.getExe pkgs.gitleaks} git ${flags} --no-banner --redact .";
                disabled = true;
              };
              all.depends_on.gitleaks-git.condition = "process_completed_successfully";
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
          };
      };
    };
}
