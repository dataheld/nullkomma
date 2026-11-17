# nullkomma's own building blocks, published as flake-parts modules
# (https://flake.parts/options/flake-parts-flakeModules): `flakeModules.<plugin>`,
# `flakeModules.framework` and `flakeModules.default`, also as `modules.flake.*`.
# `framework` and `plugins` are internal to this flake; several files can contribute to one.
{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [ inputs.flake-parts.flakeModules.flakeModules ];
  options.framework = lib.mkOption {
    type = lib.types.deferredModule;
    default = { };
    description = "Shared nullkomma option and output plumbing, without plugin selection; exported as `flakeModules.framework`.";
  };
  options.plugins = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    apply = lib.mapAttrs (
      name: module: {
        imports = [ module ];
        options.nullkomma.${name}.enable = lib.mkEnableOption "the ${name} plugin";
      }
    );
    description = "Optional project plugins, each switched by `nullkomma.<name>.enable`; exported as `flakeModules.<name>`.";
  };
  config.flake.flakeModules = config.plugins // {
    inherit (config) framework;
  };
}
