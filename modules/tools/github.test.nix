{
  partitions.dev.module.perSystem =
    { harness, pkgs, ... }:
    {
      checks.github-ci =
        pkgs.runCommand "github-ci"
          {
            nativeBuildInputs = [
              (pkgs.python3.withPackages (p: [ p.pyyaml ]))
              pkgs.jq
            ];
          }
          ''
            python ${pkgs.writeText "test-github-ci.py" ''
              import os
              from pathlib import Path
              import re
              import subprocess
              import yaml

              jobs = yaml.safe_load(
                  Path("${harness.root}/.github/workflows/ci.yml").read_text()
              )["jobs"]
              inventory = jobs["inventory"]["steps"][-1]["run"]
              runners = dict(re.findall(r'([\w-]+) = "([^"]+)";', inventory))
              assert runners == {
                  "aarch64-darwin": "macos-latest",
                  "x86_64-darwin": "macos-latest",
                  "aarch64-linux": "ubuntu-24.04-arm",
                  "x86_64-linux": "ubuntu-latest",
              }, runners
              steps = jobs["build"]["steps"]
              rosetta = next(s for s in steps if s.get("name") == "Install Rosetta")
              assert rosetta["if"] == "matrix.system == 'x86_64-darwin'"
              assert rosetta["run"] == (
                  "sudo softwareupdate --install-rosetta --agree-to-license"
              )
              installer = next(
                  s for s in steps
                  if s.get("uses") == "DeterminateSystems/determinate-nix-action@v3"
              )
              assert steps.index(rosetta) < steps.index(installer)
              check = next(s for s in steps if s.get("name") == "Check flake")
              build = steps[-1]
              assert build["env"]["NIX_SYSTEM"] == "$" + "{{ matrix.system }}"
              for system in runners:
                  command = check["run"].replace(
                      "$" + "{{ matrix.system }}", system
                  )
                  args = subprocess.check_output(
                      ["bash", "-euc", "nix() { printf '%s\\n' \"$@\"; }\n" + command],
                      text=True,
                  ).splitlines()
                  assert args == [
                      "flake", "check", "--print-build-logs", "--system", system
                  ], args
                  args = subprocess.check_output(
                      ["bash", "-euc", """
              nix() {
                  case "$1" in
                      eval) printf '["example"]\\n' ;;
                      build) printf '%s\\n' "$@" ;;
                  esac
              }
              """ + build["run"]],
                      env=os.environ | {"NIX_SYSTEM": system},
                      text=True,
                  ).splitlines()
                  expected = []
                  for output in ("packages", "devShells"):
                      expected.extend([
                          "build", "--no-link", "--print-build-logs",
                          f'.#{output}.{system}."example"',
                      ])
                  assert args == expected, args
            ''}
            touch "$out"
          '';
    };
}
