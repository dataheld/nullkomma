# Flake schemas (DeterminateSystems/flake-schemas) make `nix flake show` and
# `nix flake check` understand nullkomma's non-standard outputs.
{
  partitions.dev.module =
    { inputs, ... }:
    let
      isModule = m: builtins.isAttrs m || builtins.isFunction m;
      children = what: output: {
        children = builtins.mapAttrs (_: _: { inherit what; }) output;
      };
    in
    {
      flake.schemas = inputs.flake-schemas.schemas // {
        flakeModules = {
          version = 1;
          doc = "Aspects as [flake-parts](https://flake.parts) modules; import them into `nullkomma.lib.mkFlake`.";
          inventory = output: {
            children = builtins.mapAttrs (_: module: {
              what = "flake-parts module";
              evalChecks.isModule = isModule module;
            }) output;
          };
        };
        flakeModule = {
          version = 1;
          doc = "Alias of `flakeModules.default`.";
          inventory = module: {
            what = "flake-parts module";
            evalChecks.isModule = isModule module;
          };
        };
        modules = {
          version = 1;
          doc = "Modules by class (`modules.<class>.<name>`), as defined by flake-parts.";
          inventory = output: {
            children = builtins.mapAttrs (class: children "${class} module") output;
          };
        };
        lib = {
          version = 1;
          doc = "Nix library: `mkFlake`, `importTree` and pure helpers per language.";
          inventory = output: {
            children = builtins.mapAttrs (_: v: {
              what = if builtins.isFunction v then "function" else "library";
            }) output;
          };
        };
      };
    };
}
