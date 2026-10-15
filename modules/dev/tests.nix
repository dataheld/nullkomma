# Contract tests: fixtures and templates are evaluated as consumers would,
# with their checks and devshells becoming checks of nullkomma itself.
{
  partitions.dev.module =
    { inputs, lib, ... }:
    let
      nullkomma = inputs.self;
      plugins = removeAttrs nullkomma.flakeModules [
        "default"
        "framework"
      ];
      callFlakeWith =
        module: src:
        let
          flake = import (src + "/flake.nix");
          debugged = nullkomma // {
            lib = nullkomma.lib // {
              mkFlake =
                args: consumer:
                nullkomma.lib.mkFlake args {
                  imports = [
                    consumer
                    module
                  ];
                  debug = true;
                };
            };
          };
          flakeInputs = {
            self = self';
            nullkomma = debugged;
            inherit (nullkomma.inputs) nixpkgs;
          };
          outputs = flake.outputs flakeInputs;
          self' = outputs // {
            _type = "flake";
            outPath = src;
            sourceInfo.outPath = src;
            inputs = flakeInputs;
            inherit outputs;
          };
        in
        self';
      callFlake = callFlakeWith { };
      fixtures = {
        md = callFlake ../../tests/fixtures/md;
        quarto = callFlake ../../tests/fixtures/quarto;
        shell = callFlake ../../tests/fixtures/shell;
      };
      cloudflare = callFlakeWith {
        nullkomma.cloudflare = {
          enable = true;
          worker = "fixture-site";
          domains."www.example.org" = "11111111111111111111111111111111";
        };
      } ../../tests/fixtures/quarto;
      batsFailing = callFlakeWith {
        nullkomma.shell.bats.testDir = "failing";
      } ../../tests/fixtures/shell;
      customized = callFlakeWith {
        perSystem =
          { pkgs, ... }:
          {
            nullkomma.editor.vscode.settings."nix.serverPath" = "project-nixd";
            nullkomma.devHelpers = [ pkgs.hello ];
            treefmt.programs.deadnix.enable = false;
            treefmt.programs.typos.enable = true;
          };
      } ../../tests/fixtures/md;
      fileSelection = callFlakeWith {
        perSystem.nullkomma.files = {
          ".vscode/settings.json".mode = "source";
          ".vscode/extensions.json".enable = false;
          "disabled-local" = {
            enable = false;
            mode = "generated";
            commentPrefix = "#";
            text = "";
          };
        };
      } ../../tests/fixtures/md;
      # Toggles each plugin; opt-in plugins are enabled instead.
      toggled = lib.genAttrs (lib.attrNames plugins) (
        name:
        callFlakeWith {
          imports = [ { nullkomma.cloudflare.worker = "fixture-site"; } ];
          nullkomma.${name}.enable = !fixtures.md.debug.config.nullkomma.${name}.enable;
        } ../../tests/fixtures/md
      );
      bareCloudflare = {
        imports = [ plugins.cloudflare ];
        nullkomma.cloudflare = {
          enable = true;
          worker = "bare-site";
        };
        perSystem =
          { pkgs, ... }:
          {
            packages.site = pkgs.writeTextDir "index.html" "";
          };
      };
      minimal = callFlakeWith {
        nullkomma =
          lib.genAttrs (lib.attrNames plugins) (_: {
            enable = false;
          })
          // {
            devshell.enable = false;
          };
      } ../../tests/fixtures/md;
      raw =
        module:
        inputs.flake-parts.lib.mkFlake
          {
            inputs.self.outPath = ../../tests/fixtures/md;
          }
          {
            imports = [
              nullkomma.flakeModules.framework
              module
            ];
            debug = true;
          };
      rawFramework = raw { };
      rawUnselected = raw {
        imports = lib.attrValues plugins;
      };
      rawTest = raw { perSystem.nullkomma.tests.custom.command = "true"; };
      rawNixUnit = raw {
        imports = [ plugins.nix ];
        nullkomma.nix.enable = true;
        perSystem.nullkomma.nix.unit.tests.testTrue = {
          expr = true;
          expected = true;
        };
      };
      rawNix = raw {
        imports = [ plugins.nix ];
        nullkomma.nix.enable = true;
      };
      fileVersions = lib.genAttrs [ "old" "new" ] (
        version:
        raw {
          perSystem.nullkomma.files = {
            "source.txt".text = version;
            "untouched.txt".text = version;
            "generated.txt" = {
              text = version;
              mode = "generated";
              commentPrefix = "#";
            };
          };
        }
      );
      agentPluginManifest = builtins.fromJSON (builtins.readFile ../../plugin.json);
      templates = lib.mapAttrs (_: t: callFlake t.path) nullkomma.templates;
      # Every way to import nullkomma at once; keys make the module system import each once.
      overlapping = callFlakeWith {
        imports = [
          nullkomma.flakeModules.framework
          nullkomma.flakeModules.nix
          nullkomma.modules.flake.nix
          nullkomma.modules.flake.default
        ];
      } ../../tests/fixtures/md;
    in
    {
      perSystem =
        { pkgs, system, ... }:
        let
          perSystem = flake: flake.allSystems.${system};
          tfConfig =
            flake: (perSystem flake).terranix.terranixConfigurations.deploy.result.terraformConfiguration;
          importTreeRoot = ../../tests/fixtures/import-tree;
          # What plugins can contribute to a consumer flake.
          summary = flake: {
            files = lib.attrNames (perSystem flake).nullkomma.files;
            tools = map lib.getName (perSystem flake).nullkomma.devshell.packages;
            formatters = lib.attrNames (perSystem flake).treefmt.build.programs;
            tasks = lib.attrNames (perSystem flake).nullkomma.tasks;
            checks = lib.attrNames flake.checks.${system};
            shells = lib.attrNames flake.devShells.${system};
            editor =
              let
                inherit ((perSystem flake).nullkomma) editor;
              in
              {
                formatter = if editor.formatter == null then null else editor.formatter.command;
                languageServers = lib.mapAttrs (_: s: removeAttrs s [ "package" ]) editor.languageServers;
                inherit (editor) vscode;
              };
          };
          tests = {
            # keep-sorted start block=yes
            testAgentPluginExposesCanonicalConflictSkill = {
              expr = {
                inherit (agentPluginManifest) name;
                schema = agentPluginManifest."$schema";
                skillExists = builtins.pathExists ../../skills/resolve-file-conflicts/SKILL.md;
                skillUsesCanonicalSource =
                  builtins.readFile ../../skills/resolve-file-conflicts/SKILL.md
                  == builtins.readFile ../../.github/skills/resolve-file-conflicts/SKILL.md;
              };
              expected = {
                name = "nullkomma";
                schema = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json";
                skillExists = true;
                skillUsesCanonicalSource = true;
              };
            };
            testAllPluginsDisabledIsBareFramework = {
              expr = map summary [
                rawFramework
                rawUnselected
                minimal
              ];
              expected = lib.replicate 3 {
                files = [ ];
                tools = [
                  "generate-files"
                  "write-files"
                  "tasks"
                ];
                formatters = [ ];
                tasks = [
                  "generate-files"
                  "write-files"
                ];
                checks = [ ];
                shells = [ ];
                editor = {
                  formatter = null;
                  languageServers = { };
                  vscode = {
                    extensions = [ ];
                    settings = { };
                  };
                };
              };
            };
            testCloudflareComposesWithAnySite = {
              expr = {
                packages = lib.attrNames (raw bareCloudflare).packages.${system};
                checks = lib.attrNames (raw bareCloudflare).checks.${system};
              };
              expected = {
                packages = [
                  "deploy"
                  "site"
                ];
                checks = [ "test-cloudflare" ];
              };
            };
            testConsumersCustomizeDefaults = {
              expr = {
                package = lib.elem pkgs.hello (perSystem customized).nullkomma.devshell.packages;
                disabled = (perSystem customized).treefmt.programs.deadnix.enable;
                enabled = (perSystem customized).treefmt.programs.typos.enable;
                setting = (perSystem customized).nullkomma.editor.vscode.settings."nix.serverPath";
              };
              expected = {
                package = true;
                disabled = false;
                enabled = true;
                setting = "project-nixd";
              };
            };
            testEveryPluginCanBeDisabled = {
              expr = lib.filter (name: summary toggled.${name} == summary fixtures.md) (lib.attrNames plugins);
              expected = [ ];
            };
            testGitignoreContainsPluginPatternsAndGeneratedFiles = {
              expr = (perSystem fixtures.md).nullkomma.files.".gitignore".text;
              expected = lib.concatLines [
                "result"
                "result-*"
                ".direnv/"
                "/.nvim.lua"
                "/.vscode/extensions.json"
                "/.vscode/settings.json"
              ];
            };
            testGitignoreRespectsFileSelection = {
              expr = (perSystem fileSelection).nullkomma.files.".gitignore".text;
              expected = lib.concatLines [
                "result"
                "result-*"
                ".direnv/"
                "/.nvim.lua"
              ];
            };
            testImportTreeSkipsUnderscoresAndNonNix = {
              expr = map (lib.removePrefix (toString importTreeRoot)) (
                map toString (nullkomma.lib.importTree importTreeRoot)
              );
              expected = [
                "/a.nix"
                "/sub/b.nix"
              ];
            };
            testImportingModulesTwiceIsHarmless =
              let
                # Import order may change list order, not contents.
                normalize =
                  v:
                  if lib.isList v then
                    lib.sort lib.lessThan v
                  else if lib.isAttrs v then
                    lib.mapAttrs (_: normalize) v
                  else
                    v;
              in
              {
                expr = normalize (summary overlapping);
                expected = normalize (summary fixtures.md);
              };
            testNixUnitTestsBecomeTest = {
              expr = {
                checks = lib.filter (lib.hasPrefix "test-") (summary rawNixUnit).checks;
                tests = lib.attrNames rawNixUnit.tests.systems.${system};
                schema = rawNixUnit.schemas ? tests;
                withoutTests = rawNix.tests.systems.${system};
              };
              expected = {
                checks = [ "test-nix-unit" ];
                tests = [ "testTrue" ];
                schema = true;
                withoutTests = { };
              };
            };
            testPluginWorksWithoutOthers = {
              expr = {
                inherit (summary rawNix) formatters;
                inherit ((perSystem rawNix).nullkomma.editor.languageServers.nixd) settings;
              };
              expected = {
                formatters = [
                  "deadnix"
                  "nixf-diagnose"
                  "nixfmt"
                ];
                settings = { };
              };
            };
            testTasksAllSkipsMutatingTasks = {
              expr = lib.attrNames (
                lib.filterAttrs (_: t: !(t.skip or false)) (perSystem fixtures.md).nullkomma.tasks
              );
              expected = [
                "check"
                "flake-checker"
              ];
            };
            testTemplatesAreFixtures = {
              expr = builtins.readFile ../../templates/default/flake.nix;
              expected = builtins.readFile ../../tests/fixtures/md/flake.nix;
            };
            testTemplatesIncludeDirenvBootstrap = {
              expr = builtins.readFile (nullkomma.templates.default.path + "/.envrc");
              expected = (perSystem templates.default).nullkomma.files.".envrc".text;
            };
            testTestsBecomeTaskAndCheck = {
              expr = {
                inherit (summary rawTest) tasks checks;
              };
              expected = {
                tasks = [
                  "generate-files"
                  "test"
                  "write-files"
                ];
                checks = [ "test-custom" ];
              };
            };
            # keep-sorted end
          };
          fixtureChecks = lib.concatMapAttrs (
            name: flake:
            lib.mapAttrs' (check: lib.nameValuePair "fixture-${name}-${check}") (
              flake.checks.${system}
              // {
                devshell = flake.devShells.${system}.default;
              }
            )
          ) fixtures;
          # One invalid file per formatter, checked by both the derivation and the real CLI.
          rejects = {
            nix = {
              file = "unformatted.nix";
              content = "{foo=1;}\n";
              expect = [
                "diff --git a/unformatted.nix b/unformatted.nix"
                "+{ foo = 1; }"
              ];
            };
            markdown = {
              file = "unformatted.md";
              content = "# Title\n* item\n";
              expect = [
                "diff --git a/unformatted.md b/unformatted.md"
                "+- item"
              ];
            };
          };
        in
        {
          # Sandboxed: nix-unit re-evaluates this flake with its inputs passed in.
          nullkomma.nix.unit.tests = tests;
          nullkomma.tasks.check-fixtures = {
            description = "Check a real consumer flake accepts valid input and rejects formatting drift";
            packages = [
              pkgs.coreutils
              pkgs.flake-checker
              pkgs.git
              pkgs.gnugrep
            ];
            command = ''
              root="$(git rev-parse --show-toplevel)"
              scratch="$(mktemp -d)"
              trap 'rm -rf "$scratch"' EXIT
              mkdir "$scratch/project"
              cp "$root/tests/fixtures/md/flake.nix" "$root/tests/fixtures/md/README.md" "$scratch/project/"
              check() {
                nix flake check "path:$scratch/project" \
                  --override-input nullkomma "path:$root" \
                  --no-write-lock-file --print-build-logs
              }
              check
              # Consumer CI lints the lock; its Nixpkgs must be visible as a root input.
              nix flake lock "path:$scratch/project" --override-input nullkomma "path:$root"
              flake-checker --no-telemetry --fail-mode "$scratch/project/flake.lock"
              rm "$scratch/project/flake.lock"
            ''
            + lib.concatMapStrings (case: ''

              printf %s ${lib.escapeShellArg case.content} > "$scratch/project/${case.file}"
              if check > "$scratch/failure.log" 2>&1; then
                echo "Consumer with invalid ${case.file} unexpectedly passed nix flake check" >&2
                exit 1
              fi
              cat "$scratch/failure.log"
              ${lib.concatMapStrings (entry: ''
                grep -qF -- ${lib.escapeShellArg entry} "$scratch/failure.log"
              '') case.expect}
              rm "$scratch/project/${case.file}"
            '') (lib.attrValues rejects);
          };
          checks =
            fixtureChecks
            // lib.mapAttrs' (
              name: case:
              lib.nameValuePair "formatting-rejects-${name}" (
                pkgs.testers.testBuildFailure' {
                  name = "nullkomma-formatting-rejects-${name}";
                  drv = (perSystem fixtures.md).treefmt.build.check (
                    pkgs.runCommandLocal "unformatted-${name}" { } ''
                      mkdir $out
                      printf '{ }\n' > $out/flake.nix
                      printf %s ${lib.escapeShellArg case.content} > $out/${case.file}
                    ''
                  );
                  expectedBuilderExitCode = 1;
                  expectedBuilderLogEntries = case.expect;
                }
              )
            ) rejects
            // {
              quarto-site = pkgs.runCommand "nullkomma-quarto-site" { } ''
                site=${fixtures.quarto.packages.${system}.site}
                grep -qF '<span class="va">answer</span>' "$site/index.html"
                test -f "$site/_redirects"
                touch $out
              '';
              cloudflare-config = cloudflare.checks.${system}.test-cloudflare;
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
                    # The provider uploads every file in this directory.
                    assets=$(jq -r .resource.cloudflare_workers_script.site.assets.directory ${tfConfig cloudflare})
                    [[ -f $assets/index.html && ! -e $assets/_headers && ! -e $assets/_redirects ]]
                    plan ${tfConfig cloudflare} | jq -e '
                      ."cloudflare_workers_script.site" as $worker
                      | ."cloudflare_workers_custom_domain.www_example_org" as $domain
                      | ."cloudflare_workers_script_subdomain.site" as $subdomain
                      | $worker.script_name == "fixture-site"
                        and ($worker.assets.asset_manifest_sha256 | test("^[0-9a-f]{64}$"))
                        and $worker.assets.config.not_found_handling == "404-page"
                        and ($worker.assets.config.headers | contains("nosniff"))
                        and ($worker.assets.config.redirects | contains("/old / 301"))
                        and $domain.hostname == "www.example.org"
                        and $domain.zone_id == "11111111111111111111111111111111"
                        and $domain.service == "fixture-site"
                        and $subdomain.enabled == false
                        and $subdomain.previews_enabled == false
                    '
                    plan ${tfConfig (raw bareCloudflare)} | jq -e '
                      keys == ["cloudflare_workers_script.site", "cloudflare_workers_script_subdomain.site"]
                        and (."cloudflare_workers_script.site".assets.config | .headers == null and .redirects == null)
                    '
                    touch $out
                  '';
              cloudflare-deploy =
                let
                  tofu = pkgs.writeShellScriptBin "tofu" ''
                    echo "$* $TF_VAR_account_id $AWS_ENDPOINT_URL_S3 $TF_CLI_ARGS_init $TF_CLI_ARGS_apply" >> "$LOG"
                  '';
                  flake = raw {
                    imports = [ bareCloudflare ];
                    perSystem.terranix.terranixConfigurations.deploy.terraformWrapper.package = lib.mkForce tofu;
                  };
                  deploy = lib.getExe flake.packages.${system}.deploy;
                in
                pkgs.runCommand "nullkomma-cloudflare-deploy" { } ''
                  export LOG=$PWD/log CLOUDFLARE_ACCOUNT_ID=account CLOUDFLARE_STATE_BUCKET=state
                  ${deploy}
                  cat > expected <<EOF
                  init account https://account.r2.cloudflarestorage.com -backend-config=bucket=state -auto-approve
                  apply account https://account.r2.cloudflarestorage.com -backend-config=bucket=state -auto-approve
                  EOF
                  cmp expected log
                  touch $out
                '';
              bats-rejects-failing-tests = pkgs.testers.testBuildFailure' {
                name = "nullkomma-bats-rejects-failing-tests";
                drv = batsFailing.checks.${system}.test-bats;
                expectedBuilderExitCode = 1;
                expectedBuilderLogEntries = [ "not ok 1 fails on purpose" ];
              };
              neovim-config =
                pkgs.runCommandLocal "nullkomma-neovim-config" { nativeBuildInputs = [ pkgs.neovim-unwrapped ]; }
                  ''
                    HOME=$TMPDIR nvim --clean -l ${pkgs.writeText "check.lua" ''
                      dofile("${(perSystem fixtures.md).nullkomma.files.".nvim.lua".source}")
                      assert(vim.lsp.config.nixd.cmd[1] == "nixd")
                      assert(vim.lsp.config.nixd.settings.nixd.formatting.command[1] == "treefmt")
                      assert(vim.lsp.is_enabled("nixd"))
                    ''}
                    touch $out
                  '';
              # Every language server an editor is told to start is in the dev shell.
              language-servers =
                pkgs.runCommandLocal "nullkomma-language-servers"
                  { nativeBuildInputs = (perSystem fixtures.md).nullkomma.devshell.packages; }
                  ''
                    ${lib.concatMapStrings (s: ''
                      command -v ${lib.escapeShellArg (lib.head s.command)}
                    '') (lib.attrValues (perSystem fixtures.md).nullkomma.editor.languageServers)}
                    touch $out
                  '';
              file-updates =
                pkgs.runCommandLocal "nullkomma-file-updates"
                  {
                    nativeBuildInputs = [ pkgs.git ];
                  }
                  ''
                    mkdir project
                    cd project
                    git init --quiet
                    ${lib.getExe (perSystem fileVersions.old).nullkomma.tasks.write-files.package}
                    ${lib.getExe (perSystem fileVersions.old).nullkomma.tasks.generate-files.package}
                    grep -q 'Generated by nullkomma. DO NOT EDIT' generated.txt
                    printf 'project edit' > source.txt
                    printf 'local edit' > generated.txt
                    if ${lib.getExe (perSystem fileVersions.new).nullkomma.tasks.write-files.package}; then
                      echo "Edited source-of-truth file unexpectedly overwritten" >&2
                      exit 1
                    fi
                    test "$(cat source.txt)" = 'project edit'
                    test "$(cat untouched.txt)" = new
                    test "$(cat .git/nullkomma/files/base/source.txt)" = old
                    test "$(cat .git/nullkomma/files/incoming/source.txt)" = new
                    ${lib.getExe (perSystem fileVersions.new).nullkomma.tasks.generate-files.package} < /dev/null
                    grep -q 'DO NOT EDIT' generated.txt
                    test "$(tail -n 1 generated.txt)" = new
                    ${lib.getExe (perSystem fileVersions.new).nullkomma.tasks.write-files.package} --accept source.txt
                    ${lib.getExe (perSystem fileVersions.new).nullkomma.tasks.write-files.package}
                    test "$(cat source.txt)" = 'project edit'
                    test "$(cat .git/nullkomma/files/base/source.txt)" = new
                    test ! -f .git/nullkomma/files/incoming/source.txt
                    mkdir ../unknown
                    cd ../unknown
                    git init --quiet
                    printf 'preexisting' > source.txt
                    if ${lib.getExe (perSystem fileVersions.new).nullkomma.tasks.write-files.package}; then
                      echo "Unknown source-of-truth file was not reported" >&2
                      exit 1
                    fi
                    test "$(cat source.txt)" = preexisting
                    test ! -f .git/nullkomma/files/base/source.txt
                    ln -s source.txt generated.txt
                    if ${lib.getExe (perSystem fileVersions.new).nullkomma.tasks.generate-files.package}; then
                      echo "Symlink target was not rejected" >&2
                      exit 1
                    fi
                    test "$(cat source.txt)" = preexisting
                    touch $out
                  '';
              agent-plugin-consumer =
                pkgs.runCommandLocal "nullkomma-agent-plugin-consumer" { nativeBuildInputs = [ pkgs.coreutils ]; }
                  ''
                    scratch="$(mktemp -d)"
                    consumer="$scratch/consumer"
                    plugin="$scratch/home/.copilot/installed-plugins/_direct/nullkomma"
                    mkdir -p "$consumer" "$plugin/.github"
                    cp ${../../tests/fixtures/agent-plugin/project/custom-file.txt} "$consumer/custom-file.txt"
                    cp ${../../plugin.json} "$plugin/plugin.json"
                    cp -R ${../../.github/skills} "$plugin/.github/skills"
                    cp -P ${../../skills} "$plugin/skills"
                    test -f "$plugin/plugin.json"
                    test -f "$plugin/skills/resolve-file-conflicts/SKILL.md"
                    grep -qF 'name: resolve-file-conflicts' "$plugin/skills/resolve-file-conflicts/SKILL.md"
                    cmp ${../../tests/fixtures/agent-plugin/project/custom-file.txt} "$consumer/custom-file.txt"
                    touch $out
                  '';
              file-update-task =
                let
                  nix = pkgs.writeShellScriptBin "nix" ''
                    printf '%s\n' "$*" >> "$NULLKOMMA_TEST_LOG"
                    case "$*" in
                      "flake update fail") exit 7 ;;
                      "develop --command write-files") exit 1 ;;
                    esac
                  '';
                in
                pkgs.runCommandLocal "nullkomma-file-update-task"
                  {
                    nativeBuildInputs = [ nix ];
                  }
                  ''
                    export NULLKOMMA_TEST_LOG="$PWD/calls"
                    if ${lib.getExe (perSystem fixtures.md).nullkomma.tasks.update.package} nullkomma; then
                      echo "Update did not propagate file conflicts" >&2
                      exit 1
                    fi
                    printf '%s\n' 'flake update nullkomma' 'develop --command write-files' 'develop --command generate-files' > expected
                    cmp calls expected
                    : > calls
                    if ${lib.getExe (perSystem fixtures.md).nullkomma.tasks.update.package} fail; then
                      echo "Failed lock update was not propagated" >&2
                      exit 1
                    fi
                    printf '%s\n' 'flake update fail' > expected
                    cmp calls expected
                    touch $out
                  '';
              # Renders nullkomma's options the way https://flake.parts does for listed modules:
              # without `pkgs`, `systems` or `self`, so computed defaults need a `defaultText`.
              options-doc =
                let
                  unavailable =
                    what: throw "${what} is not available when rendering option docs; add a `defaultText`.";
                  docs =
                    inputs.flake-parts.lib.evalFlakeModule
                      {
                        inputs = {
                          inherit (inputs) nixpkgs;
                          self.outPath = unavailable "`self.outPath`";
                        };
                      }
                      {
                        imports = [
                          nullkomma.flakeModules.default
                          (
                            { flake-parts-lib, ... }:
                            {
                              options.perSystem = flake-parts-lib.mkPerSystemOption {
                                _module.args.pkgs = lib.mapAttrs (name: _: unavailable "`pkgs.${name}`") pkgs // {
                                  _type = "pkgs";
                                  inherit lib;
                                  inherit (pkgs) formats;
                                };
                              };
                            }
                          )
                        ];
                        systems = [ (unavailable "`systems`") ];
                      };
                in
                (pkgs.nixosOptionsDoc {
                  inherit (docs) options;
                  transformOptions =
                    opt:
                    opt
                    // {
                      visible = opt.visible && lib.any (lib.hasPrefix (toString ../..)) opt.declarations;
                    };
                  warningsAreErrors = true;
                }).optionsCommonMark;
            };
        };
    };
}
