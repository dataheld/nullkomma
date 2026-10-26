# Renders a brand flake's footer for Quarto (merged into `metadata`) and pkgdown.
{
  pkgs,
  lib,
  brand,
  privacyHref ? null,
  metadata ? { },
}:
pkgs.runCommand "site-brand" { nativeBuildInputs = [ pkgs.pandoc ]; } ''
  pandoc lua ${./brand.lua} \
    ${lib.escapeShellArg (if brand != null then "${brand.lib.brand}" else "")} \
    ${lib.escapeShellArg (if privacyHref == null then "" else privacyHref)} \
    ${lib.escapeShellArg (builtins.toJSON metadata)} \
    "$out"
''
