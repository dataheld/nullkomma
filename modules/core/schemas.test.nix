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
      # The partitioned fixture's root, with `extraInputs` in its `dev` partition.
      partitioned =
        extraInputs:
        inputs.flake-parts.lib.mkFlake
          {
            inputs = {
              inherit (inputs) flake-parts nixpkgs;
              nullkomma-schemas = (import (root + "/schemas/flake.nix")).outputs { inherit (inputs) flake-schemas; };
              self.outPath = fixture;
            };
          }
          (
            { config, ... }:
            {
              imports = [ (fixture + "/root.nix") ];
              partitions.dev = { inherit extraInputs; };
              flake.schemasInPartition = config.partitions.dev.module.flake.schemas;
            }
          );
      evaluated = partitioned { inherit nullkomma; };
      childrenOf = output: lib.attrNames (evaluated.schemas.${output}.inventory evaluated.${output}).children.${system}.children;
    in
    {
      nullkomma.nix.unit.tests = {
        testPartitionedRootHasSchemasWithoutItsPartition = {
          expr =
            let
              inherit (partitioned { nullkomma = throw "evaluated the `dev` partition"; }) schemas;
            in
            lib.mapAttrs (_: schema: schema.version) { inherit (schemas) apps processTrees taskRunners tests; };
          expected = {
            apps = 1;
            processTrees = 1;
            taskRunners = 1;
            tests = 1;
          };
        };
        testPartitionedRootDescribesItsPartitionsOutputs = {
          expr = {
            processTrees = childrenOf "processTrees";
            taskRunners = childrenOf "taskRunners";
            tests = (evaluated.schemas.tests.inventory evaluated.tests).children.systems.children ? ${system};
            same = evaluated.schemasInPartition.tests.doc == evaluated.schemas.tests.doc;
          };
          expected = {
            processTrees = [ "dev" ];
            taskRunners = [ "default" ];
            tests = true;
            same = true;
          };
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
              inherit (schemas.custom) doc;
              nullkommas = schemas ? taskRunners && schemas ? tests;
              wellKnown = schemas ? apps;
            };
          expected = {
            doc = "custom";
            nullkommas = true;
            wellKnown = true;
          };
        };
      };
    };
}
