{
  partitions.dev.module.perSystem =
    {
      harness,
      lib,
      pkgs,
      ...
    }:
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
        ${(perSystem customized).treefmt.settings.formatter.gitleaks.command} allowed.txt
        if "$scan" allowed.txt > scan.log 2>&1; then
          echo 'Native configuration bypassed Nix policy' >&2
          exit 1
        fi
        if "$scan" secret.txt > scan.log 2>&1; then
          echo 'Default rules were disabled' >&2
          exit 1
        fi
        rm .gitleaks.toml
        printf 'secret.txt:github-pat:1\n' > .gitleaksignore
        if "$scan" secret.txt > scan.log 2>&1; then
          echo 'Native ignore file bypassed Nix policy' >&2
          exit 1
        fi
        # Generated site output is excluded.
        mkdir docs
        cp secret.txt docs/generated.md
        touch flake.nix
        ${lib.getExe (perSystem fixtures.r).treefmt.build.wrapper} --no-cache --fail-on-change docs/generated.md
        touch "$out"
      '';
    };
}
