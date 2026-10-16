# `nix run .#r-lock`: pak resolves DESCRIPTION into `nullkomma.r.lockfile`
# against the PPM snapshot matching nixpkgs (source packages, so the lockfile
# does not depend on the platform it was created on).
{ inputs, ... }:
{
  plugins.r =
    {
      config,
      lib,
      self,
      ...
    }:
    let
      cfg = config.nullkomma.r;
      relative = path: lib.removePrefix "${toString self}/" (toString path);
      description = relative cfg.description;
      fields = lib.concatMapStringsSep ", " builtins.toJSON cfg.fields;
    in
    {
      config.perSystem = lib.mkIf cfg.enable (
        {
          config,
          pkgs,
          system,
          ...
        }:
        let
          pkgsR = inputs.nixpkgs-r.legacyPackages.${system};
        in
        {
          packages.r-lock = config.nullkomma.tasks.r-lock.package;
          nullkomma.tasks.r-lock = {
            description = "Resolve DESCRIPTION into the R lockfile (${baseNameOf cfg.lockfile}) with pak";
            skip = true;
            packages = [
              pkgs.coreutils
              pkgs.git
              (pkgsR.rWrapper.override { packages = [ pkgsR.rPackages.pak ]; })
            ];
            command = ''
              while [ ! -f flake.nix ] && [ "$PWD" != / ]; do cd ..; done
              description=${lib.escapeShellArg description}
              lockfile=${lib.escapeShellArg (relative cfg.lockfile)}
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
        }
      );
    };
}
