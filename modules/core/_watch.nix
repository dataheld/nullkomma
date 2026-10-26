{ lib, pkgs }:
tasks:
let
  outputs = lib.unique (
    lib.concatMap (task: lib.optionals (task.watch != null) task.watch.outputs) (lib.attrValues tasks)
  );
in
pkgs.writeShellApplication {
  name = "watchexec";
  runtimeInputs = [ pkgs.git ];
  text = ''
    cd "$(git rev-parse --show-toplevel)"
    export NULLKOMMA_ROOT="$PWD"
    args=()
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
      ${lib.concatMapStrings (path: "--ignore ${lib.escapeShellArg path} ") outputs} \
      "''${args[@]}"
  '';
}
