{
  plugins.cloudflare =
    { config, lib, ... }:
    {
      config.perSystem = lib.mkIf config.nullkomma.cloudflare.enable (
        { pkgs, ... }:
        {
          nullkomma.devShell.packages = [ pkgs.wrangler ];
          nullkomma.agents.mcpServers = {
            cloudflare-api = {
              type = "http";
              url = "https://mcp.cloudflare.com/mcp";
            };
            cloudflare-docs = {
              type = "http";
              url = "https://docs.mcp.cloudflare.com/mcp";
            };
          };
        }
      );
    };
}
