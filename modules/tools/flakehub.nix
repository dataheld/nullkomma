{
  flake.plugins.flakehub =
    { config, lib, ... }:
    {
      config.perSystem =
        { pkgs, ... }:
        {
          nullkomma.devshell.packages = lib.mkIf config.nullkomma.flakehub.enable [ pkgs.fh ];
        };
    };
}
