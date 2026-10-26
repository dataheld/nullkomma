{
  lib,
  pkgs,
  contentPaths ? [ ],
}:
pkgs.writeShellApplication {
  name = "watchexec";
  runtimeInputs = [
    pkgs.git
  ]
  ++ lib.optionals (contentPaths != [ ]) [
    pkgs.b3sum
    pkgs.findutils
    pkgs.jq
  ];
  text = ''
    cd "$(git rev-parse --show-toplevel)"
    export NULLKOMMA_ROOT="$PWD"
    args=()
    ${lib.optionalString (contentPaths != [ ]) ''
      roots=()
      initial=()
      content_paths=(${lib.escapeShellArgs contentPaths})
      for path in "''${content_paths[@]}"; do
        roots+=("$PWD/$path/")
        if [[ -d "$path" ]]; then
          while IFS= read -r -d "" file; do
            hash="$(b3sum --no-names "$file")"
            initial+=("$(jq -cn --arg path "$file" \
              --arg hash "$hash" '{key: $path, value: $hash}')")
          done < <(find "$PWD/$path" -type f -print0)
        fi
      done
      roots_json="$(printf '%s\n' "''${roots[@]}" | jq -Rsc 'split("\n")[:-1]')"
      initial_json="$(printf '%s\n' "''${initial[@]}" | jq -sc 'from_entries')"
      args+=(--filter-prog "$initial_json as \$initial | $roots_json as \$roots | $(cat ${./_watch-content.jq})")
    ''}
    busy=(--on-busy-update queue)
    while (( $# )); do
      if [[ "$1" == --on-busy-update* ]]; then busy=(); fi
      if [[ "$1" == --watch && "''${2-}" == @* ]]; then
        args+=(--watch-file "''${2#@}")
        shift 2
      else
        args+=("$1")
        shift
      fi
    done
    exec ${lib.getExe pkgs.watchexec} --project-origin "$PWD" --no-discover-ignore "''${busy[@]}" \
      --ignore '.nullkomma' --ignore '.nullkomma/**' --ignore '.direnv' --ignore '.direnv/**' \
      "''${args[@]}"
  '';
}
