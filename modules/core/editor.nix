# Editor data lives in Nix: language servers are editor-neutral, and editor
# plugins (`vscode`, `neovim`) write them out as generated files.
{
  framework =
    { flake-parts-lib, lib, ... }:
    {
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { config, ... }:
        let
          cfg = config.nullkomma.editor;
        in
        {
          options.nullkomma.editor = {
            languageServers = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options = {
                    package = lib.mkOption {
                      type = lib.types.package;
                      description = "Package providing the server, put in the dev shell.";
                    };
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
            formatter = lib.mkOption {
              type = lib.types.nullOr (
                lib.types.submodule {
                  options = {
                    package = lib.mkOption {
                      type = lib.types.package;
                      description = "Package providing the formatter, put in the dev shell.";
                    };
                    command = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      description = "Command formatting stdin as the file `{file}`, from the dev shell.";
                    };
                  };
                }
              );
              default = null;
              description = "Formatter editors and language servers use when set.";
            };
            vscode = {
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
          };
          config.nullkomma.devShell.packages =
            lib.mapAttrsToList (_: s: s.package) cfg.languageServers
            ++ lib.optional (cfg.formatter != null) cfg.formatter.package;
        }
      );
    };
  plugins.vscode =
    { config, lib, ... }:
    let
      enabled = config.nullkomma.vscode.enable;
    in
    {
      config.perSystem =
        { config, pkgs, ... }:
        let
          json = pkgs.formats.json { };
          cfg = config.nullkomma.editor.vscode;
        in
        {
          nullkomma.files = lib.mkIf enabled {
            ".vscode/extensions.json" = {
              mode = lib.mkDefault "generated";
              commentPrefix = "//";
              source = json.generate "vscode-extensions.json" {
                recommendations = lib.sort lib.lessThan (lib.unique cfg.extensions);
              };
            };
            ".vscode/mcp.json" = {
              mode = lib.mkDefault "generated";
              commentPrefix = "//";
              source = json.generate "vscode-mcp.json" {
                servers.nullkomma = {
                  type = "stdio";
                }
                // config.taskRunners.default.mcpServer;
              };
            };
            ".vscode/settings.json" = {
              mode = lib.mkDefault "generated";
              commentPrefix = "//";
              source = json.generate "vscode-settings.json" cfg.settings;
            };
          };
        };
    };
  plugins.neovim =
    { config, lib, ... }:
    let
      enabled = config.nullkomma.neovim.enable;
    in
    {
      config.perSystem =
        { config, ... }:
        {
          nullkomma.files.".nvim.lua" = lib.mkIf enabled {
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
            ''
            + lib.optionalString (config.nullkomma.editor.formatter != null) ''
              vim.api.nvim_create_user_command("Format", function()
                local file = vim.api.nvim_buf_get_name(0)
                if file == "" then
                  vim.notify("Save the buffer before formatting", vim.log.levels.ERROR)
                  return
                end
                local command = vim.json.decode([==[${builtins.toJSON config.nullkomma.editor.formatter.command}]==])
                for i, arg in ipairs(command) do
                  command[i] = arg:gsub("{file}", function() return file end)
                end
                local input = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
                  .. (vim.bo.endofline and "\n" or "")
                local result = vim.system(command, {
                  stdin = input, text = true, cwd = vim.fs.dirname(file),
                }):wait()
                if result.code ~= 0 then
                  vim.notify(result.stderr, vim.log.levels.ERROR)
                  return
                end
                local view = vim.fn.winsaveview()
                local lines = vim.split(result.stdout, "\n", { plain = true })
                local endofline = lines[#lines] == ""
                if endofline then table.remove(lines) end
                vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
                vim.bo.endofline = endofline
                vim.fn.winrestview(view)
              end, { desc = "Format this buffer with the project's formatter" })
            '';
          };
        };
    };
}
