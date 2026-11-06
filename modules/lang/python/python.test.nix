{
  partitions.dev.module.perSystem =
    {
      harness,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (harness)
        fixtures
        perSystem
        summary
        rawAt
        root
        nullkomma
        task
        project
        treefmt
        watching
        ;
      fixture = root + "/tests/fixtures/python";
      cfg = perSystem fixtures.python;
      enabled =
        src:
        rawAt src {
          imports = [ nullkomma.flakeModules.python ];
          nullkomma.python.enable = true;
        };
      stringRoot = enabled "${builtins.path { path = fixture; }}";
      withoutLock = perSystem (
        enabled (
          builtins.path {
            path = fixture;
            filter = path: _: baseNameOf path != "uv.lock";
          }
        )
      );
      scripts = enabled (root + "/tests/fixtures/python-scripts");
      linted = harness.callFlakeWith {
        nullkomma.lint = {
          ruff.lint.ignore = [ "F401" ];
          ty.rules.invalid-return-type = "ignore";
        };
      } fixture;
      customized = harness.callFlakeWith {
        perSystem = { pkgs, ... }: {
          nullkomma.python.test.packages = [ pkgs.hello ];
        };
      } fixture;
      overridden = perSystem (
        harness.callFlakeWith {
          perSystem = { pkgs, ... }: {
            nullkomma.python = {
              interpreter = pkgs.python312;
              overlay = final: prev: {
                nk-example = prev.nk-example.overrideAttrs (old: {
                  postInstall = (old.postInstall or "") + ''
                    echo 'VALUE = 42' > "$out/${final.python.sitePackages}/nk_example/override.py"
                  '';
                });
              };
            };
          };
        } fixture
      );
    in
    {
      nullkomma.nix.unit.tests = {
        testPythonOutputs = {
          expr = {
            apps = lib.attrNames cfg.apps;
            checks = lib.filter (lib.hasPrefix "python-") (summary fixtures.python).checks;
            formatters = lib.filter (lib.hasPrefix "ruff") (lib.attrNames cfg.treefmt.build.programs);
            ignored = lib.elem ".venv" fixtures.python.debug.config.nullkomma.gitignore;
          };
          expected = {
            apps = [
              "default"
              "nk-example"
              "python-lock"
            ];
            checks = [
              "python-lock-check"
              "python-test"
              "python-typecheck"
            ];
            formatters = [
              "ruff-check"
              "ruff-format"
            ];
            ignored = true;
          };
        };
        testPythonStringRoot = {
          expr = lib.isString (perSystem stringRoot).nullkomma.python.environments.development.drvPath;
          expected = true;
        };
        testPythonMinimumVersion = {
          expr = {
            ruff = fixtures.python.debug.config.nullkomma.lint.ruff.target-version;
            ty = fixtures.python.debug.config.nullkomma.lint.ty.environment.python-version;
          };
          expected = {
            ruff = "py310";
            ty = "3.10";
          };
        };
        testPythonMinimumParsing = {
          expr = map (import ../../../lib/python-minimum.nix lib) [
            ">=3.10,<4"
            "<4,>=3.10"
            ">= 3.11"
            "~=3.11.0"
            ">3.9"
            "==3.12.*"
            "<=3.12"
            ""
          ];
          expected = [
            "3.10"
            "3.10"
            "3.11"
            "3.11"
            "3.9"
            "3.12"
            null
            null
          ];
        };
        testPythonRequiresLock = {
          expr = withoutLock.packages.default.drvPath;
          expectedError.msg = "uv.lock is missing";
        };
        testPythonLockBootstrapsWithoutLock = {
          expr = lib.isString withoutLock.apps.python-lock.program;
          expected = true;
        };
        testPythonRequiresBuildSystem = {
          expr = (perSystem scripts).packages.default.drvPath;
          expectedError.msg = "needs a .build-system. table";
        };
        testPythonTwoScriptsWithoutMinimum =
          let
            inherit (scripts.debug.config.nullkomma.lint) ruff ty;
          in
          {
            expr = {
              apps = lib.attrNames (perSystem scripts).apps;
              ruff = ruff ? target-version;
              ty = ty ? environment && ty.environment ? python-version;
            };
            expected = {
              apps = [
                "first"
                "python-lock"
                "second"
              ];
              ruff = false;
              ty = false;
            };
          };
        testPythonIntelConsumer = {
          expr =
            (builtins.tryEval (
              (harness.callFlakeWith {
                systems = lib.mkForce [ "x86_64-darwin" ];
              } fixture).checks.x86_64-darwin.python-test.drvPath
            )).success;
          expected = true;
        };
      };
      checks.python-runtime = pkgs.runCommand "python-runtime" { } ''
        ${cfg.apps.default.program} | grep -Fx 'Hello from Python'
        test ! -e ${cfg.packages.default}/bin/python
        ${cfg.nullkomma.python.environments.runtime}/bin/python -c 'import click; import importlib.util; assert importlib.util.find_spec("pytest") is None'
        touch "$out"
      '';
      checks.python-overrides = pkgs.runCommand "python-overrides" { } ''
        ${overridden.nullkomma.python.environments.runtime}/bin/python -c 'import sys; from nk_example.override import VALUE; assert sys.version_info[:2] == (3, 12); assert VALUE == 42'
        ${project fixture}
        ${overridden.apps.python-lock.program} --check --offline 2>&1 | grep -F ${overridden.nullkomma.python.interpreter.interpreter}
        touch "$out"
      '';
      checks.python-working-tree = pkgs.runCommand "python-working-tree" { } ''
        ${project fixture}
        mkdir "$TMPDIR/inherited"
        echo 'raise ImportError("PYTHONPATH reached Python")' > "$TMPDIR/inherited/nk_example.py"
        echo 'def command(): raise ImportError("PYTHONPATH reached ty")' > "$TMPDIR/inherited/click.py"
        export PYTHONPATH="$TMPDIR/inherited"
        ${task fixtures.python "python-test"}
        ${task fixtures.python "python-typecheck"}
        substituteInPlace src/nk_example/__init__.py --replace-fail 'Hello from Python' 'Edited source'
        substituteInPlace tests/test_example.py --replace-fail 'Hello from Python' 'Edited source'
        ${task fixtures.python "python-test"}
        printf '\n[tool.pytest.ini_options]\npythonpath = ["src"]\n' >> pyproject.toml
        fails "AssertionError" ${task fixtures.python "python-test"} --installed tests/test_example.py::test_greeting
        ${task fixtures.python "python-test"} --installed -k test_console_script
        mv src/nk_example nk_example
        touch tests/__init__.py
        fails "AssertionError" ${task fixtures.python "python-test"} --installed tests/test_example.py::test_greeting
        rm tests/__init__.py
        mv nk_example src/nk_example
        echo 'def test_failure(): assert False' > tests/test_failure.py
        fails "FAILED" ${task fixtures.python "python-test"}
        ${task fixtures.python "python-test"} tests/test_example.py
        rm tests/test_failure.py
        touch "$out"
      '';
      checks.python-lock = pkgs.runCommand "python-lock" { } ''
        ${project fixture}
        # Without dependencies, uv resolves the project with no network.
        printf '[project]\nname = "nk_example"\nversion = "0.1.0"\nrequires-python = ">=3.10"\n' > pyproject.toml
        fails "needs to be updated" ${task fixtures.python "python-lock-check"}
        ${cfg.apps.python-lock.program} --offline
        ${task fixtures.python "python-lock-check"}
        touch "$out"
      '';
      checks.python-dev-shell =
        let
          inherit (cfg.nullkomma) devShell editor;
        in
        pkgs.runCommand "python-dev-shell" (devShell.env // { nativeBuildInputs = devShell.packages; }) ''
          ${project fixture}
          mkdir "$TMPDIR/inherited"
          echo 'raise ImportError("PYTHONPATH reached Python")' > "$TMPDIR/inherited/nk_example.py"
          export PYTHONPATH="$TMPDIR/inherited"
          ${devShell.shellHook}
          substituteInPlace src/nk_example/__init__.py --replace-fail 'Hello from Python' 'Edited source'
          test "$(python -c 'from nk_example import greeting; print(greeting())')" = 'Edited source'
          ${editor.vscode.settings."python.defaultInterpreterPath"} -c 'import pytest'
          ${
            lib.head editor.vscode.settings."ty.path"
          } check --config-file ${editor.languageServers.ty.settings.ty.configurationFile}
          uv run --offline python -c pass
          touch "$out"
        '';
      checks.python-dev-loop = pkgs.runCommand "python-dev-loop" { } ''
        ${project fixture}
        ${watching fixtures.python "python-test"}
        settled python-test 1
        test ! -e .pytest_cache
        mkdir .ruff_cache
        touch .ruff_cache/generated
        settled python-test 1
        printf '\n' >> src/nk_example/__init__.py
        settled python-test 2
        touch "$out"
      '';
      checks.python-dist = pkgs.runCommand "python-dist" { } ''
        test -f ${cfg.packages.dist}/nk_example-0.1.0.tar.gz
        test -f ${cfg.packages.dist}/nk_example-0.1.0-py3-none-any.whl
        touch "$out"
      '';
      checks.python-test-customization = pkgs.runCommand "python-test-customization" { } ''
        ${project fixture}
        cat > tests/test_environment.py <<'PY'
        import subprocess

        def test_environment():
            subprocess.run(["git", "--version"], check=True)
        PY
        ${task customized "python-test"}
        touch "$out"
      '';
      checks.python-lint = pkgs.runCommand "python-lint" { } ''
        ${project fixture}
        ${treefmt linted}
        printf '[lint]\nignore = ["I"]\n' > ruff.toml
        printf 'import sys\nimport os\n' > src/nk_example/unsorted.py
        format src/nk_example/unsorted.py
        printf 'import os\nimport sys\n' | diff - src/nk_example/unsorted.py
        mkdir -p "$HOME/.config/ty"
        printf '[rules]\ninvalid-assignment = "ignore"\n' | tee ty.toml > "$HOME/.config/ty/ty.toml"
        printf 'def broken() -> int:\n    return "wrong"\n\n\nvalue: int = "wrong"\n' > src/nk_example/broken.py
        fails "invalid-assignment" ${task linted "python-typecheck"}
        if grep -qF invalid-return-type "$TMPDIR/failure.log"; then exit 1; fi
        ${task linted "python-typecheck"} tests
        touch "$out"
      '';
    };
}
