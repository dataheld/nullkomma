# Consumers inherit output schemas without declaring another input.
{ inputs, ... }:
{
  flake.plugins.base =
    { ... }:
    let
      isModule = m: builtins.isAttrs m || builtins.isFunction m;
      children = what: output: {
        children = builtins.mapAttrs (_: _: { inherit what; }) output;
      };
    in
    {
      flake.schemas = inputs.flake-schemas.schemas // {
        editor = {
          version = 1;
          doc = "Project editor settings and extension IDs for workspace files or managed editor profiles.";
          inventory = children "project editor integration";
        };
        plugins = {
          version = 1;
          doc = "Project plugins as [flake-parts](https://flake.parts) modules; import them into `nullkomma.lib.mkFlake`. The base plugin is imported automatically.";
          inventory = output: {
            children = builtins.mapAttrs (_: module: {
              what = "project plugin";
              evalChecks.isModule = isModule module;
            }) output;
          };
        };
        lib = {
          version = 1;
          doc = "Nix library: `mkFlake` and `importTree`.";
          inventory = output: {
            children = builtins.mapAttrs (_: v: {
              what = if builtins.isFunction v then "function" else "library";
            }) output;
          };
        };
      };
    };
}
