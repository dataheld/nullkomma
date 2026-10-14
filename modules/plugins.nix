# Several files can contribute to one importable plugin.
{ lib, moduleLocation, ... }:
{
  options.flake.framework = lib.mkOption {
    type = lib.types.deferredModule;
    default = { };
    description = "Shared nullkomma option and output plumbing, without plugin selection.";
  };
  options.flake.plugins = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    apply = lib.mapAttrs (
      name: module: {
        _file = "${toString moduleLocation}#plugins.${name}";
        key = "${toString moduleLocation}#plugins.${name}";
        _class = "flake";
        imports = [ module ];
        options.nullkomma.${name}.enable = lib.mkEnableOption "the ${name} plugin";
      }
    );
    description = "Optional project plugins, each switched by `nullkomma.<name>.enable`; nullkomma.lib.mkFlake selects overridable defaults.";
  };
}
