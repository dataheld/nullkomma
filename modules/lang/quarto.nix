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
        description = "Quarto project rendered into `packages.site`.";
      };
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { pkgs, ... }:
        {
          options.nullkomma.quarto.package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.quartoMinimal.overrideAttrs (old: {
              # Nixpkgs' Quarto 1.9 emits a key its newer Pandoc no longer accepts.
              postPatch = old.postPatch or "" + ''
                substituteInPlace bin/quarto.js --replace-fail syntax-highlighting highlight-style
              '';
              postFixup = old.postFixup or "" + ''
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
          in
          {
            nullkomma.devHelpers = [ quarto ];
            nullkomma.editor.vscode.extensions = [ "quarto.quarto" ];
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
