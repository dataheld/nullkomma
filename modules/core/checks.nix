# `check` runs the checks, the processes it depends on;
# each also runs sandboxed as `checks.<system>.<name>`.
# `all` also formats, builds and runs checks that cannot be sandboxed;
# add to either with `depends_on`.
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
        check = task "Run the checks that `nix flake check` also runs";
        all = task "Format, build and run every check" // {
          depends_on.check.condition = "process_completed_successfully";
        };
        flake-check =
          task "Run every check sandboxed, on Git-tracked files, as CI does; args go to `nix flake check`"
          // {
            # Uses the project's own `nix`, which may differ from Nixpkgs'.
            command = ''nix flake check "$@"'';
          };
      };
      checks = lib.mapAttrs (name: _: lib.mkDefault (config.nullkomma.sandbox { process = name; })) (
        lib.defaultTo { } processes.check.depends_on
      );
    };
}
