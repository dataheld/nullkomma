# Several files can contribute to one importable plugin.
{ lib, moduleLocation, ... }:
{
  options.flake.plugins = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    apply = lib.mapAttrs (
      name: module: {
        _file = "${toString moduleLocation}#plugins.${name}";
        key = "${toString moduleLocation}#plugins.${name}";
        _class = "flake";
        imports = [ module ];
      }
    );
    description = "Composable project plugins; import into nullkomma.lib.mkFlake. The base plugin is imported automatically.";
  };
}
