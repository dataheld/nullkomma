# shellcheck shell=bash
mode="${mode:?file mode must be set by the caller}"
root="$(git rev-parse --show-toplevel)"
cd "$root" || exit 1
state="$(git rev-parse --git-path nullkomma/files)"
accept=""
accepted=false
status=0
declared=()
if [ "$mode" = source ] && [ "${1:-}" = --accept ] && [ "$#" = 2 ]; then
  accept="$2"
elif [ "$#" != 0 ]; then
  echo "Usage: nk-write-files [--accept <path>] (after resolving a conflict); nk-generate-files takes no arguments" >&2
  exit 1
fi

safe_path() {
  local parent="$1"
  case "$1" in
  "" | /* | . | ./* | */./* | */. | .. | ../* | */../* | */.. | .git | .git/* | *'
'*)
    echo "Unsafe file path: $1" >&2
    status=1
    return 1
    ;;
  esac
  while [ "$parent" != "." ]; do
    if [ -L "$parent" ]; then
      echo "Refusing symlink: $parent" >&2
      status=1
      return 1
    fi
    parent="$(dirname "$parent")"
  done
}

# shellcheck disable=SC2329 # unused when no file of this mode is enabled
process_file() {
  local path="$1" source="$2" initial="${3:-}" base incoming
  if [ -n "$accept" ] && [ "$accept" != "$path" ]; then
    return
  fi
  safe_path "$path" || return
  declared+=("$path")
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
    # Rewriting unchanged files bumps mtimes, so e.g. `quarto preview` re-renders and opens them.
    diff -r "$source" "$path" >/dev/null 2>&1 && return
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
    cmp -s "$source" "$path" && return
    mkdir -p "$(dirname "$path")"
    cp --remove-destination "$source" "$path"
    chmod u+w "$path"
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
  elif [ ! -e "$path" ] || cmp -s "$path" "$source" || { [ -f "$base" ] && cmp -s "$path" "$base"; } ||
    { [ -n "$initial" ] && cmp -s "$path" "$initial"; }; then
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
    echo "Use the nullkomma-resolve-file-conflicts skill: https://github.com/dataheld/nullkomma/blob/main/modules/tools/_agents/nullkomma-resolve-file-conflicts/SKILL.md" >&2
    status=1
  fi
}

is_declared() {
  local p
  for p in "${declared[@]}"; do
    [ "$p" = "$1" ] && return 0
  done
  return 1
}

# Removes files an earlier run wrote that are no longer declared.
prune() {
  local base path stripped
  if [ "$mode" = generated ]; then
    mkdir -p "$state"
    touch "$state/generated"
    while IFS= read -r path; do
      # Skip paths now written as source files.
      if [ -n "$path" ] && ! is_declared "$path" && [ ! -f "$state/base/$path" ] && safe_path "$path" &&
        [ -e "$path" ] && ! git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
        rm -rf "$path"
        echo "removed $path (no longer generated)"
      fi
    done <"$state/generated"
    printf '%s\n' "${declared[@]}" >"$state/generated"
    return
  fi
  shopt -s globstar dotglob nullglob
  for base in "$state"/base/**; do
    path="${base#"$state/base/"}"
    if [ ! -f "$base" ] || is_declared "$path" || ! safe_path "$path"; then
      continue
    fi
    if [ ! -f "$path" ]; then
      :
    elif grep -q 'nullkomma:[^:]*:start' "$path"; then
      stripped="$(awk '/nullkomma:[^:]+:start/ { s = 1 } !s { print } /nullkomma:[^:]+:end/ { s = 0 }' "$path")"
      if [ -n "${stripped//[[:space:]]/}" ]; then
        printf '%s\n' "$stripped" >"$path"
        echo "removed nullkomma sections from $path"
      else
        rm "$path"
        echo "removed $path (no longer managed)"
      fi
    elif cmp -s "$path" "$base"; then
      rm "$path"
      echo "removed $path (no longer managed)"
    else
      echo "kept edited $path (no longer managed)"
    fi
    rm -f "$base" "$state/incoming/$path"
  done
}

finish() {
  if [ -n "$accept" ]; then
    if [ "$accepted" != true ]; then
      echo "Not an enabled source-of-truth file: $accept" >&2
      exit 1
    fi
  else
    prune
  fi
  exit "$status"
}
