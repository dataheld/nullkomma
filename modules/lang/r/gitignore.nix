{
  plugins.r =
    { config, lib, ... }:
    {
      config.nullkomma.gitignore = lib.mkIf config.nullkomma.r.enable [
        "*.Rcheck/"
        ".RData"
        ".Rhistory"
        ".Rproj.user/"
        ".Ruserdata"
      ];
    };
}
