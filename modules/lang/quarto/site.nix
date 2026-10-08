{
  flake.flakeModules.quarto =
    {
      config,
      lib,
      self,
      ...
    }:
    let
      cfg = config.nullkomma.quarto;
    in
    {
      options.nullkomma.quarto = {
        root = lib.mkOption {
          type = lib.types.path;
          default = self;
          defaultText = lib.literalExpression "self";
          description = "Quarto project directory (containing `_quarto.yml`).";
        };
        site.enable = lib.mkOption {
          type = lib.types.bool;
          default = builtins.pathExists (cfg.root + "/_quarto.yml");
          defaultText = lib.literalMD "whether `root` has a `_quarto.yml`";
          description = "Whether `quarto render` of `root` becomes `nullkomma.site`.";
        };
      };
      config.perSystem =
        { config, pkgs, ... }:
        let
          quarto = config.nullkomma.quarto.package;
          inputs = [ quarto ] ++ config.nullkomma.quarto.engines;
        in
        {
          options.nullkomma.quarto.engines = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            description = "Engine environments (R, Python) on `PATH` for rendering; set by the language aspects.";
          };
          config = {
            nullkomma = {
              devshell.packages = [ quarto ];
              site = lib.mkIf cfg.site.enable (
                lib.mkDefault (
                  pkgs.stdenvNoCC.mkDerivation {
                    name = "site";
                    src = cfg.root;
                    nativeBuildInputs = inputs;
                    buildPhase = ''
                      runHook preBuild
                      export HOME="$TMPDIR"
                      quarto render --output-dir "$TMPDIR/site"
                      runHook postBuild
                    '';
                    installPhase = ''
                      runHook preInstall
                      cp -r "$TMPDIR/site" $out
                      runHook postInstall
                    '';
                  }
                )
              );
              tasks = {
                preview = {
                  description = "Live-preview the Quarto project (quarto preview)";
                  runtimeInputs = inputs;
                  command = ''exec quarto preview "$@"'';
                };
                render = {
                  description = "Render the Quarto project (quarto render)";
                  runtimeInputs = inputs;
                  command = ''exec quarto render "$@"'';
                };
              };
            };
          };
        };
    };
}
