# Files are either a source of truth (written once, then committed and edited, except for
# nullkomma's marked sections) or generated from Nix (overwritten on every run and Git-ignored).
{
  framework =
    {
      flake-parts-lib,
      lib,
      self,
      ...
    }:
    {
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { pkgs, ... }:
        let
          fileModule =
            { name, config, ... }:
            {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to write `${name}`.";
                };
                mode = lib.mkOption {
                  type = lib.types.enum [
                    "source"
                    "generated"
                  ];
                  default = "source";
                  description = "`source`: written by `write-files` if absent, then committed and the project's, except for its `sections`. `generated`: written from Nix by `generate-files` (also on entering the dev shell), overwritten when changed, and only if Git ignores it.";
                };
                commentPrefix = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Line-comment prefix for the \"do not edit\" header of generated files (for example // for JSONC) and for section markers; without it, generated files get no header. Required for sections.";
                };
                commentSuffix = lib.mkOption {
                  type = lib.types.str;
                  default = "";
                  description = "Closes the header comment and section markers, for formats without line comments (for example ` -->` with `<!--`).";
                };
                directory = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Whether `source` is a directory, copied whole and without a header, with its own `.gitignore`. Generated files only.";
                };
                text = lib.mkOption {
                  type = lib.types.nullOr lib.types.lines;
                  default = null;
                  description = "File content; sets `source`.";
                };
                source = lib.mkOption {
                  type = lib.types.path;
                  description = "Store path whose content is written to `${name}`.";
                };
                sections = lib.mkOption {
                  type = lib.types.attrsOf (lib.types.either lib.types.lines lib.types.path);
                  default = { };
                  description = "Marked sections nullkomma owns inside an otherwise project-owned source file, by name, as text or file: replaced in place, else appended, and removed once undeclared. A file without markers that equals the sections' plain text gets them marked. Needs `commentPrefix`.";
                };
              };
              config.source = lib.mkIf (config.text != null) (
                pkgs.writeText "nullkomma-${lib.replaceStrings [ "/" ] [ "-" ] name}" config.text
              );
            };
        in
        {
          options.nullkomma.files = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule fileModule);
            default = { };
            description = "Files written into the project, keyed by repo-relative path.";
          };
          options.nullkomma.src = lib.mkOption {
            type = lib.types.package;
            readOnly = true;
            description = "The flake's source with every generated file in place, as after `generate-files`: where sandboxed checks and site builds start.";
          };
        }
      );
      config.perSystem =
        { config, pkgs, ... }:
        let
          files = lib.filterAttrs (_: f: f.enable) config.nullkomma.files;
          # `splice`'s arguments for a file's sections.
          splice =
            path: f:
            assert lib.assertMsg (
              f.commentPrefix != null
            ) "File ${path} needs a commentPrefix for its sections.";
            lib.escapeShellArgs (
              [
                f.commentPrefix
                f.commentSuffix
              ]
              ++ lib.concatLists (
                lib.mapAttrsToList (name: section: [
                  name
                  (if builtins.isString section then pkgs.writeText "nullkomma-section-${name}" section else section)
                ]) f.sections
              )
            );
          generated = lib.mapAttrs (
            path: f:
            if f.directory then
              # Stays ignored whatever the root `.gitignore` says, as `python -m venv` does.
              pkgs.runCommandLocal "nullkomma-generated-${baseNameOf path}" { } ''
                cp -R ${f.source} "$out"
                chmod -R u+w "$out"
                echo '*' > "$out/.gitignore"
              ''
            else if f.commentPrefix == null then
              f.source
            else
              pkgs.concatText "nullkomma-generated-${baseNameOf path}" [
                (pkgs.writeText "nullkomma-warning" ''
                  ${f.commentPrefix} Generated by nullkomma. DO NOT EDIT; change the Nix configuration.${f.commentSuffix}
                '')
                f.source
              ]
          ) (lib.filterAttrs (_: f: f.mode == "generated") files);
          script =
            name: mode:
            pkgs.writeShellApplication {
              inherit name;
              # Functions run once per declared file, which may be none.
              excludeShellChecks = [ "SC2329" ];
              runtimeInputs = [
                pkgs.coreutils
                pkgs.gawk
                pkgs.git
              ];
              text = ''
                mode=${mode}
                sections=${./_sections.awk}
              ''
              + builtins.readFile ./_files.sh
              + lib.concatStrings (
                lib.mapAttrsToList (
                  path: f:
                  assert lib.assertMsg (
                    !f.directory || f.mode == "generated"
                  ) "Directory ${path} must be a generated file.";
                  if f.mode != mode then
                    ''
                      declare_file ${lib.escapeShellArg path}
                    ''
                  else if f.sections != { } then
                    ''
                      splice_file ${lib.escapeShellArg path} ${splice path f}
                    ''
                  else
                    ''
                      process_file ${lib.escapeShellArg path} ${lib.escapeShellArg "${if mode == "generated" then generated.${path} else f.source}"}
                    ''
                ) files
              )
              + ''
                finish
              '';
            };
          write = script "write-files" "source";
          generate = script "generate-files" "generated";
          task = description: command: {
            namespace = "nullkomma";
            inherit description command;
            disabled = true;
          };
        in
        {
          nullkomma.src = pkgs.runCommand "source" { } (
            ''
              cp -R ${self} "$out"
              chmod -R u+w "$out"
            ''
            + lib.concatStrings (
              lib.mapAttrsToList (path: source: ''
                rm -rf "$out"/${lib.escapeShellArg path}
                mkdir -p "$out"/${lib.escapeShellArg (dirOf path)}
                cp -R ${source} "$out"/${lib.escapeShellArg path}
                chmod -R u+w "$out"/${lib.escapeShellArg path}
              '') generated
            )
          );
          process-compose.dev.settings.processes = {
            write-files = task "Update the files nullkomma committed, keeping your edits" write;
            generate-files = task "Regenerate nullkomma's Git-ignored files; entering the dev shell does this too" generate;
          };
          # Generated files follow the Nix configuration, not the working tree:
          # refresh them on entering the dev shell (direnv re-enters when the flake changes).
          nullkomma.devShell.shellHook = lib.mkIf (generated != { }) (lib.getExe generate);
        };
    };
}
