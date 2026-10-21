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
        callFlakeWith
        fixtures
        perSystem
        plugins
        raw
        root
        runCheck
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
      cloudflare = callFlakeWith {
        nullkomma.cloudflare = {
          enable = true;
          worker = "fixture-site";
          domains."www.example.org" = "11111111111111111111111111111111";
        };
      } (root + "/tests/fixtures/quarto");
    in
    {
      nullkomma.nix.unit.tests = {
        testCloudflareComposesWithAnySite = {
          expr = {
            packages = lib.attrNames (raw bare).packages.${system};
            checks = lib.attrNames (raw bare).checks.${system};
          };
          expected = {
            packages = [
              "deploy"
              "site"
            ];
            checks = [
              "cloudflare"
              "treefmt"
            ];
          };
        };
        testCloudflareProvidesWranglerOnlyWhenEnabled = {
          expr = map (flake: lib.elem pkgs.wrangler (perSystem flake).nullkomma.devShell.packages) [
            cloudflare
            fixtures.quarto
          ];
          expected = [
            true
            false
          ];
        };
      };
      checks = {
        cloudflare-config = cloudflare.checks.${system}.cloudflare;
        cloudflare-validation-local =
          let
            nix = pkgs.writeShellScriptBin "nix" ''
              set -eu
              test "$*" = 'build --no-link --print-out-paths .#deploy.config'
              echo ${tfConfig (raw bare)}
            '';
            flake = raw {
              imports = [ bare ];
              perSystem.nullkomma.checks.cloudflare.packages = lib.mkForce [ nix ];
            };
          in
          pkgs.runCommand "nullkomma-cloudflare-validation-local" { } ''
            export HOME="$TMPDIR"
            ${runCheck flake "cloudflare"}
            touch "$out"
          '';
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
        cloudflare-plan =
          pkgs.runCommand "nullkomma-cloudflare-plan"
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
                tofu init -backend=false > /dev/null
                tofu plan -refresh=false -out=plan > /dev/null
                tofu show -json plan | jq '.planned_values.root_module.resources | map({key: .address, value: .values}) | from_entries'
              }
              site=${cloudflare.packages.${system}.site}
              assets=$(jq -r .resource.cloudflare_workers_script.site.assets.directory ${tfConfig cloudflare})
              cp -r "$site" expected-assets
              chmod -R u+w expected-assets
              rm expected-assets/_headers expected-assets/_redirects
              diff -r expected-assets "$assets"
              jq -e '.terraform.backend.s3.key == "fixture-site.tfstate"' ${tfConfig cloudflare}
              jq -e '.terraform.backend.s3.key == "bare-site.tfstate"' ${tfConfig (raw bare)}
              plan ${tfConfig cloudflare} | jq -e \
                --rawfile headers "$site/_headers" \
                --rawfile redirects "$site/_redirects" '
                ."cloudflare_workers_script.site" as $worker
                | ."cloudflare_workers_custom_domain.www_example_org" as $domain
                | ."cloudflare_workers_script_subdomain.site" as $subdomain
                | $worker.script_name == "fixture-site"
                  and $worker.assets.config.not_found_handling == "404-page"
                  and $worker.assets.config.headers == $headers
                  and $worker.assets.config.redirects == $redirects
                  and $domain.hostname == "www.example.org"
                  and $domain.zone_id == "11111111111111111111111111111111"
                  and $domain.service == "fixture-site"
                  and $subdomain.enabled == false
                  and $subdomain.previews_enabled == false
              '
              plan ${tfConfig (raw bare)} | jq -e '
                keys == ["cloudflare_workers_script.site", "cloudflare_workers_script_subdomain.site"]
                  and (."cloudflare_workers_script.site".assets.config | .headers == null and .redirects == null)
              '
              bareAssets=$(jq -r .resource.cloudflare_workers_script.site.assets.directory ${tfConfig (raw bare)})
              diff -r ${(raw bare).packages.${system}.site} "$bareAssets"
              touch $out
            '';
        cloudflare-deploy =
          let
            tofu = pkgs.writeShellScriptBin "tofu" ''
              set -eu
              test "$TF_VAR_account_id" = "$CLOUDFLARE_ACCOUNT_ID"
              test "$AWS_ENDPOINT_URL_S3" = "https://$CLOUDFLARE_ACCOUNT_ID.r2.cloudflarestorage.com"
              test "$TF_CLI_ARGS_init" = "-backend-config=bucket=$CLOUDFLARE_STATE_BUCKET"
              test "$TF_CLI_ARGS_apply" = "-auto-approve"
              test "$TF_IN_AUTOMATION" = 1
              test "$TF_INPUT" = 0
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
              perSystem = {
                terranix.terranixConfigurations.deploy.terraformWrapper.package = lib.mkForce tofu;
                nullkomma.tasks = {
                  deploy.packages = lib.mkForce [ nix ];
                  terraform.packages = lib.mkForce [ nix ];
                };
              };
            };
            deploy = lib.getExe flake.packages.${system}.deploy;
            tasks = (perSystem flake).nullkomma.tasks;
          in
          pkgs.runCommand "nullkomma-cloudflare-deploy" { } ''
            export CALLED=$PWD/called CLOUDFLARE_ACCOUNT_ID=account CLOUDFLARE_STATE_BUCKET=state
            ${deploy}
            test -f "$CALLED"
            rm "$CALLED"
            ${lib.getExe tasks.deploy.package}
            test -f "$CALLED"
            ${lib.getExe tasks.terraform.package}
            printf '%s\n' plan > expected
            cmp expected "$CALLED"
            ${lib.getExe tasks.terraform.package} import 'cloudflare_workers_custom_domain.site["www.example.org"]' 'account/domain id'
            printf '%s\n' import 'cloudflare_workers_custom_domain.site["www.example.org"]' 'account/domain id' > expected
            cmp expected "$CALLED"
            touch $out
          '';
      };
    };
}
