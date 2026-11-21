# Every file has one author.
# Links are Nix's: read-only links into the Nix store, Git-ignored, refreshed on entering the dev shell.
# Project files are the project's: nullkomma creates missing ones on request,
# then only checks that they keep the lines it requires.
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
          content =
            description:
            lib.types.attrsOf (
              lib.types.submodule (
                { name, config, ... }:
                {
                  options = {
                    enable = lib.mkEnableOption "`${name}`" // {
                      default = true;
                    };
                    text = lib.mkOption {
                      type = lib.types.nullOr lib.types.lines;
                      default = null;
                      description = "Content; sets `source`.";
                    };
                    source = lib.mkOption {
                      type = lib.types.path;
                      inherit description;
                    };
                  };
                  config.source = lib.mkIf (config.text != null) (
                    pkgs.writeText "nullkomma-${lib.replaceStrings [ "/" ] [ "-" ] name}" config.text
                  );
                }
              )
            );
        in
        {
          options.nullkomma.links = lib.mkOption {
            type = content "Store path, a file or directory, that the link points to.";
            default = { };
            description = "Files from Nix, keyed by path from the flake's directory: linked read-only into the Nix store on entering the dev shell, if Git ignores the path and nothing else is there.";
          };
          options.nullkomma.files = lib.mkOption {
            type = content "Lines nullkomma requires in the file.";
            default = { };
            description = "Project files, keyed by path from the flake's directory: `write-files` creates missing ones, and the `project-files` check lists the lines nullkomma requires that a file lacks. nullkomma never changes an existing file.";
          };
          options.nullkomma.src = lib.mkOption {
            type = lib.types.package;
            readOnly = true;
            description = "The flake's source with the targets of all links in place: where sandboxed checks and site builds start.";
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
          enabled = lib.filterAttrs (
            path: f:
            assert lib.assertMsg (
              !lib.hasPrefix "/" path && !lib.elem ".." (lib.splitString "/" path)
            ) "nullkomma path ${path} must stay inside the flake's directory.";
            f.enable
          );
          links =
            assert lib.assertMsg (lib.intersectAttrs config.nullkomma.links config.nullkomma.files == { })
              "nullkomma paths ${toString (lib.attrNames (lib.intersectAttrs config.nullkomma.links config.nullkomma.files))} are links; to own one, set perSystem.nullkomma.links.<path>.enable = false.";
            lib.mapAttrs (_: f: f.source) (enabled config.nullkomma.links);
          files = enabled config.nullkomma.files;
          # Links point into it at their own path, which marks them as nullkomma's.
          bundle = pkgs.linkFarm "nullkomma-links" links;
          script =
            name: runtimeInputs: text:
            pkgs.writeShellApplication {
              inherit name runtimeInputs;
              # Functions run once per declared file, which may be none.
              excludeShellChecks = [ "SC2329" ];
              inherit text;
            };
          forFiles =
            command:
            lib.concatMapAttrsStringSep "" (
              path: f: "${command} ${lib.escapeShellArg path} ${f.source}\n"
            ) files;
          # The dev shell runs it from wherever it was entered; tasks run in the root already.
          link = script "link-files" [ pkgs.coreutils pkgs.findutils pkgs.git ] (
            ''
              git rev-parse --git-dir >/dev/null 2>&1 || exit 0
              cd ${config.nullkomma.root}
              bundle=${bundle}
            ''
            + builtins.readFile ./_links.sh
            + "prune\n"
            + lib.concatMapStrings (path: "link ${lib.escapeShellArg path}\n") (lib.attrNames links)
            + "finish\n"
          );
          write = script "write-files" [ pkgs.coreutils ] (
            ''
              write() {
                [ -e "$1" ] && return
                mkdir -p "$(dirname "$1")"
                install -m 644 "$2" "$1"
                echo "wrote $1"
              }
            ''
            + forFiles "write"
          );
          check = script "project-files" [ pkgs.gnugrep ] (
            ''
              status=0
              require() {
                local missing
                if [ ! -f "$1" ]; then
                  echo "$1 is missing; nk write-files creates it." >&2
                  status=1
                  return
                fi
                missing="$(grep -Fxv -f "$1" "$2")" || [ "$?" = 1 ]
                missing="$(grep -v '^$' <<<"$missing")" || true
                if [ -n "$missing" ]; then
                  printf '%s lacks lines nullkomma requires; add them where they fit:\n%s\n' "$1" "$missing" >&2
                  status=1
                fi
              }
            ''
            + forFiles "require"
            + "exit \"$status\"\n"
          );
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
            # As in the working tree, a place the project took stays the project's.
            + ''
              cd ${bundle}
              find -L . -type f -printf '%P\0' | while IFS= read -r -d "" file; do
                target="$out/$file"
                parent="$(dirname "$target")"
                while [ "$parent" != "$out" ] && [ ! -L "$parent" ] && { [ -d "$parent" ] || [ ! -e "$parent" ]; }; do
                  parent="$(dirname "$parent")"
                done
                if [ "$parent" = "$out" ] && [ ! -e "$target" ] && [ ! -L "$target" ]; then
                  mkdir -p "$(dirname "$target")"
                  cp -L "$file" "$target"
                fi
              done
              chmod -R u+w "$out"
            ''
          );
          process-compose.dev.settings.processes = {
            link-files = task "Link nullkomma's files from the Nix store; entering the dev shell does this too" link;
            write-files = task "Create the project files nullkomma requires that are missing; it changes no existing file" write;
            project-files = lib.mkIf (files != { }) (
              task "Check that project files have the lines nullkomma requires" check
            );
            check.depends_on = lib.mkIf (files != { }) {
              project-files.condition = "process_completed_successfully";
            };
          };
          # Re-entering the dev shell, as direnv does when the flake changes, follows the Nix configuration.
          # A refusal is reported, but does not stop the shell.
          nullkomma.devShell.shellHook = lib.mkIf (links != { }) "${lib.getExe link} || true";
        };
    };
}
