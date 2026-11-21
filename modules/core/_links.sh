# shellcheck shell=bash
# Links each file of `$bundle` at the same path, in real directories, as tools such as Quarto
# don't follow linked ones, after removing the links into the previous bundle that this one lacks.
# Whatever else is at a path is the project's, so it is reported, not replaced.
bundle="${bundle:?the bundle of links must be set by the caller}"
previous=.nullkomma/gcroots/links
status=0
unignored=()
# Links without their record could not be pruned, so none are made until Git ignores it too.
blocked=
if ! git check-ignore -q -- "$previous"; then
  unignored+=("/$(dirname -- "$previous")/")
  blocked=1
fi

ours() {
  case "$(readlink -- "$1")" in
  /nix/store/*-nullkomma-links/"$1") ;;
  *) return 1 ;;
  esac
}

refuse() {
  echo "Not linked: $1" >&2
  status=1
}

# A path that changes between file and directory is pruned too, so it can be linked again.
prune() {
  local old path
  [ -z "$blocked" ] && old="$(readlink -- "$previous")" && [ "$old" != "$bundle" ] && [ -d "$old" ] || return 0
  while IFS= read -r -d '' path; do
    if [ ! -f "$bundle/$path" ] && [ -L "$path" ] && ours "$path"; then
      # `-f`: shells entered at once may prune the same links.
      rm -f -- "$path"
      echo "removed $path"
      [ "$(dirname -- "$path")" = . ] ||
        rmdir -p --ignore-fail-on-non-empty -- "$(dirname -- "$path")" 2>/dev/null || true
    fi
  done < <(find -L "$old" -type f -printf '%P\0')
}

# Usage: link <declared path>, a file or directory.
link() {
  local file
  while IFS= read -r -d '' file; do
    link_file "$1" "$1${file:+/$file}"
  done < <(find -L "$bundle/$1" -type f -printf '%P\0')
}

link_file() {
  local declared="$1" path="$2" parent
  parent="$(dirname -- "$path")"
  while [ "$parent" != . ]; do
    if [ -L "$parent" ] || { [ -e "$parent" ] && [ ! -d "$parent" ]; }; then
      refuse "$path, as $parent is not a real directory."
      return
    fi
    parent="$(dirname -- "$parent")"
  done
  if git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
    refuse "$path, as Git tracks it. Remove it from Git, or disable the link in Nix."
  elif { [ -e "$path" ] || [ -L "$path" ]; } && ! ours "$path"; then
    refuse "$path, as the project has its own. Remove it, or disable the link in Nix."
  elif ! git check-ignore -q -- "$path"; then
    unignored+=("/$declared")
  elif [ -z "$blocked" ] && [ "$(readlink -- "$path")" != "$bundle/$path" ]; then
    [ -L "$path" ] || echo "linked $path"
    mkdir -p -- "$(dirname -- "$path")"
    ln -sfn -- "$bundle/$path" "$path"
  fi
}

finish() {
  # The record is also a garbage collector root, so links outlive `nix store gc`.
  if [ -z "$blocked" ]; then
    mkdir -p -- "$(dirname -- "$previous")"
    if command -v nix-store >/dev/null; then
      nix-store --add-root "$previous" --realise "$bundle" >/dev/null
    else
      ln -sfn -- "$bundle" "$previous"
    fi
  fi
  if [ "${#unignored[@]}" != 0 ]; then
    printf 'Not linked, as Git does not ignore them; add them to .gitignore:\n' >&2
    printf '%s\n' "${unignored[@]}" | sort -u >&2
    status=1
  fi
  exit "$status"
}
