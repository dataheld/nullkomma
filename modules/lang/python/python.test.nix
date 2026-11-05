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
        imports = [
          nullkomma.flakeModules.python
          nullkomma.flakeModules.neovim
        ];
        nullkomma.python.enable = true;
        nullkomma.neovim.enable = true;
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
          nullkomma.python.test = {
            packages = [ pkgs.git ];
            environment.NULLKOMMA_PYTHON_TEST = "configured";
          };
        };
      } fixture;
      nested = rawAt root {
        imports = [ nullkomma.flakeModules.python ];
        nullkomma.python = {
          enable = true;
          root = fixture;
        };
      };
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
            lsp = cfg.nullkomma.editor.languageServers.ty.command;
            formatters = lib.filter (lib.hasPrefix "ruff") (lib.attrNames cfg.treefmt.build.programs);
          };
          expected = {
            apps = [
              "default"
              "nk-example"
              "python-lock"
            ];
            tasks = [
              "python-build"
              "python-check-dist"
              "python-lock"
              "python-lock-check"
              "python-test"
              "python-typecheck"
            ];
            lsp = [
              "ty"
              "server"
            ];
            formatters = [
              "ruff-check"
              "ruff-format"
            ];
          };
        };
        testPythonStringRoot = {
          expr = builtins.stringLength (perSystem stringRoot).nullkomma.files.".nvim.lua".text > 0;
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
          expr = (builtins.tryEval bootstrap.packages.default.drvPath).success;
          expected = false;
        };
        testPythonNestedRoot = {
          expr = (perSystem nested).process-compose.dev.settings.processes.python-typecheck.working_dir;
          expected = "./tests/fixtures/python/";
        };
        testPythonEditorEnvironment = {
          expr = {
            neovim = cfg.nullkomma.editor.languageServers.ty.settings.ty.configuration.environment.python;
            vscode = cfg.nullkomma.editor.vscode.settings."ty.configuration".environment.python;
          };
          expected = {
            neovim = "${cfg.nullkomma.python.devEnvironment}/bin/python";
            vscode = "${cfg.nullkomma.python.devEnvironment}/bin/python";
          };
        };
      };
      checks.python-runtime = pkgs.runCommand "python-runtime" { } ''
        ${cfg.packages.default}/bin/nk-example | grep -Fx 'Hello from Python'
        ${cfg.packages.default}/bin/python -c 'import click; import importlib.util; assert importlib.util.find_spec("pytest") is None'
        touch "$out"
      '';
      checks.python-working-tree = pkgs.runCommand "python-working-tree" { } ''
        ${project fixture}
        export PYTHONPATH=/nonexistent-inherited-pythonpath
        ${task fixtures.python "python-test"}
        test -f coverage.xml
        test -f htmlcov/index.html
        mv src src-hidden
        ${task fixtures.python "python-test"} --installed
        mv src-hidden src
        substituteInPlace src/nk_example/__init__.py --replace-fail 'Hello from Python' 'Edited source'
        substituteInPlace tests/test_example.py --replace-fail 'Hello from Python' 'Edited source'
        ${task fixtures.python "python-test"}
        substituteInPlace pyproject.toml --replace-fail '[tool.pytest.ini_options]' $'[tool.pytest.ini_options]\npythonpath = ["src"]'
        fails "AssertionError" ${task fixtures.python "python-test"} --installed
        echo 'def broken() -> int: return "wrong"' > src/nk_example/broken.py
        printf '[rules]\ninvalid-return-type = "ignore"\n' > ty.toml
        fails "invalid-return-type" ${task fixtures.python "python-typecheck"}
        rm src/nk_example/broken.py
        echo 'def test_failure(): assert False' > tests/test_failure.py
        fails "FAILED" ${task fixtures.python "python-test"} tests/test_failure.py
        rm tests/test_failure.py
        ${task fixtures.python "python-test"} tests/test_example.py
        substituteInPlace pyproject.toml --replace-fail 'click>=8' 'click>=999'
        fails "lock" ${task fixtures.python "python-lock-check"}
        touch "$out"
      '';
      checks.python-bootstrap = pkgs.runCommand "python-bootstrap" { } ''
        ${project withoutLock}
        ${bootstrap.apps.python-lock.program} --help >/dev/null
        test ! -f uv.lock
        touch "$out"
      '';
      checks.python-distribution-install = pkgs.runCommand "python-distribution-install" { } ''
        ${project fixture}
        ${task fixtures.python "python-check-dist"}
        test -f dist/nk_example-0.1.0.tar.gz
        test -f dist/nk_example-0.1.0-py3-none-any.whl
        substituteInPlace src/nk_example/__init__.py --replace-fail 'def main(' 'def absent('
        fails "AttributeError" ${task fixtures.python "python-check-dist"}
        touch "$out"
      '';
      checks.python-test-customization = pkgs.runCommand "python-test-customization" { } ''
        ${project fixture}
        cat > tests/test_environment.py <<'PY'
        import os
        import pathlib
        import subprocess

        def test_environment():
            assert os.environ["NULLKOMMA_PYTHON_TEST"] == "configured"
            subprocess.run(["git", "--version"], check=True)
            (pathlib.Path.home() / "writable-home").touch()
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
