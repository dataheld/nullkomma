# A site's privacy policy, assembled from sections owned by whoever sets up
# the processing: hosting plugins, brand modules or the project itself.
{
  framework =
    { lib, ... }:
    {
      options.nullkomma.privacy = {
        languages = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                code = lib.mkOption {
                  type = lib.types.str;
                  description = "Language code, a key of each section's `markdown`.";
                };
                label = lib.mkOption {
                  type = lib.types.str;
                  description = "Name of the language, in that language.";
                };
              };
            }
          );
          default = [
            {
              code = "en";
              label = "English";
            }
            {
              code = "de";
              label = "Deutsch";
            }
          ];
          description = "Languages of the privacy policy, in display order; every section needs each of them.";
        };
        sections = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule (
              { name, ... }:
              {
                options = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Whether the privacy policy includes `${name}`.";
                  };
                  order = lib.mkOption {
                    type = lib.types.int;
                    default = 500;
                    description = "Position in the policy; lower comes first.";
                  };
                  markdown = lib.mkOption {
                    type = lib.types.attrsOf lib.types.path;
                    description = "Markdown file per language code, starting at heading level 2.";
                  };
                };
              }
            )
          );
          default = { };
          example = lib.literalExpression "{ booking = { order = 400; markdown = { en = ./booking.en.md; de = ./booking.de.md; }; }; }";
          description = "Sections of the site's privacy policy, keyed by name. Plugins add sections for processing they set up; site plugins render them.";
        };
      };
    };
}
