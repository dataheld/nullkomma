{
  plugins.python =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.python;
      inherit (config.nullkomma.lint) ty;
    in
    {
      config = lib.mkIf cfg.enable {
        # ty infers it from requires-python only without --config-file.
        nullkomma.lint.ty.environment.python-version = lib.mkIf (cfg.minimum != null) (
          lib.mkDefault cfg.minimum
        );
        perSystem =
          { config, pkgs, ... }:
          let
            settings = (pkgs.formats.toml { }).generate "ty.toml" (
              lib.recursiveUpdate {
                environment.python = toString config.nullkomma.python.environments.development;
              } ty
            );
            # ty merges the user's ty.toml even with --config-file.
            isolated = pkgs.writeShellApplication {
              name = "ty";
              runtimeEnv.XDG_CONFIG_HOME = "/var/empty";
              text = ''
                unset PYTHONPATH
                exec ${lib.getExe pkgs.ty} "$@"
              '';
            };
          in
          {
            nullkomma.editor = {
              languageServers.ty = {
                package = isolated;
                command = [
                  "ty"
                  "server"
                ];
                filetypes = [ "python" ];
                settings.ty.configurationFile = toString settings;
              };
              vscode = {
                extensions = [ "astral-sh.ty" ];
                settings = lib.mapAttrs (_: lib.mkDefault) {
                  "ty.path" = [ (lib.getExe isolated) ];
                  "ty.configurationFile" = toString settings;
                };
              };
            };
            process-compose.dev.settings.processes = {
              python-typecheck = {
                namespace = "python";
                description = "Check Python types with ty";
                command = "${lib.getExe isolated} check --config-file ${settings}";
                watch.paths = [
                  {
                    path = ".";
                    include = [
                      "*.py"
                      "*.pyi"
                    ];
                  }
                ];
              };
              check.depends_on.python-typecheck.condition = "process_completed_successfully";
            };
          };
      };
    };
}
