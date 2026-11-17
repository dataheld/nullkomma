{ inputs, ... }:
{
  plugins.opentofu =
    { config, lib, ... }:
    {
      imports = [ inputs.terranix.flakeModule ];
      config = lib.mkIf config.nullkomma.opentofu.enable {
        perSystem.nullkomma.agents.mcpServers.opentofu = {
          type = "http";
          url = "https://mcp.opentofu.org/mcp";
        };
      };
    };
}
