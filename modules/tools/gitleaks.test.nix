{
  partitions.dev.module.perSystem =
    { harness, pkgs, ... }:
    let
      inherit (harness)
        fixtures
        perSystem
        callFlakeWith
        root
        ;
      customized = callFlakeWith {
        nullkomma.lint.gitleaks.allowlists = [ { paths = [ "^allowed[.]txt$" ]; } ];
      } (root + "/tests/fixtures/md");
    in
    {
      checks.gitleaks = pkgs.runCommand "gitleaks-treefmt" { } ''
        scan=${(perSystem fixtures.md).treefmt.settings.formatter.gitleaks.command}
        printf 'ordinary project text\n' > clean.txt
        "$scan" clean.txt
        printf '%s%s\n' 'ghp_' 'xcW3BwhFZwDiTfeZpXyE2KJm6RQbnVhqUsa7' > secret.txt
        if "$scan" clean.txt secret.txt > scan.log 2>&1; then
          echo 'Secret scanner accepted a synthetic credential' >&2
          exit 1
        fi
        ! grep -qF 'xcW3BwhFZwDiTfeZpXyE2KJm6RQbnVhqUsa7' scan.log
        cp secret.txt allowed.txt
        cat > .gitleaks.toml <<'TOML'
        [extend]
        useDefault = true
        [[allowlists]]
        paths = ["^allowed[.]txt$"]
        TOML
        customized=${(perSystem customized).treefmt.settings.formatter.gitleaks.command}
        "$customized" allowed.txt
        if "$customized" secret.txt > scan.log 2>&1; then
          echo 'Project settings disabled the default rules' >&2
          exit 1
        fi
        if "$scan" allowed.txt > scan.log 2>&1; then
          echo 'Native configuration bypassed Nix policy' >&2
          exit 1
        fi
        rm .gitleaks.toml
        printf 'secret.txt:github-pat:1\n' > .gitleaksignore
        if "$scan" secret.txt > scan.log 2>&1; then
          echo 'Native ignore file bypassed Nix policy' >&2
          exit 1
        fi
        touch "$out"
      '';
    };
}
