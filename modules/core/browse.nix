# The one way nullkomma opens pages: each server in `nullkomma.browse.servers`
# gets an opener, `<server>-browser`, as a prerequisite,
# so that restarts of the server reuse the open page instead of opening more.
# Servers keep their own live reload.
{
  framework =
    { flake-parts-lib, lib, ... }:
    {
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { pkgs, ... }:
        {
          options.nullkomma.browse = {
            servers = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Processes of the `dev` tree whose page opens once they first log their `ready_log_line`, at the first URL on that line.";
            };
            command = lib.mkOption {
              type = lib.types.str;
              default = if pkgs.stdenv.isDarwin then "/usr/bin/open" else "${pkgs.xdg-utils}/bin/xdg-open";
              defaultText = lib.literalMD "`open` on macOS, `xdg-open` on Linux, which follows `$BROWSER` outside desktop environments";
              description = "Program that opens a URL, its only argument, in the browser.";
            };
          };
        }
      );
      config.perSystem =
        { config, pkgs, ... }:
        let
          cfg = config.nullkomma.browse;
          inherit (config.process-compose.dev.settings) processes;
          opener =
            name:
            let
              ready =
                lib.throwIf (processes.${name}.ready_log_line == null)
                  "nullkomma.browse.servers: ${name} needs a ready_log_line on the line of its URL"
                  processes.${name}.ready_log_line;
            in
            pkgs.writeShellApplication {
              name = "${name}-browser";
              runtimeInputs = [ config.process-compose.dev.package ];
              # The URL ends at the color codes that some servers log around it.
              # Browsers may refuse 0.0.0.0, on which servers listen for all addresses.
              text = ''
                while :; do
                  while IFS= read -r line; do
                    if [[ "$line" == *${lib.escapeShellArg ready}* && "$line" =~ https?://[^[:space:][:cntrl:]]+ ]]; then
                      exec ${lib.escapeShellArg cfg.command} "''${BASH_REMATCH[0]/:\/\/0.0.0.0:/://127.0.0.1:}"
                    fi
                  done < <(process-compose process logs ${lib.escapeShellArg name} 2>/dev/null)
                  sleep 1
                done
              '';
            };
        in
        {
          process-compose.dev.settings.processes = lib.mkMerge (
            map (name: {
              ${name}.depends_on."${name}-browser".condition = "process_started";
              "${name}-browser" = {
                inherit (processes.${name}) namespace;
                command = opener name;
              };
            }) cfg.servers
          );
        };
    };
}
