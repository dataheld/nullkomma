{
  partitions.dev.module.perSystem =
    { harness, pkgs, ... }:
    let
      inherit (harness)
        callFlakeWith
        fixtures
        perSystem
        root
        ;
      deployed = callFlakeWith {
        nullkomma.github.ci = {
          inputs = {
            deploy = true;
            cloudflare-account-id = "account";
            cloudflare-state-bucket = "state";
          };
          secrets = [
            "CLOUDFLARE_API_TOKEN"
            "CLOUDFLARE_R2_ACCESS_KEY_ID"
            "CLOUDFLARE_R2_SECRET_ACCESS_KEY"
          ];
        };
      } (root + "/tests/fixtures/md");
      workflow = flake: (perSystem flake).nullkomma.files.".github/workflows/push.yml".source;
    in
    {
      checks.github-deploy-workflow =
        pkgs.runCommand "nullkomma-github-deploy-workflow"
          {
            nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ];
          }
          ''
            python - ${workflow fixtures.md} ${workflow deployed} ${root + "/.github/workflows/ci.yml"} <<'PY'
            import sys
            import yaml

            plain, deployed, reusable = [yaml.safe_load(open(path)) for path in sys.argv[1:]]
            assert plain["concurrency"]["cancel-in-progress"] is True
            cancel = deployed["concurrency"]["cancel-in-progress"]
            assert "github.event_name == 'pull_request'" in cancel
            assert "github.ref != format('refs/heads/{0}', github.event.repository.default_branch)" in cancel
            caller = deployed["jobs"]["nullkomma"]
            assert caller["with"]["deploy"] is True
            assert caller["with"]["cloudflare-account-id"] == "account"
            assert caller["with"]["cloudflare-state-bucket"] == "state"
            secrets = ["CLOUDFLARE_API_TOKEN", "CLOUDFLARE_R2_ACCESS_KEY_ID", "CLOUDFLARE_R2_SECRET_ACCESS_KEY"]
            assert set(caller["secrets"]) == set(secrets)
            # PyYAML's YAML 1.1 parser treats the Actions `on` key as a boolean.
            contract = reusable[True]["workflow_call"]
            assert contract["inputs"]["deploy"]["default"] is False
            assert set(contract["secrets"]) == set(secrets)
            deploy = reusable["jobs"]["deploy"]
            assert deploy["needs"] == "success"
            for guard in [
                "inputs.deploy",
                "!github.event.repository.fork",
                "github.event_name == 'push'",
                "github.ref == format('refs/heads/{0}', github.event.repository.default_branch)",
            ]:
                assert guard in deploy["if"]
            assert deploy["concurrency"]["cancel-in-progress"] is False
            assert deploy["concurrency"]["group"] == "cloudflare-production-''${{ github.repository }}"
            steps = deploy["steps"]
            assert steps[0]["with"]["persist-credentials"] is False
            assert steps[-1]["run"].rstrip().endswith("nix run .#deploy")
            assert steps[-1]["env"]["AWS_ACCESS_KEY_ID"] == "''${{ secrets.CLOUDFLARE_R2_ACCESS_KEY_ID }}"
            assert steps[-1]["env"]["AWS_SECRET_ACCESS_KEY"] == "''${{ secrets.CLOUDFLARE_R2_SECRET_ACCESS_KEY }}"
            for name, job in reusable["jobs"].items():
                if name != "deploy":
                    assert not any("CLOUDFLARE" in str(step) for step in job.get("steps", []))
            PY
            touch "$out"
          '';
    };
}
