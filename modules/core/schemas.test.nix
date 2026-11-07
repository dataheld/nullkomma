{ inputs, ... }:
{
  partitions.dev.module.perSystem =
    {
      harness,
      lib,
      system,
      ...
    }:
    let
      inherit (harness) callFlakeWith nullkomma root;
      fixture = root + "/tests/fixtures/partitioned";
      # Evaluates the partitioned fixture as a flake reading it would, extended by `module`.
      partitioned =
        module:
        (import (fixture + "/flake.nix")).outputs {
          inherit (inputs) nixpkgs;
          nullkomma-schemas = (import (root + "/schemas/flake.nix")).outputs { inherit (inputs) flake-schemas; };
          self.outPath = fixture;
          flake-parts = lib.recursiveUpdate inputs.flake-parts {
            lib.mkFlake =
              args: consumer:
              inputs.flake-parts.lib.mkFlake args {
                imports = [
                  consumer
                  module
                ];
              };
          };
        };
      withExtraInputs = extraInputs: {
        partitions.dev.extraInputs = lib.mkForce extraInputs;
      };
      unevaluated = partitioned (withExtraInputs { nullkomma = throw "evaluated the `dev` partition"; });
      evaluated = partitioned (withExtraInputs { inherit nullkomma; });
      # What Nix reads of a schema to resolve an installable.
      metadata = schema: {
        inherit (schema) version;
        roles = lib.attrNames (schema.roles or { });
        appendSystem = schema.appendSystem or false;
        defaultAttrPath = schema.defaultAttrPath or null;
      };
      runnable = {
        version = 1;
        roles = [ "nix-run" ];
        appendSystem = true;
        defaultAttrPath = [ "default" ];
      };
      namesOf = flake: lib.mapAttrs (output: _: lib.attrNames flake.${output}.${system});
    in
    {
      nullkomma.nix.unit.tests = {
        testPartitionedRootResolvesInstallablesWithoutThePartition = {
          expr = {
            metadata = lib.mapAttrs (_: metadata) {
              inherit (unevaluated.schemas)
                apps
                processTrees
                taskRunners
                tests
                ;
            };
            names = namesOf unevaluated {
              devShells = { };
              processTrees = { };
              taskRunners = { };
            };
          };
          expected = {
            metadata = {
              apps = metadata inputs.flake-schemas.exportedSchemas.apps;
              processTrees = runnable;
              taskRunners = runnable;
              tests = {
                version = 1;
                roles = [ ];
                appendSystem = false;
                defaultAttrPath = null;
              };
            };
            names = {
              devShells = [ "default" ];
              processTrees = [ "dev" ];
              taskRunners = [ "default" ];
            };
          };
        };
        testPartitionedRootReadsItsNamesFromThePartition = {
          expr = {
            shell = lib.isDerivation evaluated.devShells.${system}.default;
            tree = evaluated.processTrees.${system}.dev.processes ? all;
            runner = evaluated.taskRunners.${system}.default.tasks ? all;
            tests = lib.attrNames evaluated.tests.systems;
            inventory = {
              tree = lib.attrNames (evaluated.schemas.processTrees.inventory evaluated.processTrees).children.${system}.children;
              runner = lib.attrNames (evaluated.schemas.taskRunners.inventory evaluated.taskRunners).children.${system}.children;
            };
          };
          expected = {
            shell = true;
            tree = true;
            runner = true;
            tests = lib.attrNames evaluated.tests.systems;
            inventory = {
              tree = [ "dev" ];
              runner = [ "default" ];
            };
          };
        };
        testPartitionedAttrsExposeAllNamesOfAnOutput = {
          expr =
            namesOf
              (partitioned {
                imports = [ (withExtraInputs { inherit nullkomma; }) ];
                partitionedAttrs.processTrees = "dev";
                partitions.dev.module.perSystem.process-compose.other.settings.processes.true.command = "true";
              })
              { processTrees = { }; };
          expected.processTrees = [
            "dev"
            "other"
          ];
        };
        testProjectAddsOwnSchemasNextToNullkommas = {
          expr =
            let
              inherit
                (callFlakeWith {
                  flake.schemas.custom = {
                    version = 1;
                    doc = "custom";
                    inventory = _: { };
                  };
                } (root + "/tests/fixtures/md"))
                schemas
                ;
            in
            {
              custom = schemas.custom.doc;
              processTrees = metadata schemas.processTrees;
              taskRunners = metadata schemas.taskRunners;
              wellKnown = schemas ? apps;
            };
          expected = {
            custom = "custom";
            processTrees = runnable;
            taskRunners = runnable;
            wellKnown = true;
          };
        };
      };
    };
}
