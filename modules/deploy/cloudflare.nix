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
        projectName = lib.mkOption {
          type = lib.types.strMatching "[a-z0-9][a-z0-9-]*";
          description = "Cloudflare Pages project name.";
        };
        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional Pages custom hostname. Its DNS record belongs to the zone owner, not this plugin.";
        };
        productionBranch = lib.mkOption {
          type = lib.types.str;
          default = "main";
          description = "Pages production branch, also passed explicitly to uploads.";
        };
        stateKey = lib.mkOption {
          type = lib.types.str;
          default = "${cfg.projectName}.tfstate";
          defaultText = lib.literalMD "`projectName + \".tfstate\"`";
          description = "Object key in the existing private R2 state bucket.";
        };
      };
      config = lib.mkIf cfg.enable {
        nullkomma.gitignore = [ "/.nullkomma/cloudflare/" ];
        perSystem =
          { config, pkgs, ... }:
          let
            site =
              if config.nullkomma.site == null then
                throw "nullkomma.cloudflare: set perSystem.nullkomma.site to a static assets package"
              else
                config.nullkomma.site;
            provider =
              (import inputs.terraform-providers-bin { nixpkgs = pkgs; }).providers.cloudflare.cloudflare;
            tofu = pkgs.opentofu.withPlugins (_: [ provider ]);
            terraform = config.terranix.terranixConfigurations.cloudflare.result.terraformWrapper;
            tfConfig = config.terranix.terranixConfigurations.cloudflare.result.terraformConfiguration;
          in
          {
            terranix = {
              exportDevShells = false;
              terranixConfigurations.cloudflare = {
                workdir = ".nullkomma/cloudflare";
                terraformWrapper = {
                  package = tofu;
                  prefixText = ''
                    if [[ "''${GITHUB_ACTIONS-}" != true ]]; then
                      case "$*" in
                        "validate" | "init -backend=false -input=false") ;;
                        *)
                          echo "nullkomma.cloudflare: remote Terraform operations require GitHub Actions" >&2
                          exit 1
                          ;;
                      esac
                    fi
                    : "''${CLOUDFLARE_ACCOUNT_ID:?Set CLOUDFLARE_ACCOUNT_ID}"
                    : "''${CLOUDFLARE_STATE_BUCKET:?Set CLOUDFLARE_STATE_BUCKET to an existing private R2 bucket}"
                    if [[ ! "$CLOUDFLARE_ACCOUNT_ID" =~ ^[a-f0-9]{32}$ ]]; then
                      echo "nullkomma.cloudflare: CLOUDFLARE_ACCOUNT_ID must be 32 lowercase hexadecimal characters" >&2
                      exit 1
                    fi
                    export TF_VAR_cloudflare_account_id="$CLOUDFLARE_ACCOUNT_ID"
                    ln -sf ${tfConfig} config.tf.json
                    if [[ "''${1-}" == init ]]; then
                      # Nix pins providers; old local wrapper checksums must not override that pin.
                      rm -f .terraform.lock.hcl
                      set -- "$@" \
                        "-backend-config=bucket=$CLOUDFLARE_STATE_BUCKET" \
                        "-backend-config=endpoints={s3=\"https://$CLOUDFLARE_ACCOUNT_ID.r2.cloudflarestorage.com\"}"
                    fi
                  '';
                };
                modules = [
                  {
                    terraform = {
                      required_providers.cloudflare = {
                        source = "cloudflare/cloudflare";
                        version = provider.version;
                      };
                      backend.s3 = {
                        key = cfg.stateKey;
                        region = "auto";
                        use_lockfile = true;
                        use_path_style = true;
                        skip_credentials_validation = true;
                        skip_metadata_api_check = true;
                        skip_region_validation = true;
                        skip_requesting_account_id = true;
                        skip_s3_checksum = true;
                      };
                    };
                    variable.cloudflare_account_id.type = "string";
                    provider.cloudflare = { };
                    resource = {
                      cloudflare_pages_project.site = {
                        account_id = "\${var.cloudflare_account_id}";
                        name = cfg.projectName;
                        production_branch = cfg.productionBranch;
                        lifecycle.prevent_destroy = true;
                      };
                    }
                    // lib.optionalAttrs (cfg.domain != null) {
                      cloudflare_pages_domain.site = {
                        account_id = "\${var.cloudflare_account_id}";
                        project_name = "\${cloudflare_pages_project.site.name}";
                        name = cfg.domain;
                        lifecycle.prevent_destroy = true;
                      };
                    };
                  }
                ];
              };
            };
            nullkomma.tasks = {
              terraform = {
                description = "Manage the Pages infrastructure and R2 state with OpenTofu";
                skip = true;
                command = ''exec ${lib.getExe terraform} "$@"'';
              };
              deploy = {
                description = "Apply the Pages infrastructure, then upload the static site";
                skip = true;
                packages = [ pkgs.wrangler ];
                command = ''
                  if [[ "''${GITHUB_ACTIONS-}" != true ]]; then
                    echo "nullkomma.cloudflare: deployment requires GitHub Actions" >&2
                    exit 1
                  fi
                  : "''${CLOUDFLARE_API_TOKEN:?Set CLOUDFLARE_API_TOKEN}"
                  : "''${CLOUDFLARE_ACCOUNT_ID:?Set CLOUDFLARE_ACCOUNT_ID}"
                  : "''${CLOUDFLARE_STATE_BUCKET:?Set CLOUDFLARE_STATE_BUCKET to an existing private R2 bucket}"
                  : "''${AWS_ACCESS_KEY_ID:?Set AWS_ACCESS_KEY_ID for R2 state}"
                  : "''${AWS_SECRET_ACCESS_KEY:?Set AWS_SECRET_ACCESS_KEY for R2 state}"
                  if [[ ! -f ${site}/index.html ]]; then
                    echo "nullkomma.cloudflare: static assets package is missing index.html" >&2
                    exit 1
                  fi
                  ${lib.getExe terraform} init -input=false
                  ${lib.getExe terraform} apply "$@"
                  exec wrangler pages deploy ${site} \
                    --project-name ${lib.escapeShellArg cfg.projectName} \
                    --branch ${lib.escapeShellArg cfg.productionBranch}
                '';
              };
            };
            packages.deploy = config.nullkomma.tasks.deploy.package;
            nullkomma.tests.cloudflare = {
              packages = [
                pkgs.coreutils
                tofu
              ];
              command = ''
                scratch="$(mktemp -d)"
                trap 'rm -rf "$scratch"' EXIT
                export HOME="$scratch"
                cd "$scratch"
                cp ${tfConfig} config.tf.json
                tofu init -backend=false -input=false
                tofu validate
              '';
            };
          };
      };
    };
}
