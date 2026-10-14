{
  plugins.flakehub =
    { config, lib, ... }:
    {
      config.perSystem =
        { pkgs, ... }:
        {
          nullkomma.devHelpers = lib.mkIf config.nullkomma.flakehub.enable [ pkgs.fh ];
        };
    };
}
