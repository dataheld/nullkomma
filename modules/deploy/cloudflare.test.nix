{
  partitions.dev.module.perSystem =
    {
      harness,
      lib,
      pkgs,
      system,
      ...
    }:
    let
      inherit (harness)
        fixtures
        perSystem
        plugins
        raw
        task
        ;
      tfConfig =
        flake: (perSystem flake).terranix.terranixConfigurations.deploy.result.terraformConfiguration;
      # Any flake with a `packages.site`, without other plugins.
      bare = {
        imports = [ plugins.cloudflare ];
        nullkomma.cloudflare = {
          enable = true;
          worker = "bare-site";
        };
        perSystem =
          { pkgs, ... }:
          {
            packages.site = pkgs.writeTextDir "content.txt" "Independent static assets\n";
          };
      };
      inherit (fixtures) cloudflare;
    in
    {
      checks = {
        cloudflare-devshell =
          (raw {
            imports = [ bare ];
            nullkomma.devShell.enable = true;
            perSystem =
              { pkgs, ... }:
              {
                packages.site = lib.mkForce (pkgs.runCommand "unbuildable-site" { } "exit 1");
              };
          }).devShells.${system}.default;
        cloudflare-plan-offline =
          pkgs.runCommand "nullkomma-cloudflare-plan-offline"
            {
              nativeBuildInputs = [
                (perSystem cloudflare).terranix.terranixConfigurations.deploy.terraformWrapper.package
                pkgs.jq
              ];
            }
            ''
              export HOME=$TMPDIR CLOUDFLARE_API_TOKEN=0000000000000000000000000000000000000000
              export TF_VAR_account_id=00000000000000000000000000000000
              # Plan without backend, refresh or network.
              export HTTPS_PROXY=http://127.0.0.1:1
              plan() {
                jq 'del(.terraform.backend)' "$1" > config.tf.json
                tofu init -backend=false > /dev/null || return
                tofu plan -refresh=false -out=plan > /dev/null || return
                tofu show -json plan | jq '.planned_values.root_module.resources | map({key: .address, value: .values}) | from_entries'
              }
              site=${cloudflare.packages.${system}.site}
              assets=$(jq -r .resource.cloudflare_workers_script.site.assets.directory ${tfConfig cloudflare})
              cp -r "$site" expected-assets
              chmod -R u+w expected-assets
              rm expected-assets/_headers expected-assets/_redirects
              diff -r expected-assets "$assets"
              plan ${tfConfig cloudflare} | jq -e \
                --rawfile headers "$site/_headers" \
                --rawfile redirects "$site/_redirects" '
                ."cloudflare_workers_script.site" as $worker
                | ."cloudflare_workers_custom_domain.subdomain" as $domain
                | $worker.script_name == "fixture-site"
                  and $worker.assets.config.headers == $headers
                  and $worker.assets.config.redirects == $redirects
                  and $domain.hostname == "www.example.org"
                  and $domain.service == "fixture-site"
              '
              plan ${tfConfig (raw bare)} | jq -e '
                keys == ["cloudflare_workers_script.site", "cloudflare_workers_script_subdomain.site"]
                  and (."cloudflare_workers_script.site".assets.config | .headers == null and .redirects == null)
              '
              bareAssets=$(jq -r .resource.cloudflare_workers_script.site.assets.directory ${tfConfig (raw bare)})
              diff -r ${(raw bare).packages.${system}.site} "$bareAssets"
              mkdir identity && cd identity
              export TF_VAR_site_name=lap
              # Exercise our state-key wiring locally, without R2 credentials.
              jq '.terraform.backend = {local: {path: .terraform.backend.s3.key}}' ${
                tfConfig (raw {
                  imports = [ bare ];
                  nullkomma.cloudflare.worker = lib.mkForce null;
                })
              } > config.tf.json
              tofu init > /dev/null
              tofu plan -refresh=false > /dev/null
              if tofu plan -refresh=false -var=site_name=other > /dev/null 2>error; then
                echo "Changing the Worker identity must require backend reinitialization" >&2
                exit 1
              fi
              grep -q 'Backend initialization required' error
              touch $out
            '';
        cloudflare-name =
          let
            tofu = pkgs.writeShellScriptBin "tofu" ''
              set -eu
              test "''${TF_VAR_site_name:-}" = "$EXPECTED_NAME"
            '';
            wrapper =
              options:
              lib.getExe
                (perSystem (raw {
                  imports = [ bare ];
                  nullkomma.cloudflare = {
                    domain = "example.org";
                  }
                  // options;
                  perSystem.terranix.terranixConfigurations.deploy.terraformWrapper.package = lib.mkForce tofu;
                })).terranix.terranixConfigurations.deploy.result.terraformWrapper;
            inferredWrapper = wrapper { worker = lib.mkForce null; };
            namedWrapper = wrapper {
              name = "other-name";
              worker = lib.mkForce "other-name";
            };
            independentWrapper = wrapper { };
          in
          pkgs.runCommand "nullkomma-cloudflare-name" { nativeBuildInputs = [ pkgs.git ]; } ''
            export CLOUDFLARE_ACCOUNT_ID=account CLOUDFLARE_STATE_BUCKET=state
            export CLOUDFLARE_R2_ACCESS_KEY_ID=r2-key CLOUDFLARE_R2_SECRET_ACCESS_KEY=r2-secret
            export HOME=$TMPDIR/home
            mkdir -p "$HOME"
            export GIT_CONFIG_NOSYSTEM=1
            unset GIT_DIR GIT_WORK_TREE TF_VAR_site_name GITHUB_REPOSITORY
            git init -q
            git remote add origin https://github.com/owner/lap.git
            export EXPECTED_NAME=lap
            ${inferredWrapper} init
            git remote set-url origin git@github.com:owner/lap.git
            ${inferredWrapper} plan
            git remote set-url origin ssh://git@github.com/owner/lap.git
            ${inferredWrapper} plan
            export GITHUB_REPOSITORY=owner/from-ci EXPECTED_NAME=from-ci
            ${inferredWrapper} plan
            ${independentWrapper} plan
            export EXPECTED_NAME=""
            ${namedWrapper} plan
            unset GITHUB_REPOSITORY
            git remote remove origin
            ${namedWrapper} plan
            fails() {
              if ${inferredWrapper} plan > /dev/null 2>error; then
                echo "Expected name inference to fail" >&2
                exit 1
              fi
              grep -q "$1" error
            }
            fails 'Cannot infer Cloudflare name'
            for name in Uppercase under_score -leading trailing- "." lap.git "$(printf '%064d' 0)"; do
              export GITHUB_REPOSITORY="owner/$name"
              fails 'lowercase DNS label'
            done
            for repository in lap owner/lap/extra owner/ /lap; do
              export GITHUB_REPOSITORY="$repository"
              fails 'must be owner/repository'
            done
            export GITHUB_REPOSITORY=owner/a EXPECTED_NAME=a
            ${inferredWrapper} plan
            export EXPECTED_NAME="$(printf '%063d' 0)"
            export GITHUB_REPOSITORY="owner/$EXPECTED_NAME"
            ${inferredWrapper} plan
            touch $out
          '';
        cloudflare-deploy =
          let
            tofu = pkgs.writeShellScriptBin "tofu" ''
              set -eu
              test "$TF_VAR_account_id" = "$CLOUDFLARE_ACCOUNT_ID"
              test "$AWS_ACCESS_KEY_ID" = r2-key
              test "$AWS_SECRET_ACCESS_KEY" = r2-secret
              test "$AWS_ENDPOINT_URL_S3" = "https://$CLOUDFLARE_ACCOUNT_ID.r2.cloudflarestorage.com"
              test "$TF_CLI_ARGS_init" = "-backend-config=bucket=$CLOUDFLARE_STATE_BUCKET"
              printf '%s\n' "$@" > "$CALLED"
            '';
            nix = pkgs.writeShellScriptBin "nix" ''
              set -eu
              test "$1" = run
              target="$2"
              shift 2
              if [[ "''${1-}" == -- ]]; then shift; fi
              case "$target" in
                .#deploy) exec ${deploy} "$@" ;;
                .#deploy.init) exec ${lib.getExe flake.packages.${system}.deploy.init} "$@" ;;
                .#deploy.terraform) exec ${lib.getExe flake.packages.${system}.deploy.terraform} "$@" ;;
                *) exit 1 ;;
              esac
            '';
            flake = raw {
              imports = [ bare ];
              perSystem.terranix.terranixConfigurations.deploy.terraformWrapper.package = lib.mkForce tofu;
            };
            deploy = lib.getExe flake.packages.${system}.deploy;
          in
          pkgs.runCommand "nullkomma-cloudflare-deploy"
            {
              nativeBuildInputs = [
                pkgs.git
                nix
              ];
            }
            ''
              export CALLED=$PWD/called CLOUDFLARE_ACCOUNT_ID=account CLOUDFLARE_STATE_BUCKET=state
              export CLOUDFLARE_R2_ACCESS_KEY_ID=r2-key CLOUDFLARE_R2_SECRET_ACCESS_KEY=r2-secret
              export AWS_ACCESS_KEY_ID=other-key AWS_SECRET_ACCESS_KEY=other-secret
              ${deploy}
              test -f "$CALLED"
              if (unset CLOUDFLARE_R2_ACCESS_KEY_ID; ${deploy}) > /dev/null 2>error; then
                echo "Deployment must reject missing Cloudflare R2 credentials" >&2
                exit 1
              fi
              grep -q CLOUDFLARE_R2_ACCESS_KEY_ID error
              rm "$CALLED"
              mkdir project
              cd project
              git init -q
              ${task flake "cloudflare-deploy"}
              test -f "$CALLED"
              ${task flake "cloudflare-plan"}
              printf '%s\n' plan > expected
              cmp expected "$CALLED"
              ${task flake "cloudflare-plan"} -target=cloudflare_workers_script.site
              printf '%s\n' plan -target=cloudflare_workers_script.site > expected
              cmp expected "$CALLED"
              touch $out
            '';
      };
    };
}
