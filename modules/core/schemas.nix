# Consumers inherit output schemas without declaring another input.
{ inputs, ... }:
{
  flake.framework =
    { ... }:
    let
      isModule = m: builtins.isAttrs m || builtins.isFunction m;
    in
    {
      flake.schemas = inputs.flake-schemas.schemas // {
        inherit (inputs.up.exportedSchemas) taskRunners;
        plugins = {
          version = 1;
          doc = "Optional project plugins as [flake-parts](https://flake.parts) modules. nullkomma.lib.mkFlake selects overridable defaults.";
          inventory = output: {
            children = builtins.mapAttrs (_: module: {
              what = "project plugin";
              evalChecks.isModule = isModule module;
            }) output;
          };
        };
        framework = {
          version = 1;
          doc = "Shared nullkomma option and output plumbing.";
          inventory = module: {
            what = "flake-parts module";
            evalChecks.isModule = isModule module;
          };
        };
        lib = {
          version = 1;
          doc = "Nix library: `mkFlake`, `defaults`, `importTree` and `defaultPlugins`.";
          inventory = output: {
            children = builtins.mapAttrs (_: v: {
              what = if builtins.isFunction v then "function" else "library";
            }) output;
          };
        };
      };
    };
}
