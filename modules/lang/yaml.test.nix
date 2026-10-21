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
        printf 'name: "%0120d"\n' 0 > long.yaml
        printf 'name: yes\n' > yes.yaml
        format custom.yaml long.yaml yes.yaml
        printf 'name: on\n' > on.yaml
        rejects truthy on.yaml
        cp on.yaml shared-ignore.yaml
        format shared-ignore.yaml
        # A native config replaces the shared one.
        printf 'extends: default\nrules:\n  quoted-strings: {required: true}\nignore-from-file: .yamlignore\n' > .yamllint
        printf 'ignored.yaml\n' > .yamlignore
        cp custom.yaml ignored.yaml
        rejects quoted-strings custom.yaml
        rejects line-length long.yaml
        format ignored.yaml
        touch "$out"
      '';
    };
}
