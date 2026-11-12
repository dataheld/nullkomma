# A thin GitHub Actions stub calling nullkomma's reusable CI workflow, so CI logic
# is upgraded centrally (.github/workflows/ci.yml in this repo).
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
      '';
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
      };
      config.perSystem = lib.mkIf cfg.enable {
        # Project jobs go below the section, as `jobs` is the last key.
        nullkomma.files.".github/workflows/push.yml" = {
          commentPrefix = "#";
          sections.github = ci;
        };
      };
    };
}
