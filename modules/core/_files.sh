# shellcheck shell=bash
mode="${mode:?file mode must be set by the caller}"
root="$(git rev-parse --show-toplevel)"
cd "$root" || exit 1
state="$(git rev-parse --git-path nullkomma/files)"
yes=false
accept=""
accepted=false
status=0
case "${1:-}" in
--yes)
  yes=true
  shift
  ;;
--accept-shared)
  if [ "$mode" != shared ] || [ "$#" != 2 ]; then
    echo "Usage: write-files --accept-shared <path> (after reviewing/resolving a conflict)" >&2
    exit 1
  fi
  accept="$2"
  shift 2
  ;;
esac
if [ "$#" != 0 ]; then
  echo "Unexpected arguments; use --yes or write-files --accept-shared <path>" >&2
  exit 1
fi

# shellcheck disable=SC2329 # unused when no file of this mode is enabled
confirm() {
  local answer
  if [ "$yes" = true ]; then
    return 0
  fi
  if [ ! -t 0 ]; then
    echo "Confirmation required; rerun interactively or pass --yes after review." >&2
    return 1
  fi
  read -r -p "$1 [y/N] " answer
  [ "$answer" = y ] || [ "$answer" = Y ]
}

# shellcheck disable=SC2329 # unused when no file of this mode is enabled
process_file() {
  local path="$1" source="$2" parent base incoming exclude pattern
  if [ -n "$accept" ] && [ "$accept" != "$path" ]; then
    return
  fi
  case "$path" in
  "" | /* | . | ./* | */./* | */. | .. | ../* | */../* | */.. | .git | .git/* | *'
'*)
    echo "Unsafe file path: $path" >&2
    status=1
    return
    ;;
  esac
  parent="$path"
  while [ "$parent" != "." ]; do
    if [ -L "$parent" ]; then
      echo "Refusing symlink: $parent" >&2
      status=1
      return
    fi
    parent="$(dirname "$parent")"
  done
  if [ -e "$path" ] && [ ! -f "$path" ]; then
    echo "Not a regular file: $path" >&2
    status=1
    return
  fi
  if [ "$mode" = generated ]; then
    if git --literal-pathspecs ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
      echo "Refusing to generate tracked file $path; migrate edits to Nix, then explicitly untrack it." >&2
      status=1
      return
    fi
    if [ -f "$path" ] && ! cmp -s "$path" "$source"; then
      echo "Nix candidate: $source" >&2
      if ! confirm "Replace Nix-owned $path? Local edits will be lost."; then
        echo "Not replaced: $path" >&2
        status=1
        return
      fi
    fi
    exclude="$(git rev-parse --git-path info/exclude)"
    mkdir -p "$(dirname "$exclude")"
    touch "$exclude"
    pattern="${path//\\/\\\\}"
    pattern="${pattern//\*/\\*}"
    pattern="${pattern//\?/\\?}"
    pattern="${pattern//\[/\\[}"
    if ! grep -qxF "/$pattern" "$exclude"; then
      printf '\n/%s\n' "$pattern" >>"$exclude"
    fi
    if ! git check-ignore --no-index --quiet -- "$path"; then
      echo "Project Git rules prevent ignoring $path; resolve them before generation." >&2
      status=1
      return
    fi
    mkdir -p "$(dirname "$path")"
    cp --remove-destination "$source" "$path"
    chmod a-w "$path"
    echo "generated $path"
    return
  fi
  base="$state/base/$path"
  incoming="$state/incoming/$path"
  mkdir -p "$(dirname "$base")" "$(dirname "$incoming")"
  if [ -n "$accept" ]; then
    if [ ! -f "$path" ]; then
      echo "Resolve or initialize $path before accepting its upstream baseline." >&2
      status=1
      return
    fi
    cp --remove-destination "$source" "$base"
    rm -f "$incoming"
    accepted=true
    echo "accepted upstream baseline for $path; project content preserved"
  elif [ ! -e "$path" ] || cmp -s "$path" "$source" || { [ -f "$base" ] && cmp -s "$path" "$base"; }; then
    mkdir -p "$(dirname "$path")"
    cp "$source" "$path"
    chmod u+w "$path"
    cp --remove-destination "$source" "$base"
    rm -f "$incoming"
    echo "initialized/updated $path"
  elif [ -f "$base" ] && cmp -s "$base" "$source"; then
    echo "kept project edits: $path"
  else
    cp --remove-destination "$source" "$incoming"
    echo "Upstream conflict: $path (project file preserved)." >&2
    echo "Baseline: $base (may be absent); incoming: $incoming" >&2
    echo "Use the resolve-file-conflicts skill: https://github.com/dataheld/nullkomma/blob/main/.github/skills/resolve-file-conflicts/SKILL.md" >&2
    status=1
  fi
}

finish() {
  if [ -n "$accept" ] && [ "$accepted" != true ]; then
    echo "Not an enabled shared file: $accept" >&2
    exit 1
  fi
  exit "$status"
}
