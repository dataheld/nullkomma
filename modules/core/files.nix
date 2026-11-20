# Files are either a source of truth (written once, then committed and edited, except for
# nullkomma's marked sections) or generated from Nix (overwritten on every run):
# Git-ignored, or committed when programs read them on opening a checkout,
# before anything can enter the dev shell.
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
                    "committed"
                  ];
                  default = "source";
                  description = "`source`: written by `write-files` if absent, then committed and the project's, except for its `sections`. `generated`: written from Nix by `generate-files` (also on entering the dev shell), overwritten when changed, and only if Git ignores it. `committed`: generated likewise, but committed, for programs that read it on opening a checkout, before the dev shell exists; written only if Git does not ignore it. Its content must be the same on every system; the `generate-files-check` check fails when the file differs from Nix.";
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
                  description = "Whether `source` is a directory, copied whole and without a header; a `generated` one gets its own `.gitignore`. Generated and committed files only.";
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
            description = "Files written into the project, keyed by path from the flake's directory.";
          };
          options.nullkomma.src = lib.mkOption {
            type = lib.types.package;
            readOnly = true;
            description = "The flake's source with every Git-ignored generated file in place, as after `generate-files`: where sandboxed checks and site builds start. Committed files are as Git has them.";
          };
          options.nullkomma.root = lib.mkOption {
            type = lib.types.str;
            readOnly = true;
            description = "Shell word for the flake's directory in the working tree: Git's top level, or the directory below it that holds `flake.nix`. Tasks, the task runner and the dev shell work there.";
          };
        }
      );
      config.perSystem =
        { config, pkgs, ... }:
        let
          # `/<dir>` for a flake below its repository's root, else empty; only the text, so
          # scripts don't depend on the source.
          directory = builtins.unsafeDiscardStringContext (
            lib.removePrefix (toString (self.sourceInfo.outPath or self.outPath)) (toString self.outPath)
          );
          files = lib.filterAttrs (_: f: f.enable) config.nullkomma.files;
          ofMode = mode: lib.filterAttrs (_: f: f.mode == mode) files;
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
                  (
                    if builtins.isString section then
                      pkgs.writeText "nullkomma-section-${name}" section
                    else
                      "${section}"
                  )
                ]) f.sections
              )
            );
          generated = lib.mapAttrs (
            path: f:
            if f.directory then
              # An ignored directory stays ignored whatever the root `.gitignore` says,
              # as `python -m venv` does.
              pkgs.runCommandLocal "nullkomma-generated-${baseNameOf path}" { } (
                ''
                  cp -R ${f.source} "$out"
                  chmod -R u+w "$out"
                ''
                + lib.optionalString (f.mode == "generated") ''
                  echo '*' > "$out/.gitignore"
                ''
              )
            else if f.commentPrefix == null then
              f.source
            else
              pkgs.concatText "nullkomma-generated-${baseNameOf path}" [
                (pkgs.writeText "nullkomma-warning" ''
                  ${f.commentPrefix} Generated by nullkomma. DO NOT EDIT; change the Nix configuration.${f.commentSuffix}
                '')
                f.source
              ]
          ) (lib.filterAttrs (_: f: f.mode != "source") files);
          script =
            name: modes:
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
                mode=${lib.head modes}
                sections=${./_sections.awk}
                root=${config.nullkomma.root}
                manifest=${lib.escapeShellArg "nullkomma/files/generated${lib.escapeURL directory}"}
                committed_manifest=${lib.escapeShellArg "nullkomma/files/committed${lib.escapeURL directory}"}
              ''
              + builtins.readFile ./_files.sh
              + lib.concatStrings (
                lib.mapAttrsToList (
                  path: f:
                  assert lib.assertMsg (
                    !f.directory || f.mode != "source"
                  ) "Directory ${path} must be a generated or committed file.";
                  if !lib.elem f.mode modes then
                    ''
                      declare_file ${lib.escapeShellArg path}
                    ''
                  else if f.sections != { } then
                    ''
                      splice_file ${lib.escapeShellArg path} ${splice path f}
                    ''
                  else
                    ''
                      process_file ${
                        lib.escapeShellArgs [
                          path
                          "${generated.${path} or f.source}"
                          f.mode
                        ]
                      }
                    ''
                ) files
              )
              + ''
                finish
              '';
            };
          write = script "write-files" [ "source" ];
          generate = script "generate-files" [
            "generated"
            "committed"
          ];
          committed = lib.intersectAttrs (ofMode "committed") generated;
          task = description: command: {
            namespace = "nullkomma";
            inherit description command;
            disabled = true;
          };
        in
        {
          nullkomma.root = ''"$(${lib.getExe pkgs.git} rev-parse --show-toplevel)"${lib.escapeShellArg directory}'';
          nullkomma.src = pkgs.runCommand "source" { } (
            ''
              cp -R ${self} "$out"
              chmod -R u+w "$out"
            ''
            + lib.concatStrings (
              lib.mapAttrsToList (path: _: ''
                rm -rf "$out"/${lib.escapeShellArg path}
                mkdir -p "$out"/${lib.escapeShellArg (dirOf path)}
                cp -R ${generated.${path}} "$out"/${lib.escapeShellArg path}
                chmod -R u+w "$out"/${lib.escapeShellArg path}
              '') (ofMode "generated")
            )
          );
          process-compose.dev.settings.processes = {
            write-files = task "Update the files nullkomma committed, keeping your edits" write;
            generate-files = task "Regenerate the files nullkomma generates from Nix; entering the dev shell does this too" generate;
            generate-files-check = lib.mkIf (committed != { }) (
              task "Check that the committed generated files match Nix" (
                pkgs.writeShellApplication {
                  name = "generate-files-check";
                  runtimeInputs = [ pkgs.diffutils ];
                  text = ''
                    status=0
                  ''
                  + lib.concatStrings (
                    lib.mapAttrsToList (path: source: ''
                      diff -r ${source} ${lib.escapeShellArg path} || {
                        echo ${lib.escapeShellArg "${path} differs from the Nix configuration; run nk generate-files and commit it."} >&2
                        status=1
                      }
                    '') committed
                  )
                  + ''
                    exit "$status"
                  '';
                }
              )
            );
            check.depends_on = lib.mkIf (committed != { }) {
              generate-files-check.condition = "process_completed_successfully";
            };
          };
          # Generated files follow the Nix configuration, not the working tree:
          # refresh them on entering the dev shell (direnv re-enters when the flake changes).
          # A refusal is reported, but does not stop the shell.
          nullkomma.devShell.shellHook = lib.mkIf (generated != { }) "${lib.getExe generate} || true";
        };
    };
}
