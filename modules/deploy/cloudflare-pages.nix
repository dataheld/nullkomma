# Deploys `nullkomma.site` to Cloudflare Pages: `nix run .#deploy` locally, or
# from CI on pushes to the default branch (needs the two secrets below).
{ inputs, ... }:
{
  flake.flakeModules.cloudflare-pages =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.cloudflare-pages;
    in
    {
      imports = [ inputs.self.flakeModules.default ];
      options.nullkomma.cloudflare-pages = {
        project = lib.mkOption {
          type = lib.types.str;
          example = "my-docs";
          description = "Cloudflare Pages project name.";
        };
        branch = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Cloudflare Pages branch; null uses the project's production branch.";
        };
      };
      config = {
        nullkomma.github.ci = {
          inputs.deploy = true;
          secrets = [
            "CLOUDFLARE_ACCOUNT_ID"
            "CLOUDFLARE_API_TOKEN"
          ];
        };
        perSystem =
          { config, pkgs, ... }:
          {
            nullkomma.tasks.deploy = {
              description = "Deploy the site to Cloudflare Pages (needs CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID)";
              runtimeInputs = [ pkgs.wrangler ];
              command = ''
                exec wrangler pages deploy ${
                  if config.nullkomma.site == null then
                    throw "nullkomma.cloudflare-pages: no `nullkomma.site`; import a docs aspect such as flakeModules.quarto"
                  else
                    config.nullkomma.site
                } ${
                  lib.escapeShellArgs (
                    [
                      "--project-name"
                      cfg.project
                    ]
                    ++ lib.optionals (cfg.branch != null) [
                      "--branch"
                      cfg.branch
                    ]
                  )
                } "$@"
              '';
            };
          };
      };
    };
}
