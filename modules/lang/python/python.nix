{ inputs, ... }:
{
  plugins.python =
    {
      config,
      flake-parts-lib,
      lib,
      self,
      ...
    }:
    let
      cfg = config.nullkomma.python;
      prefix = import ../../../lib/prefix.nix lib self cfg.root;
      pyproject =
        if builtins.pathExists (cfg.root + "/pyproject.toml") then
          lib.importTOML (cfg.root + "/pyproject.toml")
        else
          throw "nullkomma.python: pyproject.toml is missing; Python projects must be packages.";
      project = pyproject.project or (throw "nullkomma.python: pyproject.toml needs a [project] table.");
      name = inputs.pyproject-nix.lib.pypa.normalizePackageName project.name;
      workspace =
        if builtins.pathExists (cfg.root + "/uv.lock") then
          inputs.uv2nix.lib.workspace.loadWorkspace { workspaceRoot = cfg.root; }
        else
          throw "nullkomma.python: uv.lock is missing; run `nix run .#python-lock` and git add uv.lock.";
      generated = [
        ".venv/**"
        "__pycache__/**"
        "**/__pycache__/**"
        ".pytest_cache/**"
        ".ruff_cache/**"
        ".coverage"
        "coverage.xml"
        "htmlcov/**"
        "dist/**"
        "*.egg-info/**"
      ];
    in
    {
      options.nullkomma.python = {
        root = lib.mkOption {
          type = lib.types.path;
          default = self.outPath;
          apply = path: /. + builtins.unsafeDiscardStringContext (toString path);
          defaultText = lib.literalExpression "self.outPath";
          description = "Python package directory containing project-owned `pyproject.toml` and `uv.lock`.";
        };
        test.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Run pytest, which a dependency group must provide, with `python-test`: on the editable working tree in the dev loop and `check`, on the installed package in nix flake check (or with `nk python-test --installed`).";
        };
      };
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { pkgs, ... }:
        {
          options.nullkomma.python = {
            interpreter = lib.mkOption {
              type = lib.types.package;
              default = pkgs.python3;
              defaultText = lib.literalExpression "pkgs.python3";
              description = "Nix Python interpreter; must satisfy the project's requires-python.";
            };
            overlay = lib.mkOption {
              type = lib.types.raw;
              default = _: _: { };
              defaultText = lib.literalExpression "final: prev: {}";
              description = "Scoped pyproject.nix overlay for native libraries and package build fixes, applied after uv.lock.";
            };
            environment = lib.mkOption {
              type = lib.types.package;
              readOnly = true;
              description = "Non-editable runtime virtual environment, without development groups.";
            };
            devEnvironment = lib.mkOption {
              type = lib.types.package;
              readOnly = true;
              description = "Editable development virtual environment with the selected dependency groups.";
            };
            test.packages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = "Extra commands available to pytest, for example pkgs.git.";
            };
          };
        }
      );
      config = lib.mkIf cfg.enable {
        nullkomma.generatedPaths = map (path: prefix + path) generated;
        nullkomma.gitignore =
          map (path: "/${prefix}${path}") [
            ".venv/"
            ".pytest_cache/"
            ".ruff_cache/"
            ".coverage"
            "coverage.xml"
            "htmlcov/"
            "dist/"
          ]
          ++ [
            "__pycache__/"
            "*.py[cod]"
            "*.egg-info/"
          ];
        perSystem =
          { config, pkgs, ... }:
          let
            pcfg = config.nullkomma.python;
            pythonSet =
              (pkgs.callPackage inputs.pyproject-nix.build.packages {
                python = pcfg.interpreter;
              }).overrideScope
                (
                  lib.composeManyExtensions [
                    inputs.pyproject-build-systems.overlays.wheel
                    (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
                    pcfg.overlay
                  ]
                );
            editableSet = pythonSet.overrideScope (
              lib.composeManyExtensions [
                (workspace.mkEditablePyprojectOverlay { root = "$NULLKOMMA_PYTHON_ROOT"; })
                # Hatchling requests editables dynamically (PEP 660), which Nix builds cannot.
                (final: prev: {
                  ${name} = prev.${name}.overrideAttrs (old: {
                    nativeBuildInputs = old.nativeBuildInputs ++ final.resolveBuildSystem { editables = [ ]; };
                  });
                })
              ]
            );
            runtime = pythonSet.mkVirtualEnv "${name}-env" workspace.deps.default;
            development = editableSet.mkVirtualEnv "${name}-dev-env" workspace.deps.all;
            testEnvironment = pythonSet.mkVirtualEnv "${name}-test-env" workspace.deps.all;
            uvEnv = {
              UV_PYTHON = pcfg.interpreter.interpreter;
              UV_PYTHON_DOWNLOADS = "never";
              UV_NO_SYNC = "1";
            };
            command =
              taskName: tools: text:
              pkgs.writeShellApplication {
                name = taskName;
                runtimeInputs = tools;
                runtimeEnv = uvEnv;
                text = ''
                  unset PYTHONPATH
                  export NULLKOMMA_PYTHON_ROOT="$PWD"
                ''
                + text;
              };
            process = description: tools: text: {
              namespace = "python";
              working_dir = "./${prefix}";
              inherit description;
              command = command "python-task" tools text;
              disabled = true;
            };
            lock = command "python-lock" [ pkgs.uv ] ''
              cd "$(${lib.getExe pkgs.git} rev-parse --show-toplevel)/${prefix}"
              exec uv lock "$@"
            '';
            scripts = project.scripts or { };
            scriptNames = lib.attrNames scripts;
            apps = lib.mapAttrs (script: _: {
              type = "app";
              program = "${runtime}/bin/${script}";
              meta.description = project.description or "Run ${script}";
            }) scripts;
            test = command "python-test" pcfg.test.packages ''
              if [[ "''${1-}" == --installed ]]; then
                shift
                PATH="${testEnvironment}/bin:$PATH"
                exec python -I -m pytest --import-mode=importlib -o pythonpath= "$@"
              fi
              PATH="${development}/bin:$PATH"
              exec python -m pytest "$@"
            '';
            distribution =
              buildType:
              (pythonSet.${name}.override {
                pyprojectHook = pythonSet.pyprojectDistHook;
              }).overrideAttrs
                { env.uvBuildType = buildType; };
          in
          {
            nullkomma.python = {
              environment = runtime;
              devEnvironment = development;
            };
            nullkomma.devShell = {
              packages = [
                development
                pkgs.uv
              ];
              env = uvEnv;
              shellHook = ''
                unset PYTHONPATH
                export NULLKOMMA_PYTHON_ROOT="$(${lib.getExe pkgs.git} rev-parse --show-toplevel)/${prefix}"
              '';
            };
            packages = {
              ${name} = runtime;
              default = lib.mkDefault runtime;
              dist = pkgs.symlinkJoin {
                name = "${name}-dist";
                paths = map distribution [
                  "sdist"
                  "wheel"
                ];
              };
            };
            apps =
              apps
              // lib.optionalAttrs (lib.length scriptNames == 1) {
                default = lib.mkDefault apps.${lib.head scriptNames};
              }
              // {
                python-lock = {
                  type = "app";
                  program = lib.getExe lock;
                  meta.description = "Resolve pyproject.toml into uv.lock";
                };
              };
            checks.python-test = lib.mkIf cfg.test.enable (
              config.nullkomma.sandbox {
                process = "python-test";
                args = [ "--installed" ];
              }
            );
            process-compose.dev.settings.processes = {
              python-lock = process "Resolve pyproject.toml into uv.lock" [ ] "" // {
                command = lock;
              };
              python-lock-check = process "Check uv.lock without changing it or accessing the network" [
                pkgs.uv
              ] ''exec uv lock --check --offline "$@"'';
              python-test = lib.mkIf cfg.test.enable (
                process "Run pytest on the editable working tree; --installed tests the installed package" [ ] ""
                // {
                  command = config.nullkomma.scratch {
                    name = "python-test";
                    command = test;
                  };
                  disabled = false;
                  watch.paths = [
                    {
                      path = ".";
                      exclude = generated;
                    }
                  ];
                }
              );
              python-test-coverage = lib.mkIf cfg.test.enable (
                process "Write test coverage to the terminal, coverage.xml and htmlcov with pytest-cov" [ ] ""
                // {
                  command = ''${lib.getExe test} --cov --cov-report=term-missing --cov-report=xml --cov-report=html "$@"'';
                }
              );
              check.depends_on = {
                python-lock-check.condition = "process_completed_successfully";
              }
              // lib.optionalAttrs cfg.test.enable {
                python-test.condition = "process_completed_successfully";
              };
            };
          };
      };
    };
}
