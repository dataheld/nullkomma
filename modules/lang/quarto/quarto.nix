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
      prefix = import ../../../lib/prefix.nix lib self cfg.root;
      ignored = [
        ".quarto/"
        "_site/"
        # Quarto's Lua editor hints, pointing at its store path.
        ".luarc.json"
      ];
      privacyPage = ''

        ---
        title: ${builtins.toJSON privacy.title}
        sidebar: false
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
          description = "Quarto project rendered into `packages.site` and served by the `quarto-preview` task.";
        };
        extensions = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          example = lib.literalExpression ''{ my-brand = inputs.my-brand + "/_extensions/my-brand"; }'';
          description = "Quarto extensions by name, placed in `_extensions/<name>` (generated and Git-ignored) and in the build.";
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
              # shortcut: `patches` and `postPatch` make Nixpkgs 26.05's Quarto 1.9 work with
              # its Pandoc 3.7; drop them once NixOS/nixpkgs#569134 reaches our pin, see
              # https://github.com/dataheld/nullkomma/issues/212.
              patches = (old.patches or [ ]) ++ [ ../../../patches/quarto.patch ];
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
        # nkdocs, a Quarto extension contributing a project type: stock Quarto docs features, nothing brand-specific.
        nullkomma.quarto.extensions.nkdocs = ./_nkdocs;
        nullkomma.generatedPaths = [
          "${prefix}.quarto/**"
          "${prefix}_site/**"
          "${prefix}.luarc.json"
        ];
        nullkomma.gitignore = ignored;
        perSystem =
          { config, pkgs, ... }:
          let
            quarto = config.nullkomma.quarto.package;
            quartoProcess = description: command: {
              namespace = "quarto";
              inherit description;
              working_dir = "./${prefix}";
              command = pkgs.writeShellApplication {
                name = "quarto-${command}";
                runtimeInputs = [ quarto ];
                text = ''exec quarto ${command} "$@"'';
              };
            };
          in
          {
            nullkomma.devShell.packages = [ quarto ];
            nullkomma.editor.vscode.extensions = [ "quarto.quarto" ];
            process-compose.dev.settings.processes = {
              quarto-render = quartoProcess "Render the Quarto site" "render" // {
                disabled = true;
                watch.paths = [
                  {
                    path = ".";
                    # Quarto writes `<page>.html`, `<page>_files/` and `site_libs/`
                    # beside the sources before moving them into `_site/`.
                    exclude = map (lib.removeSuffix "/") ignored ++ [
                      "*.html"
                      "*_files"
                      "site_libs"
                    ];
                  }
                ];
              };
              all.depends_on.quarto-render.condition = "process_completed_successfully";
              # Not `quarto preview`: it renders a page only when it is opened,
              # and misses changes to included files (quarto-dev/quarto-cli#2795).
              quarto-preview = {
                namespace = "quarto";
                description = "Format, lint and render the site, then serve it on localhost; re-render and reload on changes";
                working_dir = "./${prefix}";
                # live-server fails if `_site` does not exist yet.
                command = "mkdir -p _site && ${lib.getExe pkgs.live-server} _site --host 127.0.0.1 --open";
                depends_on = {
                  treefmt.condition = "process_completed";
                  # Serve the last site even if a render fails.
                  quarto-render.condition = "process_completed";
                };
              };
            };
            packages.site = lib.mkDefault (
              config.nullkomma.sandbox {
                process = "quarto-render";
                output = "${prefix}_site";
              }
            );
            nullkomma.files =
              lib.mapAttrs' (
                name: source:
                lib.nameValuePair "${prefix}_extensions/${name}" {
                  mode = "generated";
                  directory = true;
                  inherit source;
                }
              ) cfg.extensions
              // lib.optionalAttrs (cfg.privacy.page != null && privacy.policy != { }) {
                "${prefix}${cfg.privacy.page}" = {
                  mode = "generated";
                  commentPrefix = "<!--";
                  commentSuffix = " -->";
                  text = privacyPage;
                };
              };
          };
      };
    };
}
