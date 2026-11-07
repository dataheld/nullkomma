# A flake's `schemas` replaces Nix's default ones, so this set includes them.
flake-schemas:
let
  isModule = m: builtins.isAttrs m || builtins.isFunction m;
  # Without the `nix-run` role of `up`'s schemas: `nix run .#name` evaluates every output
  # with that role, and a flake that others consume keeps these in its partition.
  derivationsWith = doc: childrenOf: {
    version = 1;
    inherit doc;
    inventory = output: {
      children = builtins.mapAttrs (system: items: {
        forSystems = [ system ];
        children = builtins.mapAttrs (_: item: {
          forSystems = [ system ];
          evalChecks.isDerivation = item.type or null == "derivation";
          children = builtins.mapAttrs (_: child: { forSystems = [ system ]; } // child) (childrenOf item);
        }) items;
      }) output;
    };
  };
in
flake-schemas.exportedSchemas
// {
  processTrees =
    derivationsWith "[process-compose](https://github.com/F1bonacc1/process-compose) trees."
      (
        tree:
        builtins.mapAttrs (_: process: {
          what = if process.description != null then process.description else "process";
          shortDescription = if process.command != null then process.command else "";
        }) (tree.processes or { })
      );
  taskRunners = derivationsWith "Task runners, with their tasks in `tasks`." (
    runner:
    builtins.mapAttrs (_: task: {
      what = task.description or "task runner";
    }) (runner.tasks or { })
  );
  tests = {
    version = 1;
    doc = "[nix-unit](https://github.com/nix-community/nix-unit) tests by system, run by `checks.<system>.nix-unit`.";
    inventory = output: {
      children.systems.children = builtins.mapAttrs (system: _: {
        what = "nix-unit test suite";
        forSystems = [ system ];
      }) output.systems;
    };
  };
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
}
