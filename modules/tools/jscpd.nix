{
  plugins.jscpd =
    { config, lib, ... }:
    let
      enabled = config.nullkomma.jscpd.enable;
      settings = config.nullkomma.lint.jscpd;
    in
    {
      config.perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        lib.mkIf enabled (
          let
            assets = {
              aarch64-darwin = {
                name = "darwin-arm64";
                hash = "sha256-CCmtzMlKYDWkMjoQ8X+g1a7mQl6wHnxaiMxh71+HpWs=";
              };
              aarch64-linux = {
                name = "linux-arm64-musl";
                hash = "sha256-qOblrgTSeYqT6TUHOwie4mum+qpzTOHcrp9pF2nUA4w=";
              };
              x86_64-linux = {
                name = "linux-x64-musl";
                hash = "sha256-CrzW5kgf9/d7wuQHwfT2dK3zYLi9w3t0zxDTj7sfePw=";
              };
            };
            # shortcut: upstream's release binaries, since jscpd 5 needs a newer rustc than our
            # Nixpkgs; build from source (or use nixpkgs' package) once Nixpkgs catches up.
            jscpd = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
              pname = "jscpd";
              version = "5.4.1";
              src = pkgs.fetchzip {
                url = "https://github.com/kucherenko/jscpd/releases/download/v${finalAttrs.version}/jscpd-${assets.${system}.name}.tar.gz";
                inherit (assets.${system}) hash;
                stripRoot = false;
              };
              installPhase = "install -Dm755 jscpd $out/bin/jscpd";
              meta = {
                description = "Copy/paste detector for source code";
                homepage = "https://jscpd.dev";
                license = lib.licenses.mit;
                mainProgram = "jscpd";
                platforms = lib.attrNames assets;
                sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
              };
            });
          in
          {
            process-compose.dev.settings.processes = {
              jscpd = {
                namespace = "jscpd";
                description = "Find duplicated code";
                environment.JSCPD_NO_TIPS = "1";
                disabled = true;
                command = "${lib.getExe jscpd} --config ${
                  (pkgs.formats.json { }).generate "jscpd.json" (
                    {
                      threshold = 0;
                    }
                    // settings
                    // {
                      ignore = config.treefmt.settings.excludes ++ (settings.ignore or [ ]);
                    }
                  )
                }";
              };
              check.depends_on.jscpd.condition = "process_completed_successfully";
            };
          }
        );
    };
}
