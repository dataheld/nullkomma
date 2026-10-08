# Option reference for the exported flakeModules, built as the flake-parts
# ecosystem does it (`nixosOptionsDoc` over an evaluated flake-parts module tree)
# and added to this repo's own Quarto site as `reference.qmd`.
{
  partitions.dev.module =
    {
      inputs,
      lib,
      ...
    }:
    {
      perSystem =
        {
          pkgs,
          system,
          ...
        }:
        let
          evaluated = inputs.flake-parts.lib.evalFlakeModule { inherit inputs; } {
            imports = lib.attrValues (lib.removeAttrs inputs.self.flakeModules [ "flakeModules" ]);
            systems = [ system ];
            perSystem._module.args.pkgs = pkgs;
          };
          repo = "https://github.com/dataheld/nullkomma/blob/main/";
          relative =
            declaration:
            lib.head (lib.splitString "," (lib.removePrefix "${toString inputs.self}/" (toString declaration)));
          optionsDoc = pkgs.nixosOptionsDoc {
            # Only our own namespace: documenting foreign options would need their pkgs.
            options = {
              flake = evaluated.options.nullkomma;
              perSystem = (evaluated.options.perSystem.type.getSubOptions [ "perSystem" ]).nullkomma;
            };
            transformOptions =
              opt:
              opt
              // {
                declarations = map (d: {
                  name = "<nullkomma>/${relative d}";
                  url = repo + relative d;
                }) opt.declarations;
              };
            warningsAreErrors = false;
          };
          reference = pkgs.runCommand "reference.qmd" { } ''
            {
              printf -- '---\ntitle: "Option reference"\n---\n\n'
              printf 'Options of the exported `flakeModules`. Those under `perSystem` are set inside `perSystem = { ... }: { ... }`.\n\n'
              cat ${optionsDoc.optionsCommonMark}
            } > $out
          '';
        in
        {
          packages.docs-reference = reference;
          checks.docs-reference = pkgs.runCommandLocal "nullkomma-docs-reference" { } ''
            for option in \
              nullkomma.github.enable \
              nullkomma.r.extraPackages \
              nullkomma.r.rprofile \
              perSystem.nullkomma.r.snapshot \
              perSystem.nullkomma.r.buildInputs \
              nullkomma.quarto.root \
              nullkomma.cloudflare-pages.project \
              perSystem.nullkomma.tasks \
              perSystem.nullkomma.files \
              perSystem.nullkomma.devshell.packages \
              perSystem.nullkomma.r.package \
              perSystem.nullkomma.quarto.extraFiles
            do
              grep -qF "## $(echo "$option" | sed 's/\./\\./g')" ${reference} || {
                echo "reference is missing option $option" >&2
                exit 1
              }
            done
            touch $out
          '';
          nullkomma.quarto.extraFiles."reference.qmd" = reference;
        };
    };
}
