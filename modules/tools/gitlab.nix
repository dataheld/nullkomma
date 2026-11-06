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
      site = ".#packages.x86_64-linux.site";
      # Collapsible GitLab log sections, which show each step's duration.
      section = name: command: ''
        printf '\e[0Ksection_start:%s:${name}\r\e[0K${name}\n' "$(date +%s)"
        ${command}
        printf '\e[0Ksection_end:%s:${name}\r\e[0K\n' "$(date +%s)"
      '';
      setup = ''
        set -euo pipefail
        if [[ "$(uname -sm)" != "Linux x86_64" ]]; then
          echo "nullkomma GitLab CI requires an x86_64 Linux runner." >&2
          exit 1
        fi
        if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
          . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        fi
        if ! command -v nix >/dev/null; then
          echo "nullkomma GitLab CI needs Nix: use a Nix image or a shell runner with Nix." >&2
          exit 1
        fi
        nix --version
        for setting in max-jobs cores sandbox; do
          echo "$setting = $(nix config show "$setting")"
        done
      '';
      saveCache =
        roots:
        lib.optional cfg.cache.enable (
          section "cache_save" ''
            {
              ${lib.concatStringsSep "\n" roots}
            } |
              xargs -r nix-store --query --requisites --include-outputs |
              nix copy --stdin --to "file://$CI_PROJECT_DIR/.gitlab-nix-cache"
          ''
        );
      ci = {
        workflow.rules = [
          { "if" = ''$CI_PIPELINE_SOURCE == "merge_request_event"''; }
          {
            "if" = ''$CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS && $CI_PIPELINE_SOURCE == "push"'';
            when = "never";
          }
          { "if" = "$CI_COMMIT_BRANCH || $CI_COMMIT_TAG"; }
        ];
        variables.NIX_CONFIG = ''
          extra-experimental-features = nix-command flakes
          max-jobs = auto
          sandbox-fallback = false
          ${cfg.nixConfig}'';
        default = {
          inherit (cfg) image;
        }
        // lib.optionalAttrs (cfg.tags != [ ]) { inherit (cfg) tags; };
        check = {
          # Without rules GitLab excludes the job from merge request pipelines.
          rules = [ { when = "on_success"; } ];
          interruptible = true;
          script = [
            setup
          ]
          ++ lib.optional cfg.cache.enable (
            section "cache_restore" ''
              if [[ -f .gitlab-nix-cache/nix-cache-info ]]; then
                nix copy --all --no-check-sigs --from "file://$CI_PROJECT_DIR/.gitlab-nix-cache"
              fi
            ''
          )
          ++ [ (section "flake_check" "nix flake check --print-build-logs --system x86_64-linux") ]
          ++ lib.optional cfg.pages.enable (
            section "site_build" ''
              site=$(nix build --print-build-logs --no-link --print-out-paths ${site})
              mkdir .gitlab-pages
              cp -RL "$site/." .gitlab-pages/
            ''
          )
          ++ saveCache (
            [
              ''
                nix eval --raw .#checks.x86_64-linux --apply \
                  'checks: builtins.concatStringsSep "" (map (check: check.drvPath + "\n") (builtins.attrValues checks))'
              ''
            ]
            ++ lib.optional cfg.pages.enable "nix path-info --derivation ${site}"
          );
        }
        // lib.optionalAttrs cfg.cache.enable {
          cache = {
            key = {
              prefix = "nix-x86_64-linux-$CI_COMMIT_REF_SLUG";
              files = [ "flake.lock" ];
            };
            paths = [ ".gitlab-nix-cache/" ];
          };
        }
        // lib.optionalAttrs cfg.pages.enable {
          artifacts = {
            paths = [ ".gitlab-pages/" ];
            expire_in = "1 week";
          };
        };
      }
      // lib.optionalAttrs cfg.pages.enable {
        deploy-pages = {
          stage = "deploy";
          needs = [ "check" ];
          rules = [
            { "if" = ''$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $CI_PIPELINE_SOURCE == "push"''; }
          ];
          script = [ "test -f .gitlab-pages/index.html" ];
          pages.publish = ".gitlab-pages";
        };
      };
    in
    {
      options.nullkomma.gitlab = {
        image = lib.mkOption {
          type = lib.types.str;
          default = "nixos/nix:2.35.4";
          description = ''
            Image with Nix for Docker and Kubernetes executors.
            Shell executors ignore it and use the runner's Nix.
          '';
        };
        tags = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "nix" ];
          description = "Tags that select the runners for all jobs.";
        };
        nixConfig = lib.mkOption {
          type = lib.types.lines;
          default = "";
          example = "max-jobs = 4";
          description = ''
            Nix settings added to `NIX_CONFIG`.
            The defaults build in parallel (`max-jobs = auto`)
            and fail instead of building unsandboxed when `sandbox = true`
            is not possible (`sandbox-fallback = false`).
            The job log shows the effective `max-jobs`, `cores` and `sandbox`.
            A Nix daemon ignores most settings from users it does not trust.
          '';
        };
        cache.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Cache check and site build dependencies in `.gitlab-nix-cache/`,
            per ref and keyed by `flake.lock`.
            Restoring imports unsigned paths,
            so the job user must be root or a trusted Nix user:
            keep GitLab's protected-branch cache separation enabled.
            Transfers can cost more than they save on persistent runners.
          '';
        };
        pages.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Build `packages.x86_64-linux.site` after the checks in every pipeline,
            and publish it to GitLab Pages on default-branch pushes.
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
