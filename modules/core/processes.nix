# Tasks and services are processes of process-compose-flake's `dev` tree:
# plugins and external modules declare them with its options alone,
# one `namespace` each.
# Processes with a `description` are tasks, shown by `nk`.
# Bare `process-compose up` and `nix run .#dev` start the enabled ones;
# set `disabled = true` on actions that should only run when asked for.
# `up <name>` also starts the disabled processes that `<name>` depends on.
{ inputs, ... }:
let
  # One process-compose server per checkout, without a TCP port.
  socket = pkgs: ''
    export PC_SOCKET_PATH="''${PC_SOCKET_PATH:-''${XDG_RUNTIME_DIR:-/tmp}/nk-$(${pkgs.coreutils}/bin/id -u)-$(pwd | ${pkgs.coreutils}/bin/cksum | ${pkgs.coreutils}/bin/cut -d' ' -f1).sock}"
  '';
in
{
  framework =
    { flake-parts-lib, lib, ... }:
    {
      imports = [
        inputs.process-compose-flake.flakeModule
        (inputs.flake-parts.lib.mkTransposedPerSystemModule {
          name = "processTrees";
          option = lib.mkOption {
            type = lib.types.lazyAttrsOf lib.types.package;
            default = { };
            description = "[process-compose-flake](https://github.com/Platonic-Systems/process-compose-flake) trees, exported as `processTrees.<system>`.";
          };
          file = ./processes.nix;
        })
      ];
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { pkgs, ... }:
        {
          options.process-compose = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submoduleWith {
                modules = [
                  {
                    # MCP tools (`mcp`) and file watches (`watch`) are newer than
                    # process-compose-flake's typed options.
                    defaults.processSettings.freeformType = (pkgs.formats.json { }).type;
                    # shortcut: pin process-compose for MCP and watches;
                    # drop once Nixpkgs catches up, see
                    # https://github.com/dataheld/nullkomma/issues/306.
                    package = lib.mkDefault (
                      (pkgs.process-compose.override { buildGoModule = pkgs.buildGo127Module; }).overrideAttrs (old: {
                        version = "1.124.0";
                        src = pkgs.fetchFromGitHub {
                          owner = "F1bonacc1";
                          repo = "process-compose";
                          tag = "v1.124.0";
                          hash = "sha256-o7uTJqEj0rI2xHGsTmK+wdmL/Z1jNokSSRDAesNbL1Y=";
                          leaveDotGit = true;
                          postFetch = old.src.postFetch or "";
                        };
                        vendorHash = "sha256-Je5L5/Yrss/mfwMty0PdWZChTIue24u447zGConInAA=";
                        # shortcut: make watch roots absolute for a relative working_dir;
                        # drop once process-compose does, see
                        # https://github.com/dataheld/nullkomma/issues/384.
                        patches = (old.patches or [ ]) ++ [ ../../patches/process-compose.patch ];
                      })
                    );
                    cli.preHook = ''
                      cd "$(${lib.getExe pkgs.git} rev-parse --show-toplevel)"
                    ''
                    + socket pkgs;
                    cli.environment.PC_HIDE_DISABLED_PROC = lib.mkDefault true;
                  }
                ];
              }
            );
          };
        }
      );
      config.perSystem =
        { config, pkgs, ... }:
        let
          tree = config.process-compose.dev;
        in
        {
          process-compose.dev = { };
          # Native `process-compose` commands use the `dev` tree.
          nullkomma.devShell = {
            packages = [ tree.package ];
            env = {
              PC_CONFIG_FILES = "${tree.outputs.settingsFile}";
              PC_HIDE_DISABLED_PROC = "true";
            };
            shellHook = socket pkgs;
          };
          processTrees = lib.mapAttrs (
            _: tree: tree.outputs.package // { inherit (tree.settings) processes; }
          ) config.process-compose;
        };
    };
}
