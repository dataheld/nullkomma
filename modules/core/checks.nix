# `nk-check` runs the checks, the processes it depends on;
# each also runs sandboxed as `checks.<system>.<name>`.
# `all` also formats; plugins add to either with `depends_on`.
{
  framework.perSystem =
    { config, lib, ... }:
    let
      inherit (config.process-compose.dev.settings) processes;
      task = description: {
        namespace = "nullkomma";
        inherit description;
        command = "true";
        disabled = true;
      };
    in
    {
      process-compose.dev.settings.processes = {
        nk-check = task "Run all checks";
        all = task "Format and run all checks" // {
          depends_on.nk-check.condition = "process_completed_successfully";
        };
      };
      checks = lib.mapAttrs (name: _: lib.mkDefault (config.nullkomma.sandbox { process = name; })) (
        lib.defaultTo { } processes.nk-check.depends_on
      );
    };
}
