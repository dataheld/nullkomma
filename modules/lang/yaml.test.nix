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
      flake = callFlakeWith {
        nullkomma.lint.yaml = {
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
      checks.yaml-native-config = pkgs.runCommand "yaml-native-config" { } ''
        ${project (root + "/tests/fixtures/md")}
        ${treefmt flake}
        printf 'name: value\n' > custom.yaml
        printf 'rules:\n  quoted-strings: {required: true}\nignore-from-file: .yamlignore\n' > .yamllint
        printf 'ignored.yaml\n' > .yamlignore
        cp custom.yaml ignored.yaml
        cp custom.yaml shared-ignore.yaml
        rejects quoted-strings custom.yaml
        format ignored.yaml shared-ignore.yaml
        printf 'name: "%0120d"\n' 0 > long.yaml
        format long.yaml
        printf 'rules:\n  line-length: {max: 20}\n' > .yamllint
        rejects line-length long.yaml
        printf 'rules: {}\n' > .yamllint
        format custom.yaml long.yaml
        printf 'rules:\n  truthy: {check-keys: false}\n' > .yamllint
        printf 'name: yes\n' > partial.yaml
        format partial.yaml
        printf 'name: on\n' > partial.yaml
        rejects truthy partial.yaml
        touch "$out"
      '';
    };
}
