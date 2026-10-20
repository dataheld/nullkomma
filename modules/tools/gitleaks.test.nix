{
  partitions.dev.module.perSystem =
    {
      harness,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (harness) fixtures perSystem;
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
        "$scan" allowed.txt
        if "$scan" secret.txt > scan.log 2>&1; then
          echo 'Native allowlist disabled unrelated default rules' >&2
          exit 1
        fi
        rm .gitleaks.toml
        printf 'secret.txt:github-pat:1\n' > .gitleaksignore
        "$scan" secret.txt
        # Generated site output is excluded.
        mkdir docs
        cp secret.txt docs/generated.md
        touch flake.nix
        ${lib.getExe (perSystem fixtures.r).treefmt.build.wrapper} --no-cache --fail-on-change docs/generated.md
        touch "$out"
      '';
    };
}
