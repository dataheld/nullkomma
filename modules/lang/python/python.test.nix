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
        ;
      fixture = root + "/tests/fixtures/python";
      cfg = perSystem fixtures.python;
      disabled = rawAt (root + "/tests/fixtures/md") {
        imports = [ nullkomma.flakeModules.python ];
      };
      stringRoot = rawAt "${builtins.path { path = fixture; }}" {
        imports = [ nullkomma.flakeModules.python ];
        nullkomma.python.enable = true;
      };
      withoutLock = builtins.path {
        path = fixture;
        filter = path: _: baseNameOf path != "uv.lock";
      };
      bootstrap = perSystem (
        rawAt withoutLock {
          imports = [ nullkomma.flakeModules.python ];
          nullkomma.python.enable = true;
        }
      );
      customized = harness.callFlakeWith {
        perSystem = { pkgs, ... }: {
          nullkomma.python.test.packages = [ pkgs.git ];
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
        testPythonDisabled = {
          expr = summary disabled == summary (rawAt (root + "/tests/fixtures/md") { });
          expected = true;
        };
        testPythonOutputs = {
          expr = {
            apps = lib.attrNames cfg.apps;
            tasks = lib.filter (lib.hasPrefix "python-") (lib.attrNames cfg.taskRunners.default.tasks);
            formatters = lib.filter (lib.hasPrefix "ruff") (lib.attrNames cfg.treefmt.build.programs);
          };
          expected = {
            apps = [
              "default"
              "nk-example"
              "python-lock"
            ];
            tasks = [
              "python-lock"
              "python-lock-check"
              "python-test"
              "python-typecheck"
            ];
            formatters = [
              "ruff-check"
              "ruff-format"
            ];
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
        testPythonMissingLock = {
          expr = {
            package = (builtins.tryEval bootstrap.packages.default.drvPath).success;
            lock = (builtins.tryEval bootstrap.apps.python-lock.program).success;
          };
          expected = {
            package = false;
            lock = true;
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
        ${cfg.packages.default}/bin/nk-example | grep -Fx 'Hello from Python'
        ${cfg.packages.default}/bin/python -c 'import click; import importlib.util; assert importlib.util.find_spec("pytest") is None'
        touch "$out"
      '';
      checks.python-overrides = pkgs.runCommand "python-overrides" { } ''
        ${overridden.packages.default}/bin/python -c 'import sys; from nk_example.override import VALUE; assert sys.version_info[:2] == (3, 12); assert VALUE == 42'
        ${overridden.packages.default}/bin/nk-example | grep -Fx 'Hello from Python'
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
        echo 'def broken() -> int: return "wrong"' > src/nk_example/broken.py
        printf '[rules]\ninvalid-return-type = "ignore"\n' > ty.toml
        fails "invalid-return-type" ${task fixtures.python "python-typecheck"}
        rm src/nk_example/broken.py
        echo 'def test_failure(): assert False' > tests/test_failure.py
        fails "FAILED" ${task fixtures.python "python-test"}
        ${task fixtures.python "python-test"} tests/test_example.py
        rm tests/test_failure.py
        substituteInPlace pyproject.toml --replace-fail 'click>=8' 'click>=999'
        fails "lock" ${task fixtures.python "python-lock-check"}
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
        ${treefmt fixtures.python}
        printf '[lint]\nignore = ["F401"]\n' > ruff.toml
        echo 'import os' > src/nk_example/unused.py
        format src/nk_example/unused.py
        test ! -s src/nk_example/unused.py
        touch "$out"
      '';
    };
}
