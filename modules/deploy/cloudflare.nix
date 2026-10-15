{ inputs, ... }:
{
  plugins.cloudflare =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.cloudflare;
    in
    {
      imports = [ inputs.terranix.flakeModule ];
      options.nullkomma.cloudflare = {
        worker = lib.mkOption {
          type = lib.types.strMatching "[a-z0-9][a-z0-9-]*";
          description = "Worker serving `packages.site`; also keys its Terraform state.";
        };
        domains = lib.mkOption {
          type = lib.types.attrsOf (lib.types.strMatching "[0-9a-f]{32}");
          default = { };
          example."www.example.org" = "023e105f4ecef8ad9ca31a8372d0c353";
          description = "Custom hostnames and their zone IDs; Cloudflare manages their DNS records and certificates.";
        };
      };
      config = lib.mkIf cfg.enable {
        nullkomma.gitignore = [ "/.nullkomma/cloudflare/" ];
        perSystem =
          { config, pkgs, ... }:
          let
            inherit (config.packages) site;
            tf = config.terranix.terranixConfigurations.deploy;
            provider =
              (import inputs.terraform-providers-bin { nixpkgs = pkgs; }).providers.cloudflare.cloudflare;
            account_id = "\${var.account_id}";
            script_name = "\${cloudflare_workers_script.site.script_name}";
            # Like Wrangler, pass these as settings rather than publishing them;
            # the provider uploads every file in the assets directory.
            optionalFile = name: "\${fileexists(\"${site}/${name}\") ? file(\"${site}/${name}\") : null}";
            assets = pkgs.runCommand "site-assets" { } ''
              cp -r ${site} $out
              chmod -R u+w $out
              rm -f $out/_headers $out/_redirects
            '';
          in
          {
            nullkomma.devHelpers = [ pkgs.wrangler ];
            nullkomma.tasks = {
              deploy = {
                skip = true;
                description = "Publish the site to Cloudflare";
                command = "exec ${lib.getExe tf.result.app}";
              };
              terraform = {
                skip = true;
                description = "Plan Cloudflare changes, or run terraform <command> [args]";
                command = ''
                  ${lib.getExe tf.result.scripts.init}
                  if [[ $# == 0 ]]; then set -- plan; fi
                  exec ${lib.getExe tf.result.terraformWrapper} "$@"
                '';
              };
            };
            terranix = {
              exportDevShells = false;
              terranixConfigurations.deploy = {
                workdir = ".nullkomma/cloudflare";
                terraformWrapper = {
                  package = pkgs.opentofu.withPlugins (_: [ provider ]);
                  prefixText = ''
                    if [[ ! "''${CLOUDFLARE_ACCOUNT_ID:-}" =~ ^[0-9a-f]{32}$ ]]; then
                      echo "CLOUDFLARE_ACCOUNT_ID must be the 32-character account ID, not an API token" >&2
                      exit 1
                    fi
                    export TF_IN_AUTOMATION=1 TF_INPUT=0 TF_CLI_ARGS_apply=-auto-approve
                    export TF_VAR_account_id="''${CLOUDFLARE_ACCOUNT_ID:?}"
                    export AWS_ENDPOINT_URL_S3="https://$CLOUDFLARE_ACCOUNT_ID.r2.cloudflarestorage.com"
                    export TF_CLI_ARGS_init="-backend-config=bucket=''${CLOUDFLARE_STATE_BUCKET:?}"
                  '';
                };
                modules = lib.singleton {
                  terraform = {
                    required_providers.cloudflare = {
                      source = "cloudflare/cloudflare";
                      inherit (provider) version;
                    };
                    backend.s3 = {
                      key = "${cfg.worker}.tfstate";
                      region = "auto";
                      use_lockfile = true;
                      use_path_style = true;
                    }
                    // lib.genAttrs [
                      "skip_credentials_validation"
                      "skip_metadata_api_check"
                      "skip_region_validation"
                      "skip_requesting_account_id"
                      "skip_s3_checksum"
                    ] (_: true);
                  };
                  variable.account_id.type = "string";
                  resource = {
                    cloudflare_workers_script.site = {
                      inherit account_id;
                      script_name = cfg.worker;
                      assets = {
                        directory = "${assets}";
                        config = {
                          not_found_handling = "404-page";
                          headers = optionalFile "_headers";
                          redirects = optionalFile "_redirects";
                        };
                      };
                    };
                    # Serve only on the custom domains.
                    cloudflare_workers_script_subdomain.site = {
                      inherit account_id script_name;
                      enabled = false;
                      previews_enabled = false;
                    };
                    cloudflare_workers_custom_domain = lib.mapAttrs' (
                      hostname: zone_id:
                      lib.nameValuePair (lib.replaceStrings [ "." ] [ "_" ] hostname) {
                        inherit account_id hostname zone_id;
                        service = script_name;
                      }
                    ) cfg.domains;
                  };
                };
              };
            };
            nullkomma.tests.cloudflare = {
              packages = [ tf.terraformWrapper.package ];
              command = ''
                cd "$(mktemp -d)"
                ln -s ${tf.result.terraformConfiguration} config.tf.json
                tofu init -backend=false
                tofu validate
              '';
            };
          };
      };
    };
}
