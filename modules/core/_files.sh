# shellcheck shell=bash
mode="${mode:?file mode must be set by the caller}"
sections="${sections:?the section splicer must be set by the caller}"
manifest="${manifest:?the list of generated files must be set by the caller}"
cd "${root:?the project root must be set by the caller}" || exit 1
status=0
declared=()
unignored=()
if [ "$#" != 0 ]; then
  echo "Usage: $mode-files takes no arguments" >&2
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

declare_file() {
  declared+=("$1")
}

process_file() {
  local path="$1" source="$2"
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
  regular "$path" || return
  if [ "$mode" = generated ] && ! git check-ignore -q -- "$path"; then
    unignored+=("$path")
    status=1
    return
  fi
  # Source files without sections are written once, then the project's.
  if [ ! -e "$path" ] || { [ "$mode" = generated ] && ! cmp -s "$source" "$path"; }; then
    install_file "$path" "$source"
  fi
}

splice_file() {
  local path="$1" spliced
  shift
  safe_path "$path" || return
  declared+=("$path")
  regular "$path" || return
  spliced="$(mktemp)"
  if splice "$path" "$@" >"$spliced"; then
    cmp -s "$spliced" "$path" || install_file "$path" "$spliced"
  else
    status=1
  fi
  rm "$spliced"
}

# Usage: splice <file> [<marker prefix> <marker suffix> [<section name> <section file>]...]
splice() {
  local file="$1"
  [ -e "$file" ] || file=/dev/null
  awk -f "$sections" -v prefix="${2:-}" -v suffix="${3:-}" -v sections="${*:4}" "$file"
}

regular() {
  if [ -e "$1" ] && [ ! -f "$1" ]; then
    echo "Not a regular file: $1" >&2
    status=1
    return 1
  fi
}

install_file() {
  mkdir -p "$(dirname "$1")"
  cp --remove-destination "$2" "$1"
  chmod u+w "$1"
  echo "wrote $1"
}

is_declared() {
  local p
  for p in "${declared[@]}"; do
    [ "$p" = "$1" ] && return 0
  done
  return 1
}

# As for Nix, a file belongs to the project of the nearest flake.nix above it.
in_nested_project() {
  local parent
  parent="$(dirname "$1")"
  while [ "$parent" != . ]; do
    [ -e "$parent/flake.nix" ] && return
    parent="$(dirname "$parent")"
  done
  return 1
}

# Removes what nullkomma no longer declares: earlier generated files, and the sections of
# tracked files outside nested projects, as complete marker pairs.
prune() {
  local list path stripped
  if [ "$mode" = generated ]; then
    list="$(git rev-parse --path-format=absolute --git-path "$manifest")"
    mkdir -p "$(dirname "$list")"
    touch "$list"
    while IFS= read -r path; do
      if [ -n "$path" ] && ! is_declared "$path" && safe_path "$path" &&
        [ -e "$path" ] && ! git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
        rm -rf "$path"
        echo "removed $path (no longer generated)"
      fi
    done <"$list"
    printf '%s\n' "${declared[@]}" >"$list"
    return
  fi
  while IFS= read -r -d '' path; do
    if is_declared "$path" || ! safe_path "$path" || in_nested_project "$path" ||
      [ ! -f "$path" ] || ! stripped="$(splice "$path")"; then
      continue
    fi
    if [ -z "${stripped//[[:space:]]/}" ]; then
      rm "$path"
      echo "removed $path (no longer managed)"
    elif [ "$stripped" != "$(cat "$path")" ]; then
      printf '%s\n' "$stripped" >"$path"
      echo "removed nullkomma sections from $path"
    fi
  done < <(git grep -lzE '^[^[:space:]]+ nullkomma:[^:[:space:]]+:start' || true)
}

finish() {
  prune
  if [ "${#unignored[@]}" != 0 ]; then
    echo "Not written, because Git does not ignore them: ${unignored[*]}. Add them to .gitignore; with the git plugin, nk write-files does that." >&2
  fi
  exit "$status"
}
