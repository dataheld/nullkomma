# Every file has one author: Nix for links, the project for project files.
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
            description = "Project files, keyed by path from the flake's directory: `write-files` creates missing ones, and the `project-files` check lists the lines nullkomma requires that a file lacks.";
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
          links = lib.mapAttrs (_: f: f.source) (enabled config.nullkomma.links);
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
          lacking = ''
            # Prints the non-blank lines of $2 that file $1 lacks.
            lacking() { grep -Fxv -e "" -f "$1" "$2" || [ "$?" = 1 ]; }
          '';
          write =
            script "write-files"
              [
                pkgs.coreutils
                pkgs.git
                pkgs.gnugrep
              ]
              (
                lacking
                + ''
                  status=0
                  overwrite=()
                  if [ "''${1-}" = --overwrite ] && [ "$#" -gt 1 ]; then
                    overwrite=("''${@:2}")
                  elif [ "$#" != 0 ]; then
                    echo "Usage: write-files [--overwrite <file>...]; nk project-files lists the files that lack lines." >&2
                    exit 1
                  fi
                  among() {
                    local item
                    for item in "''${@:2}"; do
                      [ "$item" = "$1" ] && return
                    done
                    return 1
                  }
                  for path in "''${overwrite[@]}"; do
                    if ! among "$path" ${lib.escapeShellArgs (lib.attrNames files)}; then
                      echo "Not overwritten: $path, as nullkomma requires no lines in it." >&2
                      status=1
                    fi
                  done
                  write() {
                    if [ -e "$1" ]; then
                      among "$1" "''${overwrite[@]}" || return 0
                      if [ -z "$(lacking "$1" "$2")" ]; then
                        echo "kept $1, which has every line nullkomma requires"
                        return
                      fi
                      # Git keeps what the project had, for reconciling with `git diff`.
                      if ! git ls-files --error-unmatch -- "$1" >/dev/null 2>&1 || ! git diff --quiet HEAD -- "$1" 2>/dev/null; then
                        echo "Not overwritten: $1, as Git could not restore it; commit it first." >&2
                        status=1
                        return
                      fi
                    fi
                    mkdir -p "$(dirname "$1")"
                    install -m 644 "$2" "$1"
                    echo "wrote $1"
                  }
                ''
                + forFiles "write"
                + "exit \"$status\"\n"
              );
          check = script "project-files" [ pkgs.gnugrep ] (
            lacking
            + ''
              status=0
              require() {
                local missing
                if [ ! -f "$1" ]; then
                  echo "$1 is missing or untracked; nk write-files creates it, git add tracks it." >&2
                  status=1
                  return
                fi
                missing="$(lacking "$1" "$2")"
                if [ -n "$missing" ]; then
                  printf '%s lacks lines nullkomma requires; add them where they fit, or see nk write-files --overwrite:\n%s\n' "$1" "$missing" >&2
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
          # As in the working tree, a place the project took stays the project's.
          nullkomma.src = pkgs.runCommand "source" { } ''
            cp -R ${self} "$out"
            chmod -R u+w "$out"
            cp -RL --update=none ${bundle}/. "$out" || true
          '';
          process-compose.dev.settings.processes = {
            link-files = task "Link nullkomma's files from the Nix store; entering the dev shell does this too" link;
            write-files = task "Create missing project files; --overwrite <file>... replaces committed ones that lack lines, to reconcile with git diff" write;
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
