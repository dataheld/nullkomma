{
  plugins.flakehub =
    { config, lib, ... }:
    {
      config.perSystem =
        { pkgs, ... }:
        {
          nullkomma.devShell.packages = lib.mkIf config.nullkomma.flakehub.enable [ pkgs.fh ];
        };
    };
}
