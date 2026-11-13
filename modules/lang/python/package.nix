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
      inherit (cfg.pyproject) project;
      name = inputs.pyproject-nix.lib.pypa.normalizePackageName project.name;
      scripts = lib.attrNames (project.scripts or { });
      workspace =
        assert lib.assertMsg (
          cfg.pyproject ? build-system
        ) "nullkomma.python: pyproject.toml needs a [build-system] table, as `uv init --package` writes.";
        assert lib.assertMsg (builtins.pathExists (
          self.outPath + "/uv.lock"
        )) "nullkomma.python: uv.lock is missing; run `nix run .#python-lock`, then `git add uv.lock`.";
        # uv2nix's editable overlay needs a path value, which `self.outPath` is not.
        inputs.uv2nix.lib.workspace.loadWorkspace {
          workspaceRoot = /. + builtins.unsafeDiscardStringContext (toString self.outPath);
        };
    in
    {
      config.perSystem = lib.mkIf cfg.enable (
        { config, pkgs, ... }:
        let
          inherit (config.nullkomma.python) environments interpreter overlay;
          pythonSet =
            (pkgs.callPackage inputs.pyproject-nix.build.packages { python = interpreter; }).overrideScope
              (
                lib.composeManyExtensions [
                  inputs.pyproject-build-systems.overlays.wheel
                  (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
                  overlay
                ]
              );
          editableSet = pythonSet.overrideScope (
            lib.composeManyExtensions [
              (workspace.mkEditablePyprojectOverlay {
                root = "$NULLKOMMA_PYTHON_ROOT";
                members = [ name ];
              })
              (final: prev: {
                ${name} = prev.${name}.overrideAttrs (old: {
                  # Hatchling requests editables dynamically (PEP 660), which Nix builds cannot.
                  nativeBuildInputs = old.nativeBuildInputs ++ final.resolveBuildSystem { editables = [ ]; };
                });
              })
            ]
          );
          # Not workspace.deps.default, which holds `default-groups` and every workspace member.
          venv = pythonSet.mkVirtualEnv "${name}-env" { ${name} = [ ]; };
          # A library has no console scripts, which is all mkApplication keeps.
          runtime =
            if scripts == [ ] then
              venv
            else
              (pkgs.callPackages inputs.pyproject-nix.build.util { }).mkApplication {
                inherit venv;
                package = pythonSet.${name};
              };
          distribution =
            buildType:
            (pythonSet.${name}.override {
              pyprojectHook = pythonSet.pyprojectDistHook;
            }).overrideAttrs
              {
                uvBuildType = buildType;
                uvBuildFlags = "--no-create-gitignore";
              };
        in
        {
          nullkomma.python.environments = {
            runtime = venv;
            development = editableSet.mkVirtualEnv "${name}-dev-env" workspace.deps.all;
            test = pythonSet.mkVirtualEnv "${name}-test-env" workspace.deps.all;
          };
          packages = {
            default = lib.mkDefault runtime;
            dist = pkgs.symlinkJoin {
              name = "${name}-dist";
              paths = map distribution [
                "sdist"
                "wheel"
              ];
              meta.description = "Source distribution and wheel";
            };
          };
          apps = lib.genAttrs scripts (script: {
            program = "${runtime}/bin/${script}";
            meta.description = project.description or "Run ${script}";
          });
          nullkomma.devShell = {
            packages = [ environments.development ];
            shellHook = ''
              unset PYTHONPATH
              export NULLKOMMA_PYTHON_ROOT="$(${lib.getExe pkgs.git} rev-parse --show-toplevel)"
              # A stable path for uv and editors; a real environment there stays the project's.
              [[ -d $NULLKOMMA_PYTHON_ROOT/.venv && ! -L $NULLKOMMA_PYTHON_ROOT/.venv ]] ||
                ln -sfn ${environments.development} "$NULLKOMMA_PYTHON_ROOT/.venv"
            '';
          };
          nullkomma.editor.vscode.extensions = [ "ms-python.python" ];
        }
      );
    };
}
