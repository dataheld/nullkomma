{
  partitions.dev.module.perSystem =
    { harness, pkgs, ... }:
    let
      inherit (harness)
        callFlakeWith
        project
        root
        treefmt
        perSystem
        ;
      flake = callFlakeWith {
        perSystem.treefmt.programs.yamllint.settings = {
          ignore = [ "shared-ignore.yaml" ];
          rules.truthy.allowed-values = [
            "true"
            "false"
            "yes"
          ];
        };
      } (root + "/tests/fixtures/md");
    in
    {
      checks.yaml-nix-config = pkgs.runCommand "yaml-nix-config" { } ''
        ${project (root + "/tests/fixtures/md")}
        ${treefmt flake}
        printf 'name: value\n' > custom.yaml
        printf 'name: "%0120d"\n' 0 > long.yaml
        printf 'name: yes\n' > yes.yaml
        format custom.yaml long.yaml yes.yaml
        printf 'name: on\n' > on.yaml
        rejects truthy on.yaml
        cp on.yaml shared-ignore.yaml
        format shared-ignore.yaml
        # A native config cannot replace the Nix settings.
        printf 'extends: default\nrules:\n  quoted-strings: {required: true}\nignore-from-file: .yamlignore\n' > .yamllint
        printf 'ignored.yaml\n' > .yamlignore
        cp custom.yaml ignored.yaml
        format custom.yaml long.yaml
        cp on.yaml ignored.yaml
        rejects truthy ignored.yaml
        rejects truthy on.yaml
        touch "$out"
      '';
      checks.actionlint-nix-config =
        let
          customized = callFlakeWith {
            nullkomma.lint.actionlint.self-hosted-runner.labels = [ "custom-runner" ];
          } (root + "/tests/fixtures/md");
          actionlint = (perSystem customized).treefmt.build.programs.actionlint;
          options = (perSystem customized).treefmt.settings.formatter.actionlint.options;
        in
        pkgs.runCommand "actionlint-nix-config" { } ''
          ${project (root + "/tests/fixtures/md")}
          mkdir -p .github/workflows
          printf 'self-hosted-runner:\n  labels: ["native-only"]\n' > .github/actionlint.yaml
          cat > .github/workflows/check.yml <<'YAML'
          on: push
          jobs:
            check:
              runs-on: custom-runner
              steps:
                - run: echo ok
          YAML
          ${actionlint}/bin/actionlint ${builtins.concatStringsSep " " options} .github/workflows/check.yml
          sed -i 's/custom-runner/native-only/' .github/workflows/check.yml
          fails native-only ${actionlint}/bin/actionlint ${builtins.concatStringsSep " " options} .github/workflows/check.yml
          touch "$out"
        '';
    };
}
