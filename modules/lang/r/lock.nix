# `nix run .#r-lock`: pak resolves DESCRIPTION into `pkg.lock`
# against the PPM snapshot matching nixpkgs (source packages, so the lockfile
# does not depend on the platform it was created on).
{ inputs, ... }:
{
  plugins.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
      fields = lib.concatMapStringsSep ", " builtins.toJSON cfg.fields;
    in
    {
      config.perSystem = lib.mkIf cfg.enable (
        {
          pkgs,
          system,
          ...
        }:
        let
          pkgsR = inputs.nixpkgs-r.legacyPackages.${system};
          description = "Resolve DESCRIPTION into the R lockfile (pkg.lock) with pak";
          lock = pkgs.writeShellApplication {
            name = "nk-r-lock";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.git
              (pkgsR.rWrapper.override { packages = [ pkgsR.rPackages.pak ]; })
            ];
            text = ''
              while [ ! -f flake.nix ] && [ "$PWD" != / ]; do cd ..; done
              description=${lib.escapeShellArg "./${cfg.prefix}DESCRIPTION"}
              lockfile=${lib.escapeShellArg "./${cfg.prefix}pkg.lock"}
              if [ ! -f "$description" ]; then
                echo "nullkomma: $description not found; R projects must be packages" >&2
                exit 1
              fi
              tmp="$(mktemp -d)"
              trap 'rm -rf "$tmp"' EXIT
              mkdir "$tmp/library"
              cp "$description" "$tmp/DESCRIPTION"
              (
                cd "$tmp"
                Rscript --vanilla - <<'EOF'
                  options(repos = c(CRAN = ${builtins.toJSON cfg.ppmUrl}), pkg.platforms = "source")
                  pak::lockfile_create("deps::.", lockfile = "pkg.lock", lib = "library", dependencies = c(${fields}))
              EOF
              )
              cp "$tmp/pkg.lock" "$lockfile"
              if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
                git add -- "$lockfile"
              fi
              echo "nullkomma: wrote $lockfile; commit it"
            '';
          };
        in
        {
          apps.r-lock = {
            type = "app";
            program = lib.getExe lock;
            meta.description = description;
          };
          process-compose.dev.settings.processes.nk-r-lock = {
            namespace = "r";
            inherit description;
            command = lock;
            disabled = true;
          };
        }
      );
    };
}
