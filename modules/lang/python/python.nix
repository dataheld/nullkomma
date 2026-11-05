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
        dependencyGroups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = lib.optional (pyproject.dependency-groups or { } ? dev) "dev";
          defaultText = lib.literalMD "`[ \"dev\" ]` when that dependency group exists, otherwise `[]`";
          description = "Dependency groups from uv.lock included in development and tests, never the runtime package.";
        };
        test = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Run pytest from the selected dependency groups.";
          };
          coverage.enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Use pytest-cov from the selected groups to report terminal, XML and HTML coverage; configure coverage sources in pyproject.toml. No threshold or upload.";
          };
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
            test = {
              packages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
                description = "Extra commands available to pytest, for example pkgs.git.";
              };
              environment = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = { };
                description = "Environment variables for pytest; sandbox checks also provide a writable private HOME.";
              };
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
            devDeps = {
              ${name} = cfg.dependencyGroups;
            };
            editableSet = pythonSet.overrideScope (
              lib.composeManyExtensions [
                (workspace.mkEditablePyprojectOverlay {
                  root = "$NULLKOMMA_PYTHON_ROOT";
                  members = [ name ];
                })
                (
                  final: prev:
                  lib.optionalAttrs (pyproject.build-system.build-backend or "" == "hatchling.build") {
                    ${name} = prev.${name}.overrideAttrs (old: {
                      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { editables = [ ]; };
                    });
                  }
                )
              ]
            );
            runtime = pythonSet.mkVirtualEnv "${name}-env" { ${name} = [ ]; };
            development = editableSet.mkVirtualEnv "${name}-dev-env" devDeps;
            testEnvironment = pythonSet.mkVirtualEnv "${name}-test-env" devDeps;
            buildEnvironment = pythonSet.mkVirtualEnv "${name}-build-env" (
              lib.listToAttrs (
                map (requirement: {
                  inherit (requirement) name;
                  value = requirement.extras;
                }) (inputs.pyproject-nix.lib.pep518.parseBuildSystems pyproject)
              )
            );
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
              if [[ "''${1:-}" == "--installed" ]]; then
                shift
                python=(${testEnvironment}/bin/python -I)
                options=(--import-mode=importlib -o pythonpath=)
              else
                python=(${development}/bin/python)
                options=()
              fi
              exec "''${python[@]}" -m pytest "''${options[@]}" ${lib.optionalString cfg.test.coverage.enable "--cov --cov-report=term-missing --cov-report=xml --cov-report=html"} "$@"
            '';
            build = command "python-build" [ pkgs.uv ] ''
              exec uv build --offline --no-build-isolation \
                --python ${buildEnvironment}/bin/python "$@"
            '';
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
              dist = config.nullkomma.sandbox {
                process = "python-build";
                output = "${prefix}dist";
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
              lib.mkForce (
                config.nullkomma.sandbox {
                  process = "python-test";
                  args = [ "--installed" ];
                }
              )
            );
            process-compose.dev.settings.processes = {
              python-lock = process "Resolve pyproject.toml into uv.lock" [ ] "" // {
                command = lock;
              };
              python-lock-check = process "Check uv.lock without changing it or accessing the network" [
                pkgs.uv
              ] ''exec uv lock --check --offline "$@"'';
              python-test = lib.mkIf cfg.test.enable (
                process "Run pytest on source locally and the installed package in sandbox checks" [ ] ""
                // {
                  command = config.nullkomma.scratch {
                    name = "python-test";
                    command = test;
                    outputs = [
                      "coverage.xml"
                      "htmlcov"
                    ];
                  };
                  environment = pcfg.test.environment;
                  disabled = false;
                  watch.paths = [
                    {
                      path = ".";
                      exclude = generated;
                    }
                  ];
                }
              );
              python-build = process "Build the source distribution and a wheel from it" [ ] "" // {
                command = build;
              };
              python-check-dist =
                process "Check distribution metadata and install the wheel offline"
                  [ pkgs.uv pkgs.python3Packages.twine ]
                  ''
                    twine check --strict dist/*
                    destination="$(mktemp -d)"
                    trap 'rm -rf "$destination"' EXIT
                    uv pip install --python ${pcfg.interpreter.interpreter} \
                      --target "$destination" --no-deps --offline dist/*.whl
                    cd "$destination"
                    PYTHONPATH="$destination" ${runtime}/bin/python ${./_check-dist.py} ${lib.escapeShellArg name}
                  ''
                // {
                  depends_on.python-build.condition = "process_completed_successfully";
                };
              check.depends_on =
                lib.genAttrs
                  [
                    "python-lock-check"
                    "python-check-dist"
                  ]
                  (_: {
                    condition = "process_completed_successfully";
                  })
                // lib.optionalAttrs cfg.test.enable {
                  python-test.condition = "process_completed_successfully";
                };
            };
          };
      };
    };
}
