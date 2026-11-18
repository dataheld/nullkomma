# The browsers that nullkomma runs or provides render with one font configuration,
# so that a machine's fonts and configuration do not change what checks see.
# Chromium on macOS takes its fonts from the system, not from fontconfig.
{
  framework =
    { flake-parts-lib, lib, ... }:
    {
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { config, pkgs, ... }:
        let
          # fontconfig's own rules, without those that read the user's and the machine's.
          rules = pkgs.runCommand "fontconfig-conf.d" { } ''
            cp -rL ${pkgs.fontconfig.out}/etc/fonts/conf.d "$out"
            chmod u+w "$out"
            rm "$out"/{50-user,51-local}.conf
          '';
          browsers = pkgs.playwright-driver.browsers.override {
            withFirefox = false;
            withWebkit = false;
          };
        in
        {
          options.nullkomma.fontconfig = lib.mkOption {
            type = lib.types.package;
            # make-fonts-conf.xsl always adds the XDG font directory.
            default = pkgs.runCommand "fonts.conf" { } ''
              grep -vF '<dir prefix="xdg">fonts</dir>' ${
                pkgs.makeFontsConf {
                  fontDirectories = [
                    pkgs.liberation_ttf
                    pkgs.dejavu_fonts
                  ];
                  impureFontDirectories = [ ];
                  includes = [ rules ];
                }
              } > "$out"
            '';
            defaultText = lib.literalMD "fontconfig's own rules and the Liberation and DejaVu fonts";
            description = "fontconfig configuration of the browsers that nullkomma runs or provides on Linux: R's, the agents' and `nullkomma.playwrightBrowsers`. They use no other fonts or fontconfig configuration.";
          };
          options.nullkomma.playwrightBrowsers = lib.mkOption {
            type = lib.types.package;
            readOnly = true;
            # Playwright finds each browser at its path, so the wrappers replace the executables there.
            default =
              if pkgs.stdenv.isLinux then
                pkgs.runCommand "playwright-browsers" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
                  cp -rLs ${browsers} "$out"
                  chmod -R u+w "$out"
                  cd "$out"
                  # Playwright's own arm64 build names the headless shell differently from Chrome for Testing.
                  shopt -s nullglob
                  chromes=(chromium-*/*/chrome chromium_headless_shell-*/*/{chrome-headless-shell,headless_shell})
                  test ''${#chromes[@]} = 2
                  for chrome in "''${chromes[@]}"; do
                    rm "$chrome"
                    makeWrapper ${browsers}/"$chrome" "$chrome" --set FONTCONFIG_FILE ${config.nullkomma.fontconfig}
                  done
                ''
              else
                browsers;
            defaultText = lib.literalMD "nixpkgs' Playwright Chromium, with `nullkomma.fontconfig` on Linux";
            description = "Playwright's Chromium for `PLAYWRIGHT_BROWSERS_PATH`, e.g. in checks with nixpkgs' Playwright.";
          };
        }
      );
    };
}
