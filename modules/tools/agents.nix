# Coding agents get always-on rules from a section of the committed AGENTS.md,
# version-specific workflows as Agent Skills (https://agentskills.io) generated from Nix,
# and MCP servers from a generated `.mcp.json`.
# Agents read skills and servers on opening a checkout, so both are committed.
{
  framework =
    {
      config,
      flake-parts-lib,
      lib,
      ...
    }:
    let
      browser = config.nullkomma.agents.browser.enable;
      inDevShell = config.nullkomma.devShell.enable;
      # Store paths differ between systems,
      # so a committed configuration names a command on the dev shell's PATH.
      launcher = name: "mcp-${name}";
      stored = server: server ? command && builtins.hasContext server.command;
    in
    {
      options.nullkomma.agents.browser.enable =
        lib.mkEnableOption "a headless browser for agents, to open and operate the project's web previews, through Playwright's MCP server";
      options.nullkomma.agents.skills = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
        description = "Agent Skill directories by name, each with a `SKILL.md` whose `name` matches; plugins add here. The `agents` plugin generates them into `.agents/skills/<name>`.";
      };
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { config, pkgs, ... }:
        {
          config.nullkomma.agents.mcpServers.playwright = lib.mkIf browser {
            type = "stdio";
            # nixpkgs' playwright-mcp fixes PLAYWRIGHT_BROWSERS_PATH, but its Chromium takes FONTCONFIG_FILE.
            command =
              if pkgs.stdenv.isLinux then
                "${pkgs.writeShellScript "playwright-mcp" ''
                  export FONTCONFIG_FILE=${config.nullkomma.fontconfig}
                  exec ${lib.getExe pkgs.playwright-mcp} "$@"
                ''}"
              else
                lib.getExe pkgs.playwright-mcp;
            # The default browser profile would be in the read-only Nix store.
            args = [
              "--headless"
              "--isolated"
            ];
          };
          options.nullkomma.agents.mcpServers = lib.mkOption {
            # Unlike JSON's type, `anything` merges identical definitions from several plugins.
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            description = "MCP servers by name, each with a `type` (`stdio` with `command` and `args`, or `http` with `url`); plugins add here. The `agents` plugin writes them to `.mcp.json`, the `vscode` plugin to `.vscode/mcp.json`; stdio servers start in the dev shell, when enabled.";
          };
          options.nullkomma.agents.generatedMcpServers = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            readOnly = true;
            description = "`mcpServers` as generated configurations list them: with the dev shell enabled, stdio servers start through `nix develop --command`, so they see its environment, by a command on its `PATH`: `mcp-<name>` for a store path.";
          };
          config.nullkomma.agents.generatedMcpServers = lib.mapAttrs (
            name: server:
            if inDevShell && server ? command then
              server
              // {
                command = "nix";
                args = [
                  "develop"
                  "--command"
                  (if stored server then launcher name else server.command)
                ]
                ++ server.args or [ ];
              }
            else
              server
          ) config.nullkomma.agents.mcpServers;
          config.nullkomma.devShell.packages = lib.mkIf inDevShell (
            lib.mapAttrsToList (
              name: server: pkgs.writeShellScriptBin (launcher name) ''exec ${server.command} "$@"''
            ) (lib.filterAttrs (_: stored) config.nullkomma.agents.mcpServers)
          );
        }
      );
      config.nullkomma.gitignore = lib.mkIf browser [ ".playwright-mcp/" ];
    };
  plugins.agents =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.agents;
      inDevShell = config.nullkomma.devShell.enable;
    in
    {
      config = lib.mkIf cfg.enable {
        nullkomma.agents.skills.nk-audit-output = ./_agents/nk-audit-output;
        perSystem =
          { config, pkgs, ... }:
          {
            nullkomma.files = {
              "AGENTS.md" = {
                commentPrefix = "<!--";
                commentSuffix = " -->";
                sections.agents = builtins.readFile ./_agents/AGENTS.md;
              };
              ".mcp.json" = {
                # Without the dev shell, stdio servers start from store paths.
                mode = lib.mkDefault (if inDevShell then "committed" else "generated");
                source = (pkgs.formats.json { }).generate "mcp.json" {
                  mcpServers = config.nullkomma.agents.generatedMcpServers;
                };
              };
            }
            // lib.mapAttrs' (
              name: source:
              lib.nameValuePair ".agents/skills/${name}" {
                inherit source;
                mode = lib.mkDefault "committed";
                directory = true;
              }
            ) cfg.skills;
          };
      };
    };
}
