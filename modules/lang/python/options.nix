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
      internal =
        description: default:
        lib.mkOption {
          type = lib.types.raw;
          internal = true;
          readOnly = true;
          inherit default description;
        };
    in
    {
      options.nullkomma.python = {
        pyproject = internal "The flake's `pyproject.toml`." (
          lib.importTOML (self.outPath + "/pyproject.toml")
        );
        minimum = internal "Lower bound of `requires-python` as `major.minor`; null without one." (
          lib.mapNullable lib.head (
            builtins.match ".*>= *([0-9]+\\.[0-9]+).*" (cfg.pyproject.project.requires-python or "")
          )
        );
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
              description = "pyproject.nix overlay for native libraries and package build fixes, applied after uv.lock.";
            };
            environments = lib.mkOption {
              type = lib.types.lazyAttrsOf lib.types.package;
              internal = true;
              description = "Virtual environments: `runtime`, without dependency groups, `development`, editable, and `test`, with the installed package; the last two have every group.";
            };
            test.packages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = "Extra commands available to pytest, for example pkgs.git.";
            };
          };
        }
      );
    };
}
