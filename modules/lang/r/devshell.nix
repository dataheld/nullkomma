{
  plugins.r =
    { config, lib, ... }:
    {
      config.perSystem = lib.mkIf config.nullkomma.r.enable (
        { config, ... }:
        {
          nullkomma.devHelpers = [ config.nullkomma.r.package ];
        }
      );
    };
}
