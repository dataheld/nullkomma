{
  plugins.quarto =
    {
      config,
      flake-parts-lib,
      lib,
      self,
      ...
    }:
    let
      cfg = config.nullkomma.quarto;
    in
    {
      options.nullkomma.quarto.root = lib.mkOption {
        type = lib.types.path;
        default = self.outPath;
        defaultText = lib.literalExpression "self.outPath";
        description = "Build source directory; `_quarto.yml` and content stay user-owned. The local `render` task works in the current directory.";
      };
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { pkgs, ... }:
        {
          options.nullkomma.quarto.package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.quartoMinimal.overrideAttrs (old: {
              # Nixpkgs' Quarto 1.9 emits a key its newer Pandoc no longer accepts.
              postPatch = (old.postPatch or "") + ''
                substituteInPlace bin/quarto.js \
                  --replace-fail "syntax-highlighting" "highlight-style"
              '';
              postFixup = (old.postFixup or "") + ''
                wrapProgram $out/bin/quarto --prefix PATH : ${lib.makeBinPath [ pkgs.which ]}
              '';
            });
            defaultText = lib.literalMD "`pkgs.quartoMinimal`, with the Pandoc compatibility fix and `which` on PATH";
            description = "Quarto without R, Python or TeX; override to supply execution engines.";
          };
        }
      );
      config = lib.mkIf cfg.enable {
        nullkomma.gitignore = [
          ".quarto/"
          "_site/"
        ];
        perSystem =
          { config, pkgs, ... }:
          let
            quarto = config.nullkomma.quarto.package;
          in
          {
            nullkomma = {
              devHelpers = [ quarto ];
              editor.vscode.extensions = [ "quarto.quarto" ];
              site = lib.mkDefault (
                pkgs.stdenvNoCC.mkDerivation {
                  name = "quarto-site";
                  src = cfg.root;
                  nativeBuildInputs = [ quarto ];
                  buildPhase = ''
                    runHook preBuild
                    export HOME="$TMPDIR" XDG_CACHE_HOME="$TMPDIR/cache"
                    quarto render --output-dir "$TMPDIR/site"
                    if [[ ! -f "$TMPDIR/site/index.html" ]]; then
                      echo "nullkomma.quarto: rendered site is missing index.html" >&2
                      exit 1
                    fi
                    runHook postBuild
                  '';
                  installPhase = ''
                    runHook preInstall
                    cp -r "$TMPDIR/site" "$out"
                    runHook postInstall
                  '';
                }
              );
              tasks.render = {
                description = "Render the current Quarto project into its configured output directory";
                packages = [ quarto ];
                skip = true;
                command = ''
                  exec quarto render "$@"
                '';
              };
            };
          };
      };
    };
}
