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
        } (root + "/tests/fixtures/md");
      files = flake: (perSystem flake).nullkomma.files;
      pipeline = flake: (files flake).".gitlab-ci.yml".source;
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
          expr = (files fixtures.md) ? ".gitlab-ci.yml";
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
              pipeline (consumer {
                systems = lib.mkForce [ "aarch64-darwin" ];
              })
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
              import subprocess
              import yaml

              pipelines = json.loads(${builtins.toJSON (builtins.toJSON (lib.mapAttrs (_: pipeline) variants))})
              for name, path in pipelines.items():
                  ci = yaml.safe_load(Path(path).read_text())
                  cached = name in ("cached", "all")
                  pages = name in ("pages", "all")
                  assert ("cache" in ci["default"]) == cached
                  assert ("deploy-pages" in ci) == pages
                  assert ci["check"]["rules"] == [{"when": "on_success"}]
                  assert ci["check"]["script"][0] == "nix flake check --print-build-logs --system x86_64-linux"
                  assert ci["workflow"]["rules"][0]["if"] == '$CI_PIPELINE_SOURCE == "merge_request_event"'
                  assert ci["workflow"]["rules"][1]["when"] == "never"
                  assert "CI_OPEN_MERGE_REQUESTS" in ci["workflow"]["rules"][1]["if"]
                  assert "image" not in ci["default"]
                  text = Path(path).read_text()
                  for unwanted in ("flakehub", "--all-systems", "aarch64", "/nix/store/"):
                      assert unwanted not in text, unwanted
                  for job in ("check", "deploy-pages") if pages else ("check",):
                      script = "\n".join(ci["default"]["before_script"] + ci[job]["script"])
                      shell = Path(f"{name}-{job}.sh")
                      shell.write_text(script)
                      subprocess.run(["bash", "-n", shell], check=True)
                      subprocess.run(["shellcheck", "-s", "bash", "-e", "SC1091", shell], check=True)
                  if cached:
                      cache = ci["default"]["cache"]
                      assert cache["paths"] == [".gitlab-nix-cache/"]
                      assert cache["key"]["files"] == ["flake.lock"]
                      assert "$CI_COMMIT_REF_SLUG" in cache["key"]["prefix"]
                      assert "--include-outputs" in text
                      assert "--all --no-check-sigs" in text
                      assert "after_script" not in ci["default"]
                  if pages:
                      job = ci["deploy-pages"]
                      assert job["needs"] == ["check"]
                      assert job["pages"]["publish"] == ".gitlab-pages"
                      assert job["rules"] == [{"if": '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $CI_PIPELINE_SOURCE == "push"'}]
                      if not cached:
                          subprocess.run(
                              ["bash", "-euc", 'nix() { printf "%s\\n" "$SITE"; }\n' + "\n".join(job["script"])],
                              check=True,
                          )
                          assert Path(".gitlab-pages/index.html").read_text() == "site\n"
                          assert not Path(".gitlab-pages/linked.html").is_symlink()
            ''}
            touch "$out"
          '';
    };
}
