{
  partitions.dev.module.perSystem =
    {
      harness,
      lib,
      pkgs,
      ...
    }:
    let
      project = harness.perSystem (
        harness.callFlakeWith {
          nullkomma.agents.browser.enable = true;
          nullkomma.r.extraPackages = [ "chromote" ];
        } (harness.root + "/tests/fixtures/r")
      );
      mcp = project.nullkomma.agents.mcpServers.playwright;
      machineFonts = "${pkgs.cantarell-fonts}/share/fonts";
    in
    {
      # Nixpkgs has no Chromium for macOS, where Chromium does not use fontconfig.
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        browser-fonts =
          pkgs.runCommand "browser-fonts"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
              NODE_PATH = "${pkgs.playwright-test}/lib/node_modules";
              PLAYWRIGHT_BROWSERS_PATH = project.nullkomma.playwrightBrowsers;
            }
            ''
              # The fonts and configuration of a machine, where fontconfig would find them.
              # FONTCONFIG_PATH stands in for /etc/fonts.
              export HOME="$TMPDIR/home" FONTCONFIG_PATH="$TMPDIR/home" FONTCONFIG_FILE="$TMPDIR/home/local.conf"
              mkdir -p "$HOME"/{.nix-profile/share,.local/share,.config/fontconfig}
              ln -s ${machineFonts} "$HOME/.nix-profile/share/fonts"
              ln -s ${machineFonts} "$HOME/.local/share/fonts"
              echo '<fontconfig><dir>${machineFonts}</dir><match><edit name="family" mode="prepend" binding="strong"><string>Cantarell</string></edit></match></fontconfig>' |
                tee "$FONTCONFIG_FILE" > "$HOME/.config/fontconfig/fonts.conf"

              cat > expected <<'FONTS'
              DejaVu Sans
              Liberation Mono
              Liberation Sans
              Liberation Serif
              Liberation Mono
              Liberation Sans
              Liberation Serif
              DejaVu Sans Mono
              Liberation Serif
              FONTS
              rendered() {
                echo "$1" >&2
                node ${./_browser-fonts.js} "$@" | diff expected -
              }
              # Playwright's headless shell and Chromium, R's Chromium, and the agents' browser.
              rendered '{}'
              rendered '{"channel": "chromium"}'
              rendered '{"executablePath": "${lib.getExe project.nullkomma.r.browser}"}'
              rendered --mcp ${lib.escapeShellArgs ([ mcp.command ] ++ mcp.args)}
              touch $out
            '';
      };
    };
}
