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
                  # Editable builds read metadata and find packages, so module edits need no rebuild.
                  # Dynamic metadata can read any file.
                  src = builtins.path {
                    path = old.src;
                    name = "source";
                    filter =
                      path: type:
                      project ? dynamic
                      || type == "directory"
                      || dirOf path == toString old.src
                      || baseNameOf path == "__init__.py";
                  };
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
              { uvBuildType = buildType; };
          app = script: {
            program = "${runtime}/bin/${script}";
            meta.description = project.description or "Run ${script}";
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
            };
          };
          apps =
            lib.genAttrs scripts app
            // lib.optionalAttrs (lib.length scripts == 1) {
              default = lib.mkDefault (app (lib.head scripts));
            };
          nullkomma.devShell = {
            packages = [ environments.development ];
            shellHook = ''
              unset PYTHONPATH
              export NULLKOMMA_PYTHON_ROOT="$(${lib.getExe pkgs.git} rev-parse --show-toplevel)"
            '';
          };
          nullkomma.editor.vscode = {
            extensions = [ "ms-python.python" ];
            settings."python.defaultInterpreterPath" = lib.mkDefault "${environments.development}/bin/python";
          };
        }
      );
    };
}
