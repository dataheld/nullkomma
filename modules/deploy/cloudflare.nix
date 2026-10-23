{ inputs, ... }:
{
  plugins.cloudflare =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.cloudflare;
      label = "[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?";
      worker = if cfg.worker == null then cfg.name else cfg.worker;
      inferName = cfg.name == null && (cfg.domain != null || worker == null);
      siteName = if cfg.name == null then "\${var.site_name}" else cfg.name;
      workerName = if worker == null then siteName else worker;
    in
    {
      imports = [ inputs.terranix.flakeModule ];
      options.nullkomma.cloudflare = {
        domain = lib.mkOption {
          type = lib.types.nullOr (lib.types.strMatching "${label}(\\.${label})+");
          default = null;
          example = "example.org";
          description = "Existing Cloudflare zone serving `<name>.<domain>`; null disables the shorthand.";
        };
        name = lib.mkOption {
          type = lib.types.nullOr (lib.types.strMatching label);
          default = null;
          description = "Subdomain label and default Worker name; null infers the repository name from `GITHUB_REPOSITORY` or Git origin at deployment time.";
        };
        worker = lib.mkOption {
          type = lib.types.nullOr (lib.types.strMatching "[a-z0-9][a-z0-9-]*");
          default = cfg.name;
          defaultText = lib.literalExpression "config.nullkomma.cloudflare.name";
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
        nullkomma.privacy.sections.cloudflare = {
          order = 200;
          markdown = {
            en = ./_cloudflare/privacy.en.md;
            de = ./_cloudflare/privacy.de.md;
          };
        };
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
            validate = configuration: ''
              cd "$(mktemp -d)"
              ln -s ${configuration} config.tf.json
              ${lib.getExe tf.terraformWrapper.package} init -backend=false
              ${lib.getExe tf.terraformWrapper.package} validate
            '';
          in
          {
            nullkomma.devShell.packages = [ pkgs.wrangler ];
            # terranix also exports packages.deploy, whose .init, .plan, ... `nix run` falls back to.
            apps.deploy = {
              type = "app";
              program = lib.getExe config.packages.deploy;
              meta.description = "Publish the site to Cloudflare";
            };
            nullkomma.tasks = {
              deploy = {
                skip = true;
                description = "Publish the site to Cloudflare";
                packages = [ pkgs.nix ];
                command = ''exec nix run .#deploy -- "$@"'';
              };
              terraform = {
                skip = true;
                description = "Plan Cloudflare changes, or run terraform <command> [args]";
                packages = [ pkgs.nix ];
                command = ''
                  nix run .#deploy.init
                  if [[ $# == 0 ]]; then set -- plan; fi
                  exec nix run .#deploy.terraform -- "$@"
                '';
              };
            };
            terranix = {
              exportDevShells = false;
              terranixConfigurations.deploy = {
                workdir = ".nullkomma/cloudflare";
                terraformWrapper = {
                  package = pkgs.opentofu.withPlugins (_: [ provider ]);
                  extraRuntimeInputs = lib.optional inferName pkgs.git;
                  prefixText = ''
                    export TF_IN_AUTOMATION=1 TF_INPUT=0 TF_CLI_ARGS_apply=-auto-approve
                    ${lib.optionalString inferName ''
                      if [[ -n "''${GITHUB_REPOSITORY:-}" ]]; then
                        if [[ ! "$GITHUB_REPOSITORY" =~ ^[^/]+/[^/]+$ ]]; then
                          echo "GITHUB_REPOSITORY must be owner/repository; set nullkomma.cloudflare.name to override." >&2
                          exit 1
                        fi
                        name="''${GITHUB_REPOSITORY#*/}"
                      else
                        if ! repository="$(git remote get-url origin)"; then
                          echo "Cannot infer Cloudflare name; set nullkomma.cloudflare.name or configure Git origin." >&2
                          exit 1
                        fi
                        name="''${repository##*/}"
                        name="''${name%.git}"
                      fi
                      if [[ ! "$name" =~ ^${label}$ ]]; then
                        echo "Cloudflare repository name must be a lowercase DNS label (1-63 characters); set nullkomma.cloudflare.name." >&2
                        exit 1
                      fi
                      export TF_VAR_site_name="$name"
                    ''}
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
                      key = "${workerName}.tfstate";
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
                  variable.site_name = lib.mkIf inferName {
                    type = "string";
                    validation = {
                      condition = "\${can(regex(\"^${label}$\", var.site_name))}";
                      error_message = "Cloudflare name must be a lowercase DNS label (1-63 characters).";
                    };
                  };
                  resource = {
                    cloudflare_workers_script.site = {
                      inherit account_id;
                      script_name = workerName;
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
                    cloudflare_workers_custom_domain =
                      lib.mapAttrs' (
                        hostname: zone_id:
                        lib.nameValuePair (lib.replaceStrings [ "." ] [ "_" ] hostname) {
                          inherit account_id hostname zone_id;
                          service = script_name;
                        }
                      ) cfg.domains
                      // lib.optionalAttrs (cfg.domain != null) {
                        subdomain = {
                          inherit account_id;
                          hostname =
                            if cfg.name != null && builtins.hasAttr "${cfg.name}.${cfg.domain}" cfg.domains then
                              throw "The derived Cloudflare hostname is also declared in nullkomma.cloudflare.domains; remove the duplicate declaration."
                            else
                              "${siteName}.${cfg.domain}";
                          zone_name = cfg.domain;
                          service = script_name;
                        }
                        // lib.optionalAttrs (cfg.name == null) {
                          lifecycle.precondition = lib.singleton {
                            condition = "\${!contains(${builtins.toJSON (lib.attrNames cfg.domains)}, \"${siteName}.${cfg.domain}\")}";
                            error_message = "The derived Cloudflare hostname is also declared in nullkomma.cloudflare.domains; remove the duplicate declaration.";
                          };
                        };
                      };
                  };
                };
              };
            };
            nullkomma.checks.cloudflare = {
              packages = [ pkgs.nix ];
              command = ''
                configuration="$(nix build --no-link --print-out-paths .#deploy.config)"
                ${validate ''"$configuration"''}
              '';
              sandboxed = pkgs.runCommand "check-cloudflare" { } ''
                export HOME="$TMPDIR"
                ${validate tf.result.terraformConfiguration}
                touch "$out"
              '';
            };
          };
      };
    };
}
