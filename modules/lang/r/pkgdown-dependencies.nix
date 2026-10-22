# Sandboxed site builds are offline, so pkgdown's CDN assets are pinned from its own metadata.
{
  partitions.dev.module.perSystem =
    { inputs', pkgs, ... }:
    let
      generate = pkgs.writeShellScriptBin "pkgdown-dependencies" ''
        exec ${
          inputs'.nixpkgs-r.legacyPackages.rWrapper.override {
            packages = [ inputs'.nixpkgs-r.legacyPackages.rPackages.pkgdown ];
          }
        }/bin/Rscript --vanilla ${./_pkgdown-dependencies.R}
      '';
    in
    {
      nullkomma.tasks.pkgdown-dependencies = {
        description = "Refresh the pinned pkgdown CDN assets after upgrading pkgdown";
        packages = [
          generate
          pkgs.git
        ];
        command = ''
          cd "$(git rev-parse --show-toplevel)"
          pkgdown-dependencies > modules/lang/r/_pkgdown-dependencies.json
        '';
      };
      checks.pkgdown-dependencies = pkgs.runCommand "pkgdown-dependencies" { } ''
        ${pkgs.lib.getExe generate} | ${pkgs.lib.getExe pkgs.jq} -S . > generated.json
        ${pkgs.lib.getExe pkgs.jq} -S . ${./_pkgdown-dependencies.json} > pinned.json
        diff -u pinned.json generated.json || {
          echo "pkgdown's CDN pins are stale; run pkgdown-dependencies." >&2
          exit 1
        }
        touch "$out"
      '';
    };
}
