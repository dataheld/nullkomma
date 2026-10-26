# Applies `nullkomma.brand` to any `quarto` project through `_nullkomma-brand.yml`
# metadata, which projects list in `metadata-files`. Layered on `quarto`, whose
# options it reads; `quarto` itself knows no brand.
{ config, ... }:
let
  quartoModule = config.flake.flakeModules.quarto;
in
{
  plugins.quarto-brand =
    {
      config,
      lib,
      self,
      ...
    }:
    let
      cfg = config.nullkomma.quarto;
      inherit (config.nullkomma) privacy;
      brand =
        if config.nullkomma.brand == null then
          throw "nullkomma.quarto-brand needs nullkomma.brand"
        else
          config.nullkomma.brand;
      prefix = import ../../../lib/prefix.nix lib self cfg.root;
    in
    {
      imports = [ quartoModule ];
      config = lib.mkIf config.nullkomma.quarto-brand.enable {
        nullkomma.quarto.enable = true;
        nullkomma.quarto.extensions.nullkomma-brand = ./_nullkomma-brand;
        perSystem =
          { config, pkgs, ... }:
          let
            quarto = config.nullkomma.quarto.package;
            brandExtension = (pkgs.formats.yaml { }).generate "_extension.yml" {
              contributes.metadata.project.brand = "origin/${baseNameOf brand.lib.brand}";
            };
            siteBrand = import ../../../lib/brand.nix {
              inherit pkgs lib brand;
              metadata = {
                website.navbar.background = "primary";
                format.html = {
                  theme.light = [
                    "default"
                    "brand"
                  ];
                  theme.dark = [
                    "default"
                    "brand"
                    "_extensions/nullkomma-brand/dark.scss"
                  ];
                  respect-user-color-scheme = true;
                };
              };
              privacyHref =
                if cfg.privacy.page != null && privacy.policy != { } then
                  lib.removeSuffix ".qmd" cfg.privacy.page + ".html"
                else
                  null;
            };
          in
          {
            nullkomma.files = {
              "${prefix}_nullkomma-brand.yml" = {
                mode = "generated";
                commentPrefix = "#";
                source = "${siteBrand}/quarto.yml";
              };
              "${prefix}_brand" = {
                mode = "generated";
                directory = true;
                source = pkgs.runCommand "quarto-brand" { nativeBuildInputs = [ quarto ]; } ''
                  export HOME="$TMPDIR"
                  mkdir source
                  cp ${brandExtension} source/_extension.yml
                  ln -s ${lib.escapeShellArg "${dirOf brand.lib.brand}"} source/origin
                  quarto use brand ./source --force
                  test -f _brand/_brand.yml
                  mv _brand "$out"
                '';
              };
            };
          };
      };
    };
}
