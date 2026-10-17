# shellcheck shell=bash
mode="${mode:?file mode must be set by the caller}"
root="$(git rev-parse --show-toplevel)"
cd "$root" || exit 1
state="$(git rev-parse --git-path nullkomma/files)"
accept=""
accepted=false
status=0
if [ "$mode" = source ] && [ "${1:-}" = --accept ] && [ "$#" = 2 ]; then
  accept="$2"
elif [ "$#" != 0 ]; then
  echo "Usage: write-files [--accept <path>] (after resolving a conflict); generate-files takes no arguments" >&2
  exit 1
fi

# shellcheck disable=SC2329 # unused when no file of this mode is enabled
process_file() {
  local path="$1" source="$2" initial="${3:-}" parent base incoming
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
  if [ "$mode" = generated ] && git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
    echo "Refusing to overwrite tracked $path with a generated file; remove it from Git or disable the file in Nix." >&2
    status=1
    return
  fi
  if [ "$mode" = generated ] && [ -d "$source" ]; then
    if [ -e "$path" ] && [ ! -d "$path" ]; then
      echo "Not a directory: $path" >&2
      status=1
      return
    fi
    rm -rf "$path"
    mkdir -p "$(dirname "$path")"
    cp -R "$source" "$path"
    chmod -R u+w "$path"
    echo "generated $path/"
    return
  fi
  if [ -e "$path" ] && [ ! -f "$path" ]; then
    echo "Not a regular file: $path" >&2
    status=1
    return
  fi
  if [ "$mode" = generated ]; then
    mkdir -p "$(dirname "$path")"
    cp --remove-destination "$source" "$path"
    chmod u+w "$path"
    echo "generated $path"
    return
  fi
  base="$state/base/$path"
  incoming="$state/incoming/$path"
  mkdir -p "$(dirname "$base")" "$(dirname "$incoming")"
  if [ ! -f "$base" ] && [ -n "$initial" ] && [ -f "$path" ] && cmp -s "$path" "$initial"; then
    cp "$initial" "$base"
  fi
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
    echo "Not an enabled source-of-truth file: $accept" >&2
    exit 1
  fi
  exit "$status"
}
