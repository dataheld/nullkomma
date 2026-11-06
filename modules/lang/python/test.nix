{
  plugins.python =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.python;
    in
    {
      config.perSystem = lib.mkIf (cfg.enable && cfg.test.enable) (
        { config, pkgs, ... }:
        let
          inherit (config.nullkomma.python) environments test;
          pytest = pkgs.writeShellApplication {
            name = "python-test";
            runtimeInputs = test.packages;
            text = ''
              unset PYTHONPATH
              if [[ "''${1-}" == --installed ]]; then
                shift
                PATH="${environments.test}/bin:$PATH"
                exec python -I -m pytest --import-mode=importlib -o pythonpath= "$@"
              fi
              export NULLKOMMA_PYTHON_ROOT="$PWD"
              PATH="${environments.development}/bin:$PATH"
              exec python -m pytest "$@"
            '';
          };
        in
        {
          checks.python-test = config.nullkomma.sandbox {
            process = "python-test";
            args = [ "--installed" ];
          };
          process-compose.dev.settings.processes = {
            python-test = {
              namespace = "python";
              description = "Run pytest on the editable working tree; --installed tests the installed package";
              command = config.nullkomma.scratch {
                name = "python-test";
                command = pytest;
              };
              watch.paths = [
                {
                  path = ".";
                  exclude = config.treefmt.settings.excludes;
                }
              ];
            };
            check.depends_on.python-test.condition = "process_completed_successfully";
          };
        }
      );
    };
}
