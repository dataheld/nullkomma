{ inputs, ... }:
{
  plugins.python =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.python;
      name = inputs.pyproject-nix.lib.pypa.normalizePackageName cfg.project.name;
      scripts = lib.attrNames (cfg.project.scripts or { });
      workspace =
        assert lib.assertMsg (builtins.pathExists (
          cfg.root + "/uv.lock"
        )) "nullkomma.python: uv.lock is missing; run `nix run .#python-lock`, then `git add uv.lock`.";
        # uv2nix's editable overlay needs a path value, which `self.outPath` is not.
        inputs.uv2nix.lib.workspace.loadWorkspace {
          workspaceRoot = /. + builtins.unsafeDiscardStringContext (toString cfg.root);
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
          distribution =
            buildType:
            (pythonSet.${name}.override {
              pyprojectHook = pythonSet.pyprojectDistHook;
            }).overrideAttrs
              { env.uvBuildType = buildType; };
          app = script: {
            program = "${runtime}/bin/${script}";
            meta.description = cfg.project.description or "Run ${script}";
          };
        in
        {
          nullkomma.python.environments = {
            development = editableSet.mkVirtualEnv "${name}-dev-env" workspace.deps.all;
            test = pythonSet.mkVirtualEnv "${name}-test-env" workspace.deps.all;
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
            lib.genAttrs scripts app
            // lib.optionalAttrs (lib.length scripts == 1) {
              default = lib.mkDefault (app (lib.head scripts));
            };
          nullkomma.devShell = {
            packages = [ environments.development ];
            shellHook = ''
              unset PYTHONPATH
              export NULLKOMMA_PYTHON_ROOT="$(${lib.getExe pkgs.git} rev-parse --show-toplevel)/${cfg.prefix}"
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
