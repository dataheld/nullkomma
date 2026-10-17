{
  plugins.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
      generatedPaths = config.nullkomma.generatedPaths;
    in
    {
      options.nullkomma.r.jscpd.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Check the repository for duplicated code with jscpd. Native .jscpd.json or package.json settings extend shared defaults: Git ignores, generated/managed files and lockfile exclusions, and a zero duplication threshold.";
      };
      config.perSystem =
        { config, pkgs, ... }:
        lib.mkIf (cfg.enable && cfg.jscpd.enable) (
          let
            ignores = [
              "**/pkg.lock"
              "**/flake.lock"
              "**/package-lock.json"
              "**/tests/testthat/_snaps/**"
            ]
            ++ generatedPaths
            ++ lib.concatLists (
              lib.mapAttrsToList (path: file: [ path ] ++ lib.optional file.directory "${path}/**") (
                lib.filterAttrs (_: file: file.enable) config.nullkomma.files
              )
            );
            nodeModules = pkgs.importNpmLock.buildNodeModules {
              npmRoot = ./_jscpd;
              nodejs = pkgs.nodejs;
              derivationArgs.postInstall = ''
                # Extend native discovery instead of replacing project ignores with --ignore.
                substituteInPlace "$out"/node_modules/jscpd/dist/chunk-*.js \
                  --replace-fail '...packageJsonConfig,' 'gitignore: true, threshold: 0, ...packageJsonConfig,' \
                  --replace-fail 'result.reporters = result.reporters || [];' \
                    'result.ignore = ${builtins.toJSON ignores}.concat(result.ignore || []); result.reporters = result.reporters || [];'
              '';
            };
          in
          {
            nullkomma.tests.r-jscpd = {
              packages = [ pkgs.nodejs ];
              command = ''
                exec node ${nodeModules}/node_modules/jscpd/bin/jscpd --silent "$@" .
              '';
            };
            nullkomma.tasks.r-jscpd = {
              description = "Check for duplicated code with jscpd";
              command = "exec ${lib.getExe config.nullkomma.tests.r-jscpd.package} \"$@\"";
            };
          }
        );
    };
}
