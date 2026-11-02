# Coding agents get always-on rules from a section of the committed AGENTS.md,
# version-specific workflows as Agent Skills (https://agentskills.io) generated from Nix,
# and MCP servers from a generated `.mcp.json`.
{
  framework =
    { flake-parts-lib, lib, ... }:
    {
      options.nullkomma.agents.skills = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
        description = "Agent Skill directories by name, each with a `SKILL.md` whose `name` matches; plugins add here. The `agents` plugin generates them into `.agents/skills/<name>`.";
      };
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { pkgs, ... }:
        {
          options.nullkomma.agents.mcpServers = lib.mkOption {
            type = lib.types.attrsOf (pkgs.formats.json { }).type;
            default = { };
            description = "MCP servers by name, each with a `type` (`stdio` with `command` and `args`, or `http` with `url`); plugins add here. The `agents` plugin writes them to `.mcp.json`, the `vscode` plugin to `.vscode/mcp.json`.";
          };
        }
      );
    };
  plugins.agents =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.agents;
    in
    {
      config = lib.mkIf cfg.enable {
        nullkomma.agents.skills.nk-resolve-file-conflicts = ./_agents/nk-resolve-file-conflicts;
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
                text = builtins.toJSON { mcpServers = config.nullkomma.agents.mcpServers; };
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
