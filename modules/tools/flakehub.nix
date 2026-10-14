{
  flake.plugins.flakehub =
    { config, lib, ... }:
    {
      options.nullkomma.flakehub.enable = lib.mkEnableOption "FlakeHub CLI integration";
      config.perSystem =
        { pkgs, ... }:
        {
          nullkomma.devshell.packages = lib.mkIf config.nullkomma.flakehub.enable [ pkgs.fh ];
        };
    };
}
