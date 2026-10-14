# Editor data lives in Nix: language servers are editor-neutral, and editor
# plugins (`vscode`, `neovim`) write them out as generated files.
{
  flake.framework =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.editor;
    in
    {
      options.flake.editor = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.raw;
        default = { };
        description = "Evaluated project editor integration data.";
      };
      options.nullkomma.editor.languageServers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              command = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                description = "Command starting the language server, from the dev shell.";
              };
              filetypes = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                description = "File types the server handles.";
              };
              settings = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = { };
                description = "LSP settings sent to the server.";
              };
            };
          }
        );
        default = { };
        description = "Editor-neutral language servers; plugins add theirs here.";
      };
      options.nullkomma.editor.vscode = {
        extensions = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Project-relevant VS Code extension IDs; plugins append here. Installation belongs to the user environment.";
        };
        settings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Project-specific VS Code settings; plugins merge here. Personal preferences belong elsewhere.";
        };
      };
      config.flake.editor = {
        inherit (cfg) languageServers;
        vscode = {
          extensions = lib.sort lib.lessThan (lib.unique cfg.vscode.extensions);
          inherit (cfg.vscode) settings;
        };
      };
    };
  flake.plugins.vscode =
    { config, lib, ... }:
    {
      options.nullkomma.vscode.enable = lib.mkEnableOption "VS Code workspace files";
      config.perSystem =
        { pkgs, ... }:
        let
          json = pkgs.formats.json { };
          data = config.flake.editor.vscode;
        in
        {
          nullkomma.files = lib.mkIf config.nullkomma.vscode.enable {
            ".vscode/extensions.json" = {
              mode = lib.mkDefault "generated";
              commentPrefix = "//";
              source = json.generate "vscode-extensions.json" { recommendations = data.extensions; };
            };
            ".vscode/settings.json" = {
              mode = lib.mkDefault "generated";
              commentPrefix = "//";
              source = json.generate "vscode-settings.json" data.settings;
            };
          };
        };
    };
  flake.plugins.neovim =
    { config, lib, ... }:
    {
      options.nullkomma.neovim.enable = lib.mkEnableOption "Neovim project config (`.nvim.lua`, needs `exrc`)";
      config.perSystem.nullkomma.files.".nvim.lua" = lib.mkIf config.nullkomma.neovim.enable {
        mode = lib.mkDefault "generated";
        commentPrefix = "--";
        # shortcut: JSON in a Lua long string breaks if it contains `]==]`; switch to a Lua serializer then.
        text = ''
          for name, server in pairs(vim.json.decode([==[${
            builtins.toJSON (
              lib.mapAttrs (_: s: {
                cmd = s.command;
                inherit (s) filetypes settings;
              }) config.nullkomma.editor.languageServers
            )
          }]==])) do
            vim.lsp.config(name, server)
            vim.lsp.enable(name)
          end
        '';
      };
    };
}
