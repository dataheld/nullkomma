{
  partitions.dev.module.perSystem =
    { harness, pkgs, ... }:
    let
      inherit (harness)
        callFlakeWith
        project
        root
        treefmt
        ;
      md = root + "/tests/fixtures/md";
    in
    {
      checks.yaml-nix-config = pkgs.runCommand "yaml-nix-config" { } ''
        ${project md}
        ${treefmt (
          callFlakeWith {
            perSystem.treefmt.programs.yamllint.settings.rules.truthy.allowed-values = [
              "true"
              "false"
              "yes"
            ];
          } md
        )}
        printf 'name: value\n' > custom.yaml
        printf 'name: "%0120d"\n' 0 > long.yaml
        printf 'name: yes\n' > yes.yaml
        format custom.yaml long.yaml yes.yaml
        printf 'name: on\n' > on.yaml
        rejects truthy on.yaml
        # A native config cannot replace the Nix settings.
        printf 'extends: default\nrules:\n  quoted-strings: {required: true}\nignore-from-file: .yamlignore\n' > .yamllint
        printf 'ignored.yaml\n' > .yamlignore
        format custom.yaml long.yaml
        cp on.yaml ignored.yaml
        rejects truthy ignored.yaml
        touch "$out"
      '';
      checks.actionlint-nix-config = pkgs.runCommand "actionlint-nix-config" { } ''
        ${project md}
        ${treefmt (
          callFlakeWith {
            nullkomma.lint.actionlint.self-hosted-runner.labels = [ "custom-runner" ];
          } md
        )}
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
        format --formatters actionlint .github/workflows/check.yml
        sed -i 's/custom-runner/native-only/' .github/workflows/check.yml
        rejects native-only --formatters actionlint .github/workflows/check.yml
        touch "$out"
      '';
    };
}
