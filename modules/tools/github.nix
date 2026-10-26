# Thin GitHub Actions stubs that call nullkomma's reusable workflows, so CI logic
# is upgraded centrally (.github/workflows/{ci,maintenance}.yml in this repo).
{
  plugins.github =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.github;
      uses =
        name:
        "${cfg.workflows.source}/${name}.yml"
        + lib.optionalString (cfg.workflows.ref != null) "@${cfg.workflows.ref}";
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
      );
    in
    {
      options.nullkomma.github = {
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
          secrets = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Repository secrets passed to the reusable `ci.yml`.";
          };
        };
      };
      config.perSystem = lib.mkIf cfg.enable {
        nullkomma.files.".github/workflows/push.yml".text = ci;
      };
    };
}
