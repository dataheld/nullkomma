{
  plugins.quarto =
    {
      config,
      flake-parts-lib,
      lib,
      self,
      ...
    }:
    let
      cfg = config.nullkomma.quarto;
      inherit (config.nullkomma) privacy;
      sections = lib.sort (a: b: a.order < b.order) (
        lib.attrValues (lib.filterAttrs (_: s: s.enable) privacy.sections)
      );
      section =
        code: s:
        s.markdown.${code}
          or (throw "Privacy section is missing language `${code}`: ${toString (lib.attrValues s.markdown)}");
      policy = code: lib.concatMapStringsSep "\n" (s: builtins.readFile (section code s)) sections;
      privacyPage = ''

        ---
        title: ${builtins.toJSON cfg.privacy.title}
        ---

      ''
      + (
        if lib.length privacy.languages == 1 then
          policy (lib.head privacy.languages).code
        else
          ''
            ::: {.panel-tabset}
          ''
          + lib.concatMapStrings (language: ''

            # ${language.label}

            ${policy language.code}
          '') privacy.languages
          + ''

            :::
          ''
      );
      hasPrivacyPage = cfg.privacy.page != null && sections != [ ];
    in
    {
      options.nullkomma.quarto = {
        root = lib.mkOption {
          type = lib.types.path;
          default = self.outPath;
          defaultText = lib.literalExpression "self.outPath";
          description = "Quarto project rendered into `packages.site` and served by the `preview` task.";
        };
        extensions = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          example = lib.literalExpression ''{ my-brand = inputs.my-brand + "/_extensions/my-brand"; }'';
          description = "Quarto extensions by name, placed in `_extensions/<name>` (generated and Git-ignored) and in the build.";
        };
        privacy = {
          page = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = "privacy.qmd";
            description = "Generated page rendering `nullkomma.privacy.sections`, if there are any; null to write your own.";
          };
          title = lib.mkOption {
            type = lib.types.str;
            default = "Privacy Policy";
            description = "Title of the generated privacy page.";
          };
        };
      };
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { pkgs, ... }:
        {
          options.nullkomma.quarto.package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.quartoMinimal.overrideAttrs (old: {
              # Nixpkgs' Quarto 1.9 emits a key its newer Pandoc no longer accepts.
              postPatch = (old.postPatch or "") + ''
                substituteInPlace bin/quarto.js --replace-fail syntax-highlighting highlight-style
              '';
              postFixup = (old.postFixup or "") + ''
                wrapProgram $out/bin/quarto --prefix PATH : ${lib.makeBinPath [ pkgs.which ]}
              '';
            });
            defaultText = lib.literalMD "`pkgs.quartoMinimal`, patched for Nixpkgs' Pandoc";
            description = "Quarto, without R, Python or TeX; override to add execution engines.";
          };
        }
      );
      config = lib.mkIf cfg.enable {
        nullkomma.generatedPaths =
          let
            root = lib.removePrefix "${toString self}/" "${toString cfg.root}/";
          in
          [
            "${root}.quarto/**"
            "${root}_site/**"
          ];
        nullkomma.gitignore = [
          ".quarto/"
          "_site/"
        ];
        perSystem =
          { config, pkgs, ... }:
          let
            quarto = config.nullkomma.quarto.package;
            page = pkgs.writeText "privacy.qmd" privacyPage;
            rootInRepo =
              assert lib.assertMsg (lib.hasPrefix (toString self) (
                toString cfg.root
              )) "nullkomma.quarto.root must be inside the flake for the preview task.";
              lib.removePrefix (toString self) (toString cfg.root);
          in
          {
            nullkomma.devHelpers = [ quarto ];
            nullkomma.editor.vscode.extensions = [ "quarto.quarto" ];
            # Quarto watches the working tree and live-reloads the browser itself.
            nullkomma.tasks.preview = {
              skip = true;
              raw = true;
              description = "Serve the site on localhost, re-rendering and reloading on changes";
              packages = [
                pkgs.git
                quarto
              ];
              command = ''
                cd "$(git rev-parse --show-toplevel)"${lib.escapeShellArg rootInRepo}
                exec quarto preview "$@"
              '';
            };
            nullkomma.files =
              lib.mapAttrs' (
                name: source:
                lib.nameValuePair "_extensions/${name}" {
                  mode = "generated";
                  directory = true;
                  inherit source;
                }
              ) cfg.extensions
              // lib.optionalAttrs hasPrivacyPage {
                ${cfg.privacy.page} = {
                  mode = "generated";
                  commentPrefix = "<!--";
                  commentSuffix = " -->";
                  text = privacyPage;
                };
              };
            packages.site = lib.mkDefault (
              pkgs.runCommand "site" { nativeBuildInputs = [ quarto ]; } (
                ''
                  cp -r ${cfg.root} src && chmod -R u+w src && cd src
                ''
                + lib.concatStrings (
                  lib.mapAttrsToList (name: source: ''
                    rm -rf _extensions/${lib.escapeShellArg name}
                    mkdir -p _extensions
                    cp -r ${source} _extensions/${lib.escapeShellArg name}
                  '') cfg.extensions
                )
                + lib.optionalString hasPrivacyPage ''
                  page=${lib.escapeShellArg cfg.privacy.page}
                  if [ -e "$page" ] && ! head -n 1 "$page" | grep -q '^<!-- Generated by nullkomma'; then
                    echo "$page is generated from nullkomma.privacy.sections; remove it or set nullkomma.quarto.privacy.page = null." >&2
                    exit 1
                  fi
                  cp --remove-destination ${page} "$page"
                ''
                + ''
                  chmod -R u+w .
                  HOME=$TMPDIR quarto render --output-dir "$out"
                ''
              )
            );
          };
      };
    };
}
