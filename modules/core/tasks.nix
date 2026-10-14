# Named tasks become `apps.<name>` (`nix run .#<name>`); `nix run` lists them.
{
  flake.framework =
    { flake-parts-lib, lib, ... }:
    let
      taskModule = {
        options = {
          description = lib.mkOption {
            type = lib.types.str;
            description = "One-line description, shown by `nix run`.";
          };
          command = lib.mkOption {
            type = lib.types.lines;
            description = "Bash script (checked by shellcheck); arguments are in `$@`.";
          };
          runtimeInputs = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            description = "Packages on `PATH` while the task runs.";
          };
        };
      };
    in
    {
      options.perSystem = flake-parts-lib.mkPerSystemOption {
        options.nullkomma.tasks = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule taskModule);
          default = { };
          description = "Project tasks (the Makefile replacement), exposed as `apps.<name>`.";
        };
      };
      config.perSystem =
        { config, pkgs, ... }:
        let
          cfg = config.nullkomma.tasks;
          toApp = name: task: {
            type = "app";
            program = lib.getExe (
              pkgs.writeShellApplication {
                inherit name;
                inherit (task) runtimeInputs;
                text = task.command;
              }
            );
            meta.description = task.description;
          };
          width = lib.foldl' lib.max 0 (map lib.stringLength (lib.attrNames cfg)) + 2;
          pad = s: s + lib.concatStrings (lib.genList (_: " ") (width - lib.stringLength s));
          help = pkgs.writeShellApplication {
            name = "nullkomma-help";
            text = ''
              cat <<'EOF'
              Tasks (nix run .#<task>):
              ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: t: "  ${pad n}${t.description}") cfg)}

              Also: nix develop, nix fmt, nix flake check, nix flake show
              EOF
            '';
          };
        in
        {
          config = {
            apps = lib.mapAttrs toApp cfg // {
              default = lib.mkDefault {
                type = "app";
                program = lib.getExe help;
                meta.description = "List nullkomma tasks";
              };
            };
          };
        };
    };
}
