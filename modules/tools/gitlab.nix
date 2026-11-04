{
  plugins.gitlab =
    {
      config,
      lib,
      withSystem,
      ...
    }:
    let
      cfg = config.nullkomma.gitlab;
      saveCache =
        roots:
        lib.optional cfg.cache.enable ''
          ${lib.removeSuffix "\n" roots} |
            xargs -r nix-store --query --requisites --include-outputs |
            nix copy --stdin --to "file://$CI_PROJECT_DIR/.gitlab-nix-cache"
        '';
      ci = {
        workflow.rules = [
          { "if" = ''$CI_PIPELINE_SOURCE == "merge_request_event"''; }
          {
            "if" = ''$CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS && $CI_PIPELINE_SOURCE == "push"'';
            when = "never";
          }
          { "if" = "$CI_COMMIT_BRANCH || $CI_COMMIT_TAG"; }
        ];
        variables.NIX_CONFIG = "extra-experimental-features = nix-command flakes";
        default = {
          before_script = [
            ''
              set -euo pipefail
              if [[ "$(uname -sm)" != "Linux x86_64" ]]; then
                echo "nullkomma GitLab CI requires an x86_64 Linux shell runner." >&2
                exit 1
              fi
              if ! command -v nix >/dev/null && [[ ! -x /nix/var/nix/profiles/default/bin/nix ]]; then
                curl --proto '=https' --tlsv1.2 -fsSL https://install.determinate.systems/nix |
                  sudo -n sh -s -- install linux --no-confirm --no-modify-profile --diagnostic-endpoint ""
              fi
              if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
                . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
              fi
              nix --version
            ''
          ]
          ++ lib.optional cfg.cache.enable ''
            if [[ -f .gitlab-nix-cache/nix-cache-info ]]; then
              sudo -n "$(command -v nix)" --extra-experimental-features nix-command \
                copy --all --no-check-sigs --from "file://$CI_PROJECT_DIR/.gitlab-nix-cache"
            fi
          '';
        }
        // lib.optionalAttrs cfg.cache.enable {
          cache = {
            key = {
              prefix = "nix-x86_64-linux-$CI_COMMIT_REF_SLUG";
              files = [ "flake.lock" ];
            };
            paths = [ ".gitlab-nix-cache/" ];
          };
        };
        check = {
          # Without rules GitLab excludes the job from merge request pipelines.
          rules = [ { when = "on_success"; } ];
          script = [
            "nix flake check --print-build-logs --system x86_64-linux"
          ]
          ++ saveCache ''
            nix eval --raw .#checks.x86_64-linux --apply \
              'checks: builtins.concatStringsSep "" (map (check: check.drvPath + "\n") (builtins.attrValues checks))'
          '';
        };
      }
      // lib.optionalAttrs cfg.pages.enable {
        deploy-pages = {
          stage = "deploy";
          needs = [ "check" ];
          rules = [
            { "if" = ''$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $CI_PIPELINE_SOURCE == "push"''; }
          ];
          script = [
            ''
              site=$(nix build --print-build-logs --no-link --print-out-paths .#packages.x86_64-linux.site)
              mkdir .gitlab-pages
              cp -RL "$site/." .gitlab-pages/
            ''
          ]
          ++ saveCache "nix path-info --derivation .#packages.x86_64-linux.site";
          pages.publish = ".gitlab-pages";
        };
      };
    in
    {
      options.nullkomma.gitlab = {
        cache.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Cache check and site build dependencies in `.gitlab-nix-cache/`,
            per ref and keyed by `flake.lock`.
            Restores unsigned local build output with sudo:
            keep GitLab's protected-branch cache separation enabled.
            Transfers can cost more than they save on persistent runners.
          '';
        };
        pages.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Publish `packages.x86_64-linux.site` to GitLab Pages after checks
            pass on default-branch pushes.
            Requires a site provider, such as `quarto` or R's pkgdown,
            and GitLab 17.10 or newer.
          '';
        };
      };
      config = lib.mkIf cfg.enable {
        nullkomma.gitignore =
          lib.optional cfg.cache.enable "/.gitlab-nix-cache/"
          ++ lib.optional cfg.pages.enable "/.gitlab-pages/";
        perSystem =
          { pkgs, ... }:
          {
            nullkomma.files.".gitlab-ci.yml".source =
              assert lib.assertMsg (lib.elem "x86_64-linux" config.systems)
                "nullkomma.gitlab requires x86_64-linux in systems.";
              assert lib.assertMsg (
                !cfg.pages.enable || withSystem "x86_64-linux" ({ config, ... }: config.packages ? site)
              ) "nullkomma.gitlab.pages requires packages.x86_64-linux.site.";
              (pkgs.formats.yaml { }).generate "gitlab-ci.yml" ci;
          };
      };
    };
}
