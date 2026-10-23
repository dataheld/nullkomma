{
  pkgs,
  lib,
  brand,
  privacyHref ? null,
}:
pkgs.runCommand "site-brand"
  { nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ]; }
  ''
    python ${./brand.py} \
      ${lib.escapeShellArg (if brand == null then "" else "${brand.lib.brand}")} \
      ${
        lib.escapeShellArg (if brand != null && brand.lib ? footer then "${brand.lib.footer}" else "")
      } \
      ${lib.escapeShellArg (if privacyHref == null then "" else privacyHref)} \
      ${../modules/lang/_quarto/docs.yml} "$out"
    cp ${../modules/lang/_quarto/dark.scss} "$out/dark.scss"
    cp ${../modules/lang/_quarto/landmarks.lua} "$out/landmarks.lua"
  ''
