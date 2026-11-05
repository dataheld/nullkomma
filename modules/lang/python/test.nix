{
  plugins.python =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.python;
      python = {
        namespace = "python";
        working_dir = "./${cfg.prefix}";
      };
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
            python-test = python // {
              description = "Run pytest on the editable working tree; --installed tests the installed package";
              command = config.nullkomma.scratch {
                name = "python-test";
                command = pytest;
              };
              watch.paths = [
                {
                  path = ".";
                  exclude = cfg.generated;
                }
              ];
            };
            python-test-coverage = python // {
              description = "Write test coverage to the terminal, coverage.xml and htmlcov with pytest-cov";
              command = ''${lib.getExe pytest} --cov --cov-report=term-missing --cov-report=xml --cov-report=html "$@"'';
              disabled = true;
            };
            check.depends_on.python-test.condition = "process_completed_successfully";
          };
        }
      );
    };
}
