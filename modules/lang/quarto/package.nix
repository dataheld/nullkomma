{ inputs, ... }:
{
  flake.flakeModules.quarto =
    { lib, ... }:
    {
      imports = [ inputs.self.flakeModules.default ];
      perSystem =
        { pkgs, ... }:
        {
          options.nullkomma.quarto.package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.quartoMinimal.overrideAttrs (old: {
              # nixpkgs#519484: quarto 1.9.37 emits `syntax-highlighting`, pandoc 3.7+ expects `highlight-style`
              postPatch = (old.postPatch or "") + ''
                substituteInPlace bin/quarto.js \
                  --replace-fail "syntax-highlighting" "highlight-style"
              '';
              # nixpkgs#393246: quarto shells out to `which`
              postFixup = (old.postFixup or "") + ''
                wrapProgram $out/bin/quarto --prefix PATH : ${lib.makeBinPath [ pkgs.which ]}
              '';
            });
            defaultText = lib.literalMD "`pkgs.quartoMinimal` with nullkomma's workarounds";
            description = "Quarto, without bundled R/Python; engines come from the R/Python aspects.";
          };
        };
    };
}
