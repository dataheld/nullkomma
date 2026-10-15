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
        description = "Quarto project rendered into `packages.site` and served by the `preview` task.";
      };
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { pkgs, ... }:
        {
          options.nullkomma.quarto.package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.quartoMinimal.overrideAttrs (old: {
              # Nixpkgs' Quarto 1.9 emits a key its newer Pandoc no longer accepts.
              postPatch = (old.postPatch or "") + ''
                substituteInPlace bin/quarto.js --replace-fail syntax-highlighting highlight-style
              '';
              postFixup = (old.postFixup or "") + ''
                wrapProgram $out/bin/quarto --prefix PATH : ${lib.makeBinPath [ pkgs.which ]}
              '';
            });
            defaultText = lib.literalMD "`pkgs.quartoMinimal`, patched for Nixpkgs' Pandoc";
            description = "Quarto, without R, Python or TeX; override to add execution engines.";
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
            rootInRepo =
              assert lib.assertMsg (lib.hasPrefix (toString self) (
                toString cfg.root
              )) "nullkomma.quarto.root must be inside the flake for the preview task.";
              lib.removePrefix (toString self) (toString cfg.root);
          in
          {
            nullkomma.devHelpers = [ quarto ];
            nullkomma.editor.vscode.extensions = [ "quarto.quarto" ];
            # Quarto watches the working tree and live-reloads the browser itself.
            nullkomma.tasks.preview = {
              skip = true;
              raw = true;
              description = "Serve the site on localhost, re-rendering and reloading on changes";
              packages = [
                pkgs.git
                quarto
              ];
              command = ''
                cd "$(git rev-parse --show-toplevel)"${lib.escapeShellArg rootInRepo}
                exec quarto preview "$@"
              '';
            };
            packages.site = lib.mkDefault (
              pkgs.runCommand "site" { nativeBuildInputs = [ quarto ]; } ''
                cp -r ${cfg.root} src && chmod -R u+w src && cd src
                HOME=$TMPDIR quarto render --output-dir "$out"
              ''
            );
          };
      };
    };
}
