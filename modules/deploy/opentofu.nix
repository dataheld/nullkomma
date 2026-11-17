{ inputs, ... }:
{
  plugins.opentofu =
    { config, lib, ... }:
    {
      imports = [ inputs.terranix.flakeModule ];
      config.perSystem = lib.mkIf config.nullkomma.opentofu.enable {
        nullkomma.agents.mcpServers.opentofu = {
          type = "http";
          url = "https://mcp.opentofu.org/mcp";
        };
      };
    };
}
