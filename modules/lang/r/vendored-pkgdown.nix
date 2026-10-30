# Offline site builds vendor pkgdown's CDN assets using a manifest from its own metadata.
{
  partitions.dev.module.perSystem =
    {
      inputs',
      lib,
      pkgs,
      ...
    }:
    let
      refresh = pkgs.writeShellScriptBin "refresh-vendored-pkgdown" ''
        ${
          inputs'.nixpkgs-r.legacyPackages.rWrapper.override {
            packages = [ inputs'.nixpkgs-r.legacyPackages.rPackages.pkgdown ];
          }
        }/bin/Rscript --vanilla ${./_vendored-pkgdown.R} > modules/lang/r/_vendored-pkgdown.json
      '';
    in
    {
      process-compose.dev.settings.processes = {
        refresh-vendored-pkgdown = {
          namespace = "dev";
          description = "Refresh the vendored pkgdown asset manifest after upgrading pkgdown";
          command = refresh;
          disabled = true;
        };
        refresh-vendored.depends_on.refresh-vendored-pkgdown.condition = "process_completed_successfully";
      };
      checks.vendored-pkgdown = pkgs.runCommand "vendored-pkgdown" { } ''
        mkdir -p modules/lang/r
        ${lib.getExe refresh}
        ${lib.getExe pkgs.jq} -S . modules/lang/r/_vendored-pkgdown.json > generated.json
        ${lib.getExe pkgs.jq} -S . ${./_vendored-pkgdown.json} > vendored.json
        diff -u vendored.json generated.json || {
          echo "pkgdown's vendored asset manifest is stale; run nk refresh-vendored-pkgdown." >&2
          exit 1
        }
        touch "$out"
      '';
    };
}
