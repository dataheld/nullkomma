{
  partitions.dev.module.perSystem =
    {
      harness,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (harness)
        callFlakeWith
        fixtures
        perSystem
        root
        ;
      consumer =
        module:
        callFlakeWith {
          imports = [ module ];
          nullkomma.github.enable = false;
          nullkomma.gitlab.enable = true;
        } (root + "/templates/default");
      files = flake: (perSystem flake).nullkomma.files;
      pipeline = flake: (files flake).".gitlab-ci.yml".sections.gitlab;
      variants =
        lib.genAttrs
          [
            "plain"
            "cached"
            "pages"
            "all"
          ]
          (
            name:
            consumer {
              nullkomma.gitlab = {
                cache.enable = lib.elem name [
                  "cached"
                  "all"
                ];
                pages.enable = lib.elem name [
                  "pages"
                  "all"
                ];
              }
              // lib.optionalAttrs (name == "all") {
                tags = [ "nix" ];
                nixConfig = "cores = 2";
              };
              perSystem.packages.site = pkgs.runCommand "gitlab-test-site" { } ''
                mkdir "$out"
                echo site > "$out/index.html"
                ln -s index.html "$out/linked.html"
              '';
            }
          );
    in
    {
      nullkomma.nix.unit.tests = {
        testGitlabIsOptIn = {
          expr = (files fixtures.template) ? ".gitlab-ci.yml";
          expected = false;
        };
        testGitlabReplacesGithubWhenSelected = {
          expr = {
            gitlab = (files variants.plain) ? ".gitlab-ci.yml";
            github = (files variants.plain) ? ".github/workflows/push.yml";
            mode = (files variants.plain).".gitlab-ci.yml".mode;
          };
          expected = {
            gitlab = true;
            github = false;
            mode = "source";
          };
        };
        testGitlabNeedsLinuxChecks = {
          expr =
            (builtins.tryEval (
              (consumer {
                systems = lib.mkForce [ "aarch64-darwin" ];
              }).allSystems.aarch64-darwin.nullkomma.files.".gitlab-ci.yml".sections.gitlab
            )).success;
          expected = false;
        };
        testGitlabPagesNeedsSite = {
          expr =
            (builtins.tryEval (
              pipeline (consumer {
                nullkomma.gitlab.pages.enable = true;
              })
            )).success;
          expected = false;
        };
      };
      checks.gitlab-ci =
        pkgs.runCommand "gitlab-ci"
          {
            nativeBuildInputs = [
              (pkgs.python3.withPackages (p: [ p.pyyaml ]))
              pkgs.shellcheck
            ];
          }
          ''
            export SITE=${(perSystem variants.pages).packages.site}
            python ${pkgs.writeText "test-gitlab-ci.py" ''
              import json
              from pathlib import Path
              import shutil
              import subprocess
              import yaml

              pipelines = json.loads(${builtins.toJSON (builtins.toJSON (lib.mapAttrs (_: pipeline) variants))})

              def run(script, prelude=""):
                  return subprocess.run(["bash", "-c", prelude + script], capture_output=True, text=True)

              for name, path in pipelines.items():
                  text = Path(path).read_text()
                  ci = yaml.safe_load(text)
                  cached = name in ("cached", "all")
                  pages = name in ("pages", "all")
                  check = ci["check"]
                  setup, *steps = check["script"]
                  assert ci["default"]["image"].startswith("nixos/nix:")
                  assert ci["default"].get("tags") == (["nix"] if name == "all" else None)
                  nix_config = ci["variables"]["NIX_CONFIG"].splitlines()
                  assert "max-jobs = auto" in nix_config
                  assert "sandbox-fallback = false" in nix_config
                  assert ("cores = 2" in nix_config) == (name == "all")
                  assert check["rules"] == [{"when": "on_success"}]
                  assert check["interruptible"] is True
                  assert "retry" not in text
                  assert ("cache" in check) == cached
                  assert "cache" not in ci["default"]
                  assert ("artifacts" in check) == pages
                  assert ("deploy-pages" in ci) == pages
                  flake_check = next(s for s in steps if "nix flake check" in s)
                  assert "nix flake check --print-build-logs --system x86_64-linux" in flake_check
                  assert "section_start:" in flake_check and "section_end:" in flake_check
                  assert ci["workflow"]["rules"][0]["if"] == '$CI_PIPELINE_SOURCE == "merge_request_event"'
                  assert ci["workflow"]["rules"][1]["when"] == "never"
                  assert "CI_OPEN_MERGE_REQUESTS" in ci["workflow"]["rules"][1]["if"]
                  for unwanted in ("flakehub", "--all-systems", "aarch64", "/nix/store/", "sudo", "curl"):
                      assert unwanted not in text, unwanted
                  for job in ("check", "deploy-pages") if pages else ("check",):
                      shell = Path(f"{name}-{job}.sh")
                      shell.write_text("\n".join(ci[job]["script"]))
                      subprocess.run(["bash", "-n", shell], check=True)
                      subprocess.run(["shellcheck", "-s", "bash", "-e", "SC1091", shell], check=True)

                  profile = Path("nix-daemon.sh").absolute()
                  setup = setup.replace("/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh", str(profile))
                  linux = 'uname() { echo "Linux x86_64"; }\n'
                  stub = 'nix() { echo "nix $*"; }\n'
                  profile.unlink(missing_ok=True)
                  missing = run(setup, linux)
                  assert missing.returncode != 0 and "needs Nix" in missing.stderr, missing
                  assert run(setup, 'uname() { echo "Linux aarch64"; }\n' + stub).returncode != 0
                  container = run(setup, linux + stub)
                  profile.write_text(stub)
                  shell_runner = run(setup, linux)
                  for runner in (container, shell_runner):
                      assert runner.returncode == 0, runner
                      for setting in ("max-jobs", "cores", "sandbox"):
                          assert f"nix config show {setting}" in runner.stdout, setting

                  if cached:
                      cache = check["cache"]
                      assert cache["paths"] == [".gitlab-nix-cache/"]
                      assert cache["key"]["files"] == ["flake.lock"]
                      assert "$CI_COMMIT_REF_SLUG" in cache["key"]["prefix"]
                      assert "--include-outputs" in steps[-1]
                      assert "--all --no-check-sigs" in steps[0]
                      assert ("packages.x86_64-linux.site" in steps[-1]) == pages
                  if pages:
                      assert check["artifacts"]["paths"] == [".gitlab-pages/"]
                      assert check["artifacts"]["expire_in"]
                      job = ci["deploy-pages"]
                      assert job["needs"] == ["check"]
                      assert job["pages"]["publish"] == ".gitlab-pages"
                      assert job["rules"] == [{"if": '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $CI_PIPELINE_SOURCE == "push"'}]
                      assert "interruptible" not in job
                      assert "nix" not in "\n".join(job["script"])
                      site = next(s for s in steps if ".gitlab-pages" in s)
                      shutil.rmtree(".gitlab-pages", ignore_errors=True)
                      built = run(site, 'set -euo pipefail\nnix() { printf "%s\\n" "$SITE"; }\n')
                      assert built.returncode == 0, built
                      assert Path(".gitlab-pages/index.html").read_text() == "site\n"
                      assert not Path(".gitlab-pages/linked.html").is_symlink()
                      published = run("\n".join(job["script"]))
                      assert published.returncode == 0, published
            ''}
            touch "$out"
          '';
    };
}
