{
  partitions.dev.module.perSystem =
    {
      config,
      harness,
      pkgs,
      ...
    }:
    let
      site = config.packages.site;
      deploy = config.terranix.terranixConfigurations.deploy;
    in
    {
      checks.site = harness.linkcheck "documentation-site" site;
      checks.site-legal = harness.legalcheck "site-legal" site;
      checks.site-deploy =
        pkgs.runCommand "documentation-site-deploy"
          {
            nativeBuildInputs = [
              deploy.terraformWrapper.package
              pkgs.jq
            ];
          }
          ''
            export HOME=$TMPDIR
            export CLOUDFLARE_API_TOKEN=0000000000000000000000000000000000000000
            export TF_VAR_account_id=00000000000000000000000000000000
            export TF_VAR_site_name=nullkomma
            export HTTPS_PROXY=http://127.0.0.1:1
            jq 'del(.terraform.backend)' ${deploy.result.terraformConfiguration} > config.tf.json
            tofu init -backend=false > /dev/null
            tofu plan -refresh=false -out=plan > /dev/null
            tofu show -json plan | jq -e '
              .planned_values.root_module.resources | map({key: .address, value: .values}) | from_entries
              | ."cloudflare_workers_script.site" as $worker
              | ."cloudflare_workers_custom_domain.subdomain" as $domain
              | $worker.script_name == "nullkomma"
                and $domain.hostname == "nullkomma.maxheld.de"
                and $domain.zone_name == "maxheld.de"
                and $domain.service == $worker.script_name
                and (."cloudflare_workers_script_subdomain.site" | .enabled == false and .previews_enabled == false)
            '
            assets=$(jq -r .resource.cloudflare_workers_script.site.assets.directory ${deploy.result.terraformConfiguration})
            diff -r ${site} "$assets"
            grep -q 'https://nullkomma.maxheld.de/' "$assets/sitemap.xml"
            grep -q 'Cloudflare' "$assets/privacy.html"
            touch "$out"
          '';
    };
}
