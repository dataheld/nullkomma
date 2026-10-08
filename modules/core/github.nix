# Thin GitHub Actions stubs that call nullkomma's reusable workflows, so CI logic
# is upgraded centrally (.github/workflows/{ci,maintenance}.yml in this repo).
{
  flake.flakeModules.default =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.github;
      uses =
        name:
        "${cfg.workflows.source}/${name}.yml"
        + lib.optionalString (cfg.workflows.ref != null) "@${cfg.workflows.ref}";
      scalar = v: if lib.isBool v then lib.boolToString v else builtins.toJSON v;
      ci = ''
        name: CI
        on:
          pull_request:
          push:
          workflow_dispatch:
        concurrency:
          group: ''${{ github.workflow }}-''${{ github.event.pull_request.number || github.ref }}
          cancel-in-progress: true
        jobs:
          nullkomma:
            uses: ${uses "ci"}
            permissions:
              contents: read
              id-token: write
      ''
      + lib.optionalString (cfg.ci.secrets != [ ]) (
        "    secrets:\n"
        + lib.concatMapStrings (s: "      ${s}: \${{ secrets.${s} }}\n") (lib.unique cfg.ci.secrets)
      )
      + lib.optionalString (cfg.ci.inputs != { }) (
        "    with:\n"
        + lib.concatStrings (lib.mapAttrsToList (k: v: "      ${k}: ${scalar v}\n") cfg.ci.inputs)
      );
      maintenance = ''
        name: Maintenance
        on:
          schedule:
            - cron: "0 0 * * 0" # weekly, Sunday 00:00 UTC
          workflow_dispatch:
        jobs:
          nullkomma:
            uses: ${uses "maintenance"}
            permissions:
              contents: write
              id-token: write
              issues: write
              pull-requests: write
      '';
    in
    {
      options.nullkomma.github = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to generate `.github/workflows/{push,cron}.yml`.";
        };
        workflows = {
          source = lib.mkOption {
            type = lib.types.str;
            default = "dataheld/nullkomma/.github/workflows";
            description = "Where the reusable workflows live (`./.github/workflows` for local ones).";
          };
          ref = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = "main";
            description = "Git ref of the reusable workflows; null for local workflows.";
          };
        };
        ci = {
          inputs = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.oneOf [
                lib.types.bool
                lib.types.int
                lib.types.str
              ]
            );
            default = { };
            example = {
              visibility = "public";
            };
            description = "Inputs of the reusable `ci.yml` (`visibility` publishes to FlakeHub, `deploy` runs `nix run .#deploy`).";
          };
          secrets = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Repository secrets passed to the reusable `ci.yml`.";
          };
        };
      };
      config.perSystem.nullkomma.files = lib.mkIf cfg.enable {
        ".github/workflows/push.yml".text = ci;
        ".github/workflows/cron.yml".text = maintenance;
      };
    };
}
