# A site's privacy policy, assembled from sections owned by whoever sets up
# the processing: hosting plugins, brand modules or the project itself.
{
  framework =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.privacy;
      sections = lib.sort (a: b: a.order < b.order) (
        lib.filter (s: s.enable) (lib.attrValues cfg.sections)
      );
    in
    {
      options.nullkomma.privacy = {
        title = lib.mkOption {
          type = lib.types.str;
          default = "Privacy Policy";
          description = "Title of the privacy page that site plugins generate.";
        };
        policy = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          readOnly = true;
          description = "The policy's Markdown by language code: the enabled sections, in order; empty without sections. Site plugins wrap it in their page format.";
        };
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
      config.nullkomma.privacy.policy = lib.optionalAttrs (sections != [ ]) (
        lib.genAttrs (map (l: l.code) cfg.languages) (
          code:
          lib.concatMapStringsSep "\n" (
            s:
            builtins.readFile (
              s.markdown.${code}
                or (throw "Privacy section is missing language `${code}`: ${toString (lib.attrValues s.markdown)}")
            )
          ) sections
        )
      );
    };
}
