# Coding agents get always-on rules from a section of the committed AGENTS.md,
# version-specific workflows as Agent Skills (https://agentskills.io) generated from Nix,
# and MCP servers from a generated `.mcp.json`.
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
            command = lib.getExe pkgs.playwright-mcp;
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
            description = "`mcpServers` as generated configurations list them: with the dev shell enabled, stdio servers start through `nix develop --command`, so they see its environment.";
          };
          config.nullkomma.agents.generatedMcpServers = lib.mapAttrs (
            _: server:
            if inDevShell && server ? command then
              server
              // {
                command = "nix";
                args = [
                  "develop"
                  "--command"
                  server.command
                ]
                ++ server.args or [ ];
              }
            else
              server
          ) config.nullkomma.agents.mcpServers;
        }
      );
      config.nullkomma.gitignore = lib.mkIf browser [ ".playwright-mcp/" ];
    };
  plugins.agents =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.agents;
    in
    {
      config = lib.mkIf cfg.enable {
        nullkomma.agents.skills.nk-audit-output = ./_agents/nk-audit-output;
        perSystem =
          { config, ... }:
          {
            nullkomma.files = {
              "AGENTS.md" = {
                commentPrefix = "<!--";
                commentSuffix = " -->";
                sections.agents = builtins.readFile ./_agents/AGENTS.md;
              };
              ".mcp.json" = {
                mode = lib.mkDefault "generated";
                text = builtins.toJSON { mcpServers = config.nullkomma.agents.generatedMcpServers; };
              };
            }
            // lib.mapAttrs' (
              name: source:
              lib.nameValuePair ".agents/skills/${name}" {
                inherit source;
                mode = "generated";
                directory = true;
              }
            ) cfg.skills;
          };
      };
    };
}
