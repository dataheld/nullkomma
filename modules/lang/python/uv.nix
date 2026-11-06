{
  plugins.python =
    { config, lib, ... }:
    {
      config.perSystem = lib.mkIf config.nullkomma.python.enable (
        { config, pkgs, ... }:
        let
          env = {
            UV_PYTHON = config.nullkomma.python.interpreter.interpreter;
            UV_PYTHON_DOWNLOADS = "never";
            UV_NO_SYNC = "1";
          };
          description = "Resolve pyproject.toml into uv.lock";
          lock = pkgs.writeShellApplication {
            name = "python-lock";
            runtimeInputs = [ pkgs.uv ];
            runtimeEnv = env;
            text = ''exec uv lock "$@"'';
          };
        in
        {
          nullkomma.devShell = {
            packages = [ pkgs.uv ];
            inherit env;
          };
          apps.python-lock = {
            program = lib.getExe lock;
            meta.description = description;
          };
          process-compose.dev.settings.processes = {
            python-lock = {
              namespace = "python";
              inherit description;
              command = lock;
              disabled = true;
            };
            python-lock-check = {
              namespace = "python";
              description = "Check uv.lock without changing it or accessing the network";
              command = pkgs.writeShellApplication {
                name = "python-lock-check";
                text = ''
                  ${lib.getExe lock} --check --offline "$@" || {
                    echo "uv.lock does not match pyproject.toml, or uv cannot read it; run nk python-lock." >&2
                    exit 1
                  }
                '';
              };
              watch.paths = map (path: { inherit path; }) [
                "pyproject.toml"
                "uv.lock"
              ];
            };
            check.depends_on.python-lock-check.condition = "process_completed_successfully";
          };
        }
      );
    };
}
