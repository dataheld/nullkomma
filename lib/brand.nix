# Translates a brand flake's brand.yml into Quarto metadata and a pkgdown footer.
{
  pkgs,
  lib,
  brand,
  privacyHref ? null,
}:
let
  metadata = lib.optionalAttrs (brand != null) {
    website.navbar.background = "primary";
    format.html = {
      theme = {
        light = [
          "default"
          "brand"
        ];
        dark = [
          "default"
          "brand"
          "_extensions/nullkomma-brand/dark.scss"
        ];
      };
      respect-user-color-scheme = true;
    };
  };
in
pkgs.runCommand "site-brand" { nativeBuildInputs = [ pkgs.pandoc ]; } ''
  pandoc lua ${./brand.lua} \
    ${lib.escapeShellArg (if brand != null then "${brand.lib.brand}" else "")} \
    ${lib.escapeShellArg (if privacyHref == null then "" else privacyHref)} \
    ${lib.escapeShellArg (builtins.toJSON metadata)} \
    "$out"
''
