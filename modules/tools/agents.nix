# Coding agents get always-on rules from a section of the committed AGENTS.md,
# and version-specific workflows as Agent Skills (https://agentskills.io) generated from Nix.
{
  framework =
    { lib, ... }:
    {
      options.nullkomma.agents.skills = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
        description = "Agent Skill directories by name, each with a `SKILL.md` whose `name` matches; plugins add here. The `agents` plugin generates them into `.agents/skills/<name>`.";
      };
    };
  plugins.agents =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.agents;
    in
    {
      config = lib.mkIf cfg.enable {
        nullkomma.agents.skills.nullkomma-resolve-file-conflicts = ./_agents/nullkomma-resolve-file-conflicts;
        perSystem.nullkomma.files = {
          "AGENTS.md" = {
            commentPrefix = "<!--";
            commentSuffix = " -->";
            sections.agents = builtins.readFile ./_agents/AGENTS.md;
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
}
