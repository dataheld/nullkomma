# Aspects composing aspects: with flakeModules.r imported too, Quarto renders
# R chunks with the project's R environment (plus knitr and rmarkdown).
{
  flake.flakeModules.quarto =
    { lib, options, ... }:
    {
      # `config = optionalAttrs …`, not `mkIf`: undeclared options must not even be defined.
      config = lib.optionalAttrs (options.nullkomma ? r) {
        nullkomma.r.extraPackages = [
          "knitr"
          "rmarkdown"
        ];
        perSystem =
          { config, ... }:
          {
            nullkomma.quarto.engines = [ config.nullkomma.r.package ];
            nullkomma.devshell.env.QUARTO_R = "${config.nullkomma.r.package}/bin/R";
          };
      };
    };
}
