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
      inherit (config.nullkomma) brand privacy;
      prefix = import ../../lib/prefix.nix lib self cfg.root;
      privacyPage = ''

        ---
        title: ${builtins.toJSON privacy.title}
        ---

      ''
      + (
        if lib.length privacy.languages == 1 then
          privacy.policy.${(lib.head privacy.languages).code}
        else
          ''
            ::: {.panel-tabset}
          ''
          + lib.concatMapStrings (language: ''

            # ${language.label}

            ${privacy.policy.${language.code}}
          '') privacy.languages
          + ''

            :::
          ''
      );
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
        renderArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "--no-clean" ];
          description = "Additional arguments to the sandboxed `quarto render` command.";
        };
        privacy.page = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "privacy.qmd";
          description = "Generated page, relative to `root`, rendering `nullkomma.privacy.sections` if there are any; null to write your own.";
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
          options.nullkomma.quarto.runtimeInputs = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            example = lib.literalExpression "[ config.nullkomma.r.package pkgs.texliveSmall ]";
            description = "Execution engines and tools on PATH for rendering, preview and the development shell, e.g. the project's wrapped R and TeX.";
          };
          options.nullkomma.quarto.postRender = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = "Shell checks after a successful sandboxed render, in the Quarto root; render.log holds its output and `$out` holds the rendered site. A failing check fails the build.";
          };
        }
      );
      config = lib.mkIf cfg.enable {
        nullkomma.generatedPaths = [
          "${prefix}.quarto/**"
          "${prefix}_site/**"
        ];
        nullkomma.gitignore = [
          ".quarto/"
          "_site/"
        ];
        perSystem =
          { config, pkgs, ... }:
          let
            quarto = config.nullkomma.quarto.package;
            inherit (config.nullkomma.quarto) runtimeInputs postRender;
            brandExtension = (pkgs.formats.yaml { }).generate "_extension.yml" {
              contributes.metadata.project.brand = "origin/${baseNameOf brand.lib.brand}";
            };
          in
          {
            nullkomma.devShell.packages = [ quarto ] ++ runtimeInputs;
            nullkomma.editor.vscode.extensions = [ "quarto.quarto" ];
            # Quarto watches the working tree and live-reloads the browser itself.
            nullkomma.tasks.preview = {
              skip = true;
              raw = true;
              description = "Serve the site on localhost, re-rendering and reloading on changes";
              packages = [
                pkgs.git
                quarto
              ]
              ++ runtimeInputs;
              command = ''
                ${lib.getExe config.nullkomma.tasks.generate-files.package}
                cd "$(git rev-parse --show-toplevel)"/${lib.escapeShellArg prefix}
                exec quarto preview "$@"
              '';
            };
            nullkomma.files =
              lib.mapAttrs' (
                name: source:
                lib.nameValuePair "${prefix}_extensions/${name}" {
                  mode = "generated";
                  directory = true;
                  inherit source;
                }
              ) cfg.extensions
              // lib.optionalAttrs (brand != null) {
                "${prefix}_brand" = {
                  mode = "generated";
                  directory = true;
                  source = pkgs.runCommand "quarto-brand" { nativeBuildInputs = [ quarto ]; } ''
                    export HOME="$TMPDIR"
                    mkdir source
                    cp ${brandExtension} source/_extension.yml
                    ln -s ${lib.escapeShellArg "${dirOf brand.lib.brand}"} source/origin
                    quarto use brand ./source --force
                    test -f _brand/_brand.yml
                    mv _brand "$out"
                  '';
                };
              }
              // lib.optionalAttrs (cfg.privacy.page != null && privacy.policy != { }) {
                "${prefix}${cfg.privacy.page}" = {
                  mode = "generated";
                  commentPrefix = "<!--";
                  commentSuffix = " -->";
                  text = privacyPage;
                };
              };
            packages.site = lib.mkDefault (
              pkgs.runCommand "site" { nativeBuildInputs = [ quarto ] ++ runtimeInputs; } ''
                set -o pipefail
                cp -r ${config.nullkomma.src} src && chmod -R u+w src && cd src/${lib.escapeShellArg prefix}
                HOME=$TMPDIR quarto render ${lib.escapeShellArgs cfg.renderArgs} --output-dir "$out" 2>&1 | tee render.log
                ${postRender}
              ''
            );
          };
      };
    };
}
