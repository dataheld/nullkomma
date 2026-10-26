# Offline site builds vendor pkgdown's CDN assets using a manifest from its own metadata.
{
  partitions.dev.module.perSystem =
    {
      config,
      inputs',
      lib,
      pkgs,
      ...
    }:
    let
      generate = pkgs.writeShellScriptBin "generate-vendored-pkgdown" ''
        exec ${
          inputs'.nixpkgs-r.legacyPackages.rWrapper.override {
            packages = [ inputs'.nixpkgs-r.legacyPackages.rPackages.pkgdown ];
          }
        }/bin/Rscript --vanilla ${./_vendored-pkgdown.R}
      '';
    in
    {
      nullkomma.tasks.refresh-vendored-pkgdown = {
        description = "Refresh the vendored pkgdown asset manifest after upgrading pkgdown";
        before = [ "refresh-vendored" ];
        working_dir = ".";
        packages = [ generate ];
        command = ''
          generate-vendored-pkgdown > modules/lang/r/_vendored-pkgdown.json
        '';
      };
      checks.vendored-pkgdown =
        assert lib.elem "refresh-vendored-pkgdown" config.nullkomma.tasks.refresh-vendored.closure;
        pkgs.runCommand "vendored-pkgdown" { nativeBuildInputs = [ pkgs.git ]; } ''
          git init --quiet
          mkdir -p modules/lang/r nested
          cd nested
          ${lib.getExe config.nullkomma.tasks.refresh-vendored-pkgdown.package}
          cd ..
          ${lib.getExe pkgs.jq} -S . modules/lang/r/_vendored-pkgdown.json > generated.json
          ${lib.getExe pkgs.jq} -S . ${./_vendored-pkgdown.json} > vendored.json
          diff -u vendored.json generated.json || {
            echo "pkgdown's vendored asset manifest is stale; run refresh-vendored-pkgdown." >&2
            exit 1
          }
          touch "$out"
        '';
    };
}
