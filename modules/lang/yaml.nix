{
  plugins.yaml =
    { config, lib, ... }:
    {
      config = lib.mkIf config.nullkomma.yaml.enable {
        nullkomma.lint.yaml = {
          extends = lib.mkDefault "relaxed";
          rules.line-length = lib.mkDefault "disable";
        };
        perSystem =
          { pkgs, ... }:
          {
            nullkomma.editor.languageServers.yamlls = {
              package = pkgs.yaml-language-server;
              command = [
                "yaml-language-server"
                "--stdio"
              ];
              filetypes = [ "yaml" ];
            };
            nullkomma.editor.vscode.extensions = [ "redhat.vscode-yaml" ];
            treefmt.programs.actionlint.enable = lib.mkDefault true;
            treefmt.programs.yamlfmt.enable = lib.mkDefault true;
            treefmt.programs.yamllint = {
              enable = lib.mkDefault true;
              priority = 1;
              package = pkgs.writeShellScriptBin "yamllint" ''
                export NULLKOMMA_YAMLLINT_CONFIG=${
                  (pkgs.formats.yaml { }).generate "nullkomma-yamllint.yaml" config.nullkomma.lint.yaml
                }
                exec ${
                  lib.getExe (
                    pkgs.yamllint.overrideAttrs (old: {
                      postPatch = (old.postPatch or "") + ''
                        # Extend before validation fills in upstream per-rule defaults.
                        substituteInPlace yamllint/config.py \
                          --replace-fail 'def __init__(self, content=None, file=None):' \
                          'def __init__(self, content=None, file=None, base=None):' \
                          --replace-fail '        self.parse(content)' ${
                            lib.escapeShellArg (
                              lib.concatStringsSep "\n" [
                                "        self.parse(content)"
                                "        if base is not None:"
                                "            ignore = self.ignore"
                                "            self.extend(base)"
                                "            if ignore is not None:"
                                "                self.ignore = base.ignore + ignore if base.ignore is not None else ignore"
                              ]
                            )
                          }
                        substituteInPlace yamllint/cli.py \
                          --replace-fail '    project_config_filepath = find_project_config_filepath()' ${
                            lib.escapeShellArg (
                              lib.concatStringsSep "\n" [
                                "    shared_path = os.environ.get('NULLKOMMA_YAMLLINT_CONFIG')"
                                "    shared = YamlLintConfig(file=shared_path) if shared_path else None"
                                "    project_config_filepath = find_project_config_filepath()"
                              ]
                            )
                          } \
                          --replace-fail 'conf = YamlLintConfig(content=args.config_data)' 'conf = YamlLintConfig(content=args.config_data, base=shared)' \
                          --replace-fail 'conf = YamlLintConfig(file=args.config_file)' 'conf = YamlLintConfig(file=args.config_file, base=shared)' \
                          --replace-fail 'conf = YamlLintConfig(file=project_config_filepath)' 'conf = YamlLintConfig(file=project_config_filepath, base=shared)' \
                          --replace-fail 'conf = YamlLintConfig(file=user_global_config)' 'conf = YamlLintConfig(file=user_global_config, base=shared)' \
                          --replace-fail "conf = YamlLintConfig('extends: default')" "conf = shared if shared is not None else YamlLintConfig('extends: default')"
                      '';
                    })
                  )
                } "$@"
              '';
            };
          };
      };
    };
}
