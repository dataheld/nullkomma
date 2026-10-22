# Consumers inherit output schemas without declaring another input.
{ inputs, ... }:
{
  framework =
    { lib, ... }:
    let
      isModule = m: builtins.isAttrs m || builtins.isFunction m;
    in
    {
      options.flake = lib.mkOption {
        type = lib.types.submoduleWith {
          modules = [
            {
              options.schemas = lib.mkOption {
                type = lib.types.lazyAttrsOf lib.types.raw;
                default = { };
                description = "[Flake schemas](https://github.com/DeterminateSystems/flake-schemas) describing this flake's outputs; add your own next to nullkomma's.";
              };
            }
          ];
        };
      };
      config.flake.schemas = inputs.flake-schemas.schemas // {
        inherit (inputs.up.exportedSchemas) taskRunners;
        flakeModules = {
          version = 1;
          doc = "[flake-parts](https://flake.parts) modules for other flakes; `default` is the framework with all plugins and the default ones enabled.";
          inventory = output: {
            children = builtins.mapAttrs (_: module: {
              what = "flake-parts module";
              evalChecks.isModule = isModule module;
            }) output;
          };
        };
        flakeModule = {
          version = 1;
          doc = "Alias of `flakeModules.default`, kept by flake-parts for older consumers.";
          inventory = module: {
            what = "flake-parts module";
            evalChecks.isModule = isModule module;
          };
        };
        modules = {
          version = 1;
          doc = "Modules by [class](https://nixos.org/manual/nixpkgs/stable/#module-system-lib-evalModules-param-class), e.g. `modules.flake` for flake-parts.";
          inventory = output: {
            children = builtins.mapAttrs (class: modules: {
              children = builtins.mapAttrs (_: module: {
                what = if class == "flake" then "flake-parts module" else "${class} module";
                evalChecks.isModule = isModule module;
              }) modules;
            }) output;
          };
        };
        lib = {
          version = 1;
          doc = "Nix library: `mkFlake` and `defaultPlugins`.";
          inventory = output: {
            children = builtins.mapAttrs (_: v: {
              what = if builtins.isFunction v then "function" else "library";
            }) output;
          };
        };
      };
    };
}
