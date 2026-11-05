{ inputs, ... }:
{
  plugins.python =
    {
      config,
      lib,
      self,
      ...
    }:
    let
      cfg = config.nullkomma.python;
      prefix = import ../../../lib/prefix.nix lib self cfg.root;
      lint = config.nullkomma.lint;
      pyproject = lib.importTOML (cfg.root + "/pyproject.toml");
      bounds = lib.filter (
        condition:
        lib.elem condition.op [
          ">="
          ">"
          "~="
          "=="
          "==="
        ]
      ) (inputs.pyproject-nix.lib.pep440.parseVersionConds (pyproject.project.requires-python or ""));
      minimum = lib.foldl' (
        version: condition:
        let
          release = map (part: if part == "*" then "0" else toString part) condition.version.release;
          bound = lib.concatStringsSep "." (lib.take 2 release);
        in
        if lib.versionOlder version bound then bound else version
      ) "3.7" bounds;
    in
    {
      config = lib.mkIf cfg.enable {
        nullkomma.lint.ruff.lint.extend-select = lib.mkDefault [ "I" ];
        nullkomma.lint.ruff.target-version = lib.mkDefault "py${lib.replaceStrings [ "." ] [ "" ] minimum}";
        nullkomma.lint.ty.environment.python-version = lib.mkDefault minimum;
        perSystem =
          { config, pkgs, ... }:
          let
            pcfg = config.nullkomma.python;
            toml = pkgs.formats.toml { };
            ruffConfig = toml.generate "ruff.toml" lint.ruff;
            tyConfig = toml.generate "ty.toml" lint.ty;
            checker = pkgs.writeShellApplication {
              name = "ty";
              runtimeInputs = [ pkgs.git ];
              runtimeEnv.TY_CONFIG_FILE = toString tyConfig;
              text = ''
                if [[ ! -v NULLKOMMA_PYTHON_ROOT ]]; then
                  NULLKOMMA_PYTHON_ROOT="$(git rev-parse --show-toplevel)/${prefix}"
                  export NULLKOMMA_PYTHON_ROOT
                fi
                exec ${lib.getExe pkgs.ty} "$@"
              '';
            };
          in
          {
            treefmt = {
              programs.ruff-check.enable = lib.mkDefault true;
              programs.ruff-format.enable = lib.mkDefault true;
              settings.formatter = {
                ruff-check.options = [
                  "--config"
                  (toString ruffConfig)
                ];
                ruff-format.options = [
                  "--config"
                  (toString ruffConfig)
                ];
              };
            };
            nullkomma.devShell.packages = [ pkgs.ruff ];
            nullkomma.editor = {
              languageServers.ty = {
                package = checker;
                command = [
                  "ty"
                  "server"
                ];
                filetypes = [ "python" ];
                settings.ty = {
                  configurationFile = toString tyConfig;
                  configuration.environment.python = "${pcfg.devEnvironment}/bin/python";
                };
              };
              vscode = {
                extensions = [
                  "ms-python.python"
                  "astral-sh.ty"
                ];
                settings = {
                  "python.defaultInterpreterPath" = lib.mkDefault "${pcfg.devEnvironment}/bin/python";
                  "ty.path" = [ (lib.getExe checker) ];
                  "ty.configurationFile" = toString tyConfig;
                  "ty.configuration".environment.python = "${pcfg.devEnvironment}/bin/python";
                };
              };
            };
            process-compose.dev.settings.processes = {
              python-typecheck = {
                namespace = "python";
                description = "Check Python types with ty";
                working_dir = "./${prefix}";
                command = pkgs.writeShellApplication {
                  name = "python-typecheck";
                  text = ''
                    unset PYTHONPATH
                    export NULLKOMMA_PYTHON_ROOT="$PWD"
                    exec ${lib.getExe checker} check --python ${pcfg.devEnvironment} "$@"
                  '';
                };
                watch.paths = [
                  {
                    path = ".";
                    include = [
                      "*.py"
                      "*.pyi"
                      "pyproject.toml"
                      "uv.lock"
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
