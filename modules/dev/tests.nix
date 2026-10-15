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
        r = callFlake ../../tests/fixtures/r;
        r-remotes = callFlake ../../tests/fixtures/r-remotes;
        r-production = callFlake ../../tests/fixtures/r-production;
        quarto-branded = callFlake ../../tests/fixtures/quarto-branded;
        shell = callFlake ../../tests/fixtures/shell;
      };
      rWithoutDescription = callFlakeWith {
        nullkomma.r.enable = true;
      } ../../tests/fixtures/md;
      rWithoutLockfile = callFlakeWith {
        nullkomma.r.lockfile = ../../tests/fixtures/r + "/missing.lock";
      } ../../tests/fixtures/r;
      rWithProfile = callFlakeWith {
        nullkomma.r.nonNix.enable = true;
      } ../../tests/fixtures/r;
      rWithWebsite = callFlakeWith {
        nullkomma.r.pkgdown.enable = true;
      } ../../tests/fixtures/r;
      rWithShiny = callFlakeWith {
        nullkomma.r.extraPackages = [ "shinytest2" ];
      } ../../tests/fixtures/r;
      rWithQuality = callFlakeWith {
        nullkomma.r.lintr.enable = true;
        nullkomma.r.coverage.enable = true;
      } ../../tests/fixtures/r;
      cloudflare = callFlakeWith {
        nullkomma.cloudflare = {
          enable = true;
          worker = "fixture-site";
          domains."www.example.org" = "11111111111111111111111111111111";
        };
      } ../../tests/fixtures/quarto;
      brandedCloudflare = callFlakeWith {
        nullkomma.cloudflare.enable = true;
        nullkomma.cloudflare.worker = "fixture-site";
        nullkomma.privacy.languages = [
          {
            code = "en";
            label = "English";
          }
        ];
      } ../../tests/fixtures/quarto-branded;
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
            packages.site = pkgs.writeTextDir "content.txt" "Independent static assets\n";
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
            testCloudflareProvidesWranglerOnlyWhenEnabled = {
              expr = map (flake: lib.elem pkgs.wrangler (perSystem flake).nullkomma.devshell.packages) [
                cloudflare
                fixtures.quarto
              ];
              expected = [
                true
                false
              ];
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
            testQuartoGeneratesExtensionsAndPrivacyPage =
              let
                inherit ((perSystem fixtures.quarto-branded).nullkomma) files;
                privacy = files."privacy.qmd";
              in
              {
                expr = {
                  extension = {
                    inherit (files."_extensions/greeting") mode directory;
                    source = builtins.pathExists (files."_extensions/greeting".source + "/greeting.lua");
                  };
                  privacy = {
                    inherit (privacy) mode commentPrefix commentSuffix;
                    startsWithFrontMatter = lib.hasPrefix "\n---\ntitle: \"Privacy Policy\"\n---\n" privacy.text;
                  };
                  ignored = lib.filter (
                    line:
                    lib.elem line [
                      "/_extensions/greeting"
                      "/privacy.qmd"
                    ]
                  ) (lib.splitString "\n" files.".gitignore".text);
                  plainQuarto = (perSystem fixtures.quarto).nullkomma.files ? "privacy.qmd";
                };
                expected = {
                  extension = {
                    mode = "generated";
                    directory = true;
                    source = true;
                  };
                  privacy = {
                    mode = "generated";
                    commentPrefix = "<!--";
                    commentSuffix = " -->";
                    startsWithFrontMatter = true;
                  };
                  ignored = [
                    "/_extensions/greeting"
                    "/privacy.qmd"
                  ];
                  plainQuarto = false;
                };
              };
            testRIntegrations = {
              expr = {
                air = (perSystem fixtures.r).treefmt.programs.air.enable;
                tests = lib.attrNames (perSystem fixtures.r).nullkomma.tests;
                languageServer = (perSystem fixtures.r).nullkomma.editor.languageServers.r.command;
                formatting =
                  (perSystem fixtures.r)
                  .nullkomma.editor.languageServers.r.settings.r.lsp.server_capabilities.documentFormattingProvider;
                profile = (perSystem fixtures.r).nullkomma.files ? ".Rprofile";
                optedInProfile = (perSystem rWithProfile).nullkomma.files.".Rprofile".mode;
                checkDisabled =
                  lib.attrNames
                    (perSystem (
                      callFlakeWith {
                        nullkomma.r.check.enable = false;
                      } ../../tests/fixtures/r
                    )).nullkomma.tests;
                snapshot = fixtures.r.debug.config.nullkomma.r.snapshot;
                ppm = fixtures.r.debug.config.nullkomma.r.ppmUrl;
                fields = fixtures.r.debug.config.nullkomma.r.fields;
                runtimeFields =
                  (callFlakeWith {
                    nullkomma.r.fields = [
                      "Depends"
                      "Imports"
                      "LinkingTo"
                    ];
                  } ../../tests/fixtures/r).debug.config.nullkomma.r.fields;
              };
              expected = {
                air = true;
                tests = [
                  "r-cmd-check"
                  "r-lock"
                  "r-namespace"
                  "r-testthat"
                  "r-testthat-installed"
                ];
                languageServer = [
                  "R"
                  "--slave"
                  "-e"
                  "languageserver::run()"
                ];
                formatting = false;
                profile = false;
                optedInProfile = "source";
                checkDisabled = [
                  "r-lock"
                  "r-namespace"
                  "r-testthat"
                  "r-testthat-installed"
                ];
                snapshot =
                  let
                    d = inputs.nixpkgs-r.sourceInfo.lastModifiedDate;
                  in
                  "${builtins.substring 0 4 d}-${builtins.substring 4 2 d}-${builtins.substring 6 2 d}";
                ppm = "https://packagemanager.posit.co/cran/${tests.testRIntegrations.expected.snapshot}";
                fields = nullkomma.lib.r.defaultFields ++ [
                  "Config/Needs/development"
                  "Config/Needs/website"
                ];
                runtimeFields = [
                  "Depends"
                  "Imports"
                  "LinkingTo"
                ];
              };
            };
            testRLockReader = {
              expr =
                let
                  inherit (nullkomma.lib.r) readLock defaultFields;
                  deps = {
                    type = "deps";
                    dep_types = defaultFields;
                  };
                  github = {
                    type = "github";
                    package = "withr";
                    ref = "r-lib/withr@abc";
                    version = "1.0";
                    dependencies = [ ];
                    metadata = {
                      RemoteUsername = "r-lib";
                      RemoteRepo = "withr";
                      RemoteSha = "abc";
                    };
                  };
                  standard = {
                    type = "standard";
                    package = "data.table";
                    ref = "data.table";
                    version = "1.0";
                    dependencies = [ ];
                    metadata = { };
                    sources = [ "https://example.org/data.table.tar.gz" ];
                  };
                  read =
                    args: packages:
                    readLock (
                      {
                        lock = {
                          lockfile_version = 1;
                          packages = [ deps ] ++ packages;
                        };
                        available.data_table = { };
                      }
                      // args
                    );
                  fails = args: packages: !(builtins.tryEval (builtins.deepSeq (read args packages) null)).success;
                in
                {
                  standard = (read { } [ standard ]).nixpkgs;
                  commit = (read { allowOffNixpkgs = true; } [ github ]).sources.withr.fetchTree.rev;
                  rejects = [
                    (fails { } [ github ])
                    (fails { } [ (standard // { ref = "data.table@1.0"; }) ])
                    (fails { available = { }; } [ standard ])
                    (fails {
                      allowOffNixpkgs = true;
                      available = { };
                    } [ standard ])
                    (fails { allowOffNixpkgs = true; } [ (github // { type = "local"; }) ])
                    (fails { fields = [ "Imports" ]; } [ ])
                    (fails {
                      lock = {
                        lockfile_version = 2;
                        packages = [ deps ];
                      };
                    } [ ])
                  ];
                };
              expected = {
                standard = [ "data.table" ];
                commit = "abc";
                rejects = lib.replicate 7 true;
              };
            };
            testRNonNixDocumentation = {
              expr =
                let
                  inherit (nullkomma.lib.r) withNonNixDocumentation;
                  original = builtins.readFile ../../tests/fixtures/r/README.md;
                  updated = withNonNixDocumentation original;
                in
                {
                  preservesNotes = lib.hasInfix "Keep these project-specific development notes." updated;
                  idempotent = withNonNixDocumentation updated == updated;
                  headingCount = lib.length (lib.splitString "\n## Development\n" updated) - 1;
                  noReadme = lib.hasInfix "## Development" (withNonNixDocumentation "");
                  rejectsIncomplete =
                    (builtins.tryEval (withNonNixDocumentation "<!-- nullkomma:r-development:start -->")).success;
                  environmentDefault = (perSystem rWithProfile).nullkomma.files.".Renviron".mode;
                  sharedDocumentation = lib.hasInfix (lib.replaceStrings
                    [ "### R development without Nix" "\n#### " ]
                    [ "#### R development without Nix" "\n##### " ]
                    nullkomma.lib.r.nonNixDocumentation
                  ) (builtins.readFile ../../README.md);
                  disabledFiles = lib.any (f: (perSystem fixtures.r).nullkomma.files ? ${f}) [
                    ".Rprofile"
                    ".Renviron"
                    ".Rbuildignore"
                    "README.md"
                  ];
                  runtimeFields =
                    lib.hasInfix "NULLKOMMA_R_ALL_CONFIG_NEEDS=false"
                      (perSystem (
                        callFlakeWith {
                          nullkomma.r.nonNix.enable = true;
                          nullkomma.r.fields = [
                            "Depends"
                            "Imports"
                            "LinkingTo"
                          ];
                        } ../../tests/fixtures/r
                      )).nullkomma.files.".Renviron".text;
                };
              expected = {
                preservesNotes = true;
                idempotent = true;
                headingCount = 1;
                noReadme = true;
                rejectsIncomplete = false;
                environmentDefault = "source";
                sharedDocumentation = true;
                disabledFiles = false;
                runtimeFields = true;
              };
            };
            testRPackagesFromLockfile = {
              expr =
                let
                  r = (perSystem fixtures.r).nullkomma.r;
                  remotes = (perSystem fixtures.r-remotes).nullkomma.r;
                in
                {
                  tools = map (p: lib.elem p r.packages) [
                    "pak"
                    "languageserver"
                    "testthat"
                    "assertthat"
                    "rematch"
                  ];
                  sources = r.lock.sources;
                  remotes = lib.mapAttrs (_: s: s.fetchTree.type or "url") remotes.lock.sources;
                  withr = remotes.lock.sources.withr.fetchTree.rev;
                  missingLock =
                    (builtins.tryEval (builtins.deepSeq (perSystem rWithoutLockfile).nullkomma.r.packages null))
                    .success;
                  bootstrap = rWithoutLockfile.packages.${system}.r-lock.type;
                  skipLock = (perSystem fixtures.r).nullkomma.tasks.r-lock.skip;
                  withoutDescription = (perSystem rWithoutDescription).nullkomma.r.lock;
                };
              expected = {
                tools = [
                  true
                  true
                  true
                  true
                  true
                ];
                sources = { };
                remotes = {
                  digest = "url";
                  withr = "github";
                };
                withr = "d82e4bc2d69a34f044ad205210e26207bfb8f3e0";
                missingLock = false;
                bootstrap = "derivation";
                skipLock = true;
                withoutDescription = {
                  nixpkgs = [ ];
                  sources = { };
                  refs = [ ];
                };
              };
            };
            testRWorkflowSelection = {
              expr = {
                tasks = lib.filter (lib.hasPrefix "r-") (lib.attrNames (perSystem fixtures.r).nullkomma.tasks);
                withoutPackage = (perSystem rWithoutDescription).nullkomma.r.packages;
                heavyweightDefaults = lib.filter (name: lib.elem name (perSystem fixtures.r).nullkomma.r.packages) [
                  "pkgdown"
                  "lintr"
                  "covr"
                  "shinytest2"
                ];
                browserByDefault = (perSystem fixtures.r).nullkomma.r.browser != null;
                website = rWithWebsite.packages.${system} ? site;
                ignored = lib.elem "/man/*.Rd" fixtures.r.debug.config.nullkomma.gitignore;
                keepsFigures = !(lib.elem "/man/" fixtures.r.debug.config.nullkomma.gitignore);
              };
              expected = {
                tasks = [
                  "r-check"
                  "r-document"
                  "r-lock"
                  "r-test"
                  "r-test-installed"
                ];
                withoutPackage = [
                  "languageserver"
                  "pak"
                ];
                heavyweightDefaults = [ ];
                browserByDefault = false;
                website = true;
                ignored = true;
                keepsFigures = true;
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
              expr = map builtins.readFile [
                ../../templates/default/flake.nix
                ../../templates/r/flake.nix
              ];
              expected = map builtins.readFile [
                ../../tests/fixtures/md/flake.nix
                ../../tests/fixtures/r/flake.nix
              ];
            };
            testTemplatesIncludeDirenvBootstrap = {
              expr = lib.mapAttrs (_: t: builtins.readFile (t.path + "/.envrc")) nullkomma.templates;
              expected = lib.mapAttrs (_: t: (perSystem t).nullkomma.files.".envrc".text) templates;
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
          rLockFailure =
            text: message:
            pkgs.testers.testBuildFailure' {
              name = "nullkomma-r-lock-rejects";
              drv =
                (callFlakeWith {
                  nullkomma.r.description = builtins.toFile "DESCRIPTION" text;
                  nullkomma.r.fields = fixtures.r.debug.config.nullkomma.r.fields;
                } ../../tests/fixtures/r).checks.${system}.test-r-lock;
              expectedBuilderExitCode = 1;
              expectedBuilderLogEntries = [ message ];
            };
          nonNixProject =
            pkgs.runCommand "nullkomma-r-non-nix-project" { nativeBuildInputs = [ pkgs.git ]; }
              ''
                cp -R ${../../tests/fixtures/r} project
                chmod -R u+w project
                cd project
                git init -q
                cp README.md original
                echo "Unseen working-tree edit" >> README.md
                if ${lib.getExe (perSystem rWithProfile).nullkomma.tasks.write-files.package} > conflict.log 2>&1; then
                  echo "README initialization overwrote an unseen edit" >&2
                  exit 1
                fi
                grep -qF 'Unseen working-tree edit' README.md
                grep -qF 'Upstream conflict: README.md' conflict.log
                mv original README.md
                ${lib.getExe (perSystem rWithProfile).nullkomma.tasks.write-files.package}
                grep -qF 'Keep these project-specific development notes.' README.md
                grep -qxF '^project-only[.]txt$' .Rbuildignore
                test "$(grep -xcF '^[.]envrc$' .Rbuildignore)" = 1
                cp README.md expected
                cp .Rbuildignore expected-buildignore
                ${lib.getExe (perSystem rWithProfile).nullkomma.tasks.write-files.package}
                cmp expected README.md
                cmp expected-buildignore .Rbuildignore
                mkdir $out
                cp -R DESCRIPTION pkg.lock R NAMESPACE man tests .Rprofile .Renviron .Rbuildignore README.md flake.nix $out/
              '';
        in
        {
          # Sandboxed: nix-unit re-evaluates this flake with its inputs passed in.
          nullkomma.nix.unit.tests = tests;
          # Dev partition inputs use flake-compat's fetchTree, not root input overrides.
          nullkomma.nix.unit.allowNetwork = true;
          # Terranix's non-followed inputs also need paths in nix-unit's fresh store.
          nullkomma.nix.unit.inputs =
            lib.mapAttrs (_: input: input.outPath) (
              removeAttrs inputs [
                "self"
                "brand"
              ]
            )
            // {
              "terranix/import-tree" = inputs.terranix.inputs.import-tree.outPath;
              "terranix/systems" = inputs.terranix.inputs.systems.outPath;
            };
          nullkomma.tasks.test-r-non-nix = {
            description = "Test Ubuntu 24.04 R workflows without Nix (requires a running Docker daemon and network)";
            skip = true;
            packages = [
              pkgs.coreutils
              pkgs.git
              pkgs.docker-client
            ];
            command = ''
              docker info > /dev/null
              scratch="$(mktemp -d)"
              trap 'rm -rf "$scratch"' EXIT
              cp -R ${nonNixProject} "$scratch/project"
              chmod -R u+w "$scratch/project"
              cp ${../../tests/r-non-nix/Dockerfile} "$scratch/Dockerfile"
              cp ${../../tests/r-non-nix/run.sh} "$scratch/run.sh"
              image=nullkomma-r-non-nix:${builtins.substring 11 12 (toString nonNixProject)}
              docker build --platform linux/amd64 --progress=plain \
                --build-arg R_VERSION=${inputs.nixpkgs-r.legacyPackages.${system}.R.version} \
                --tag "$image" "$scratch"
              docker run --rm --platform linux/amd64 "$image" bash /test.sh
            '';
          };
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
              cp -R "$root/tests/fixtures/r" "$scratch/r"
              rm "$scratch/r/pkg.lock"
              # Bootstrapping must not evaluate the lock-dependent R environment.
              nix build "path:$scratch/r#r-lock" \
                --override-input nullkomma "path:$root" \
                --no-write-lock-file --no-link --print-build-logs
              if nix eval "path:$scratch/r#devShells.${system}.default.drvPath" \
                --override-input nullkomma "path:$root" \
                --no-write-lock-file > "$scratch/missing-lock.log" 2>&1; then
                echo "R environment without pkg.lock unexpectedly evaluated" >&2
                exit 1
              fi
              grep -qF "lockfile \`pkg.lock\` of DESCRIPTION is missing" "$scratch/missing-lock.log"
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
            // {
              r-pkgdown = pkgs.runCommand "r-pkgdown-output" { } ''
                site=${rWithWebsite.packages.${system}.site}
                test -s "$site/index.html"
                test -s "$site/reference/hello.html"
                epoch="$(date -u -d "@$SOURCE_DATE_EPOCH" +%Y-%m-%dT%H:%MZ)"
                grep -qF "last_built: $epoch" "$site/pkgdown.yml"
                touch "$out"
              '';
              r-lintr = rWithQuality.checks.${system}.test-r-lintr;
              r-coverage = pkgs.runCommand "r-coverage-output" { } ''
                cp -R ${../../tests/fixtures/r} project
                chmod -R u+w project
                cd project
                export HOME="$TMPDIR/home"
                mkdir -p "$HOME"
                ${lib.getExe (perSystem rWithQuality).nullkomma.tasks.r-coverage.package}
                grep -q '<coverage ' coverage.xml
                grep -q 'hello.R' coverage.xml
                touch "$out"
              '';
              r-installed-is-not-development = pkgs.runCommand "r-installed-is-not-development" { } ''
                cp -R ${../../tests/fixtures/r} project
                chmod -R u+w project
                cd project
                export HOME="$TMPDIR/home"
                mkdir -p "$HOME"
                cat > tests/testthat/test-installed.R <<'RS'
                test_that("the installed namespace is tested", {
                  expect_false(pkgload::is_dev_package("nullkommafixture"))
                  expect_true(startsWith(find.package("nullkommafixture"), Sys.getenv("R_LIBS_USER")))
                })
                RS
                ${lib.getExe (perSystem fixtures.r).nullkomma.tasks.r-test-installed.package}
                touch "$out"
              '';
              r-namespace-rejects-drift = pkgs.runCommand "r-namespace-rejects-drift" { } ''
                cp -R ${../../tests/fixtures/r} project
                chmod -R u+w project
                cd project
                export HOME="$TMPDIR/home"
                mkdir -p "$HOME"
                printf '# Generated by roxygen2: do not edit by hand\n' > NAMESPACE
                if ${lib.getExe (perSystem fixtures.r).nullkomma.tests.r-namespace.package} > failure.log 2>&1; then
                  echo "Stale NAMESPACE unexpectedly passed" >&2
                  exit 1
                fi
                grep -qF 'NAMESPACE is stale' failure.log
                touch "$out"
              '';
            }
            // lib.optionalAttrs pkgs.stdenv.isLinux {
              r-shinytest2 =
                let
                  r = (perSystem rWithShiny).nullkomma.r;
                in
                pkgs.runCommand "r-shinytest2" { nativeBuildInputs = [ r.package ]; } ''
                  export HOME="$TMPDIR/home"
                  mkdir -p "$HOME"
                  ${r.setup}
                  export SHINY_FIXTURE=${../../tests/r-shiny}
                  Rscript --vanilla - <<'RS'
                  results <- testthat::test_file("${../../tests/r-shiny/test-browser.R}", stop_on_failure = TRUE, stop_on_warning = TRUE)
                  results <- as.data.frame(results)
                  stopifnot(sum(results$passed) >= 3L, !any(results$skipped))
                  RS
                  touch "$out"
                '';
            }
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
              r-non-nix-files = nonNixProject;
              r-non-nix-profile =
                pkgs.runCommand "nullkomma-r-non-nix-profile" { nativeBuildInputs = [ pkgs.R ]; }
                  ''
                    cp -R ${nonNixProject} project
                    chmod -R u+w project
                    cd project
                    export HOME="$TMPDIR/home"
                    mkdir -p "$HOME"
                    unset IN_NIX_SHELL R_LIBS_USER
                    Rscript -e '
                      stopifnot(startsWith(.libPaths()[1], file.path(getwd(), ".R", "library")))
                      stopifnot(getOption("repos")[["CRAN"]] == Sys.getenv("NULLKOMMA_PPM_URL"))
                      stopifnot(all(c("Config/Needs/development", "Config/Needs/website") %in% getOption("nullkomma.r.dependencies")))
                    '
                    IN_NIX_SHELL=impure Rscript -e '
                      stopifnot(!startsWith(.libPaths()[1], file.path(getwd(), ".R", "library")))
                    '
                    touch .R/library/sentinel project-only.txt
                    R CMD build --no-build-vignettes --no-manual .
                    tar -tf nullkommafixture_0.0.1.tar.gz > package-files
                    if grep -E '/(flake[.]nix|pkg[.]lock|[.]R|[.]Renviron|[.]Rprofile|project-only[.]txt)(/|$)' package-files; then
                      echo "Development files leaked into the R source package" >&2
                      exit 1
                    fi
                    grep -qx 'nullkommafixture/R/hello.R' package-files
                    rm .Renviron
                    if Rscript -e 'quit(status = 0)' > failure.log 2>&1; then
                      echo "Missing project settings unexpectedly accepted" >&2
                      exit 1
                    fi
                    grep -qF 'Missing project R settings' failure.log
                    touch $out
                  '';
              r-production =
                let
                  package = fixtures.r-production.packages.${system}.default;
                in
                pkgs.runCommand "nullkomma-r-production"
                  {
                    exportReferencesGraph = [
                      "closure"
                      package
                    ];
                    nativeBuildInputs = [ pkgs.R ];
                  }
                  ''
                    Rscript --vanilla -e 'library(nullkommafixture, lib.loc = "${package}/library"); stopifnot(hello() == "Hello, world!")'
                    if grep -E '/r-(testthat|pak|languageserver|assertthat|rematch|rcmdcheck|roxygen2|pkgdown|lintr|covr|shinytest2)-[0-9]' closure; then
                      echo "Production package includes development dependencies" >&2
                      exit 1
                    fi
                    touch $out
                  '';
              flakehub-visibility = pkgs.runCommand "nullkomma-flakehub-visibility" { } ''
                ${pkgs.nodejs}/bin/node <<'JS'
                const assert = require("node:assert/strict");
                const fs = require("node:fs");
                const workflow = fs.readFileSync("${../../.github/workflows/ci.yml}", "utf8");
                assert.match(workflow, /        default: auto\n/);
                const expression = workflow.match(/          visibility: \$\{\{ (.+) \}\}/)[1];
                const visibility = new Function("inputs", "github", "return (" + expression + ");");
                for (const isPrivate of [false, true]) {
                  for (const input of ["auto", "public", "unlisted", "private", ""]) {
                    const actual = visibility(
                      {visibility: input},
                      {event: {repository: {private: isPrivate}}},
                    );
                    const expected = input === "auto" ? (isPrivate ? "private" : "public") : input;
                    assert.equal(actual, expected);
                  }
                }
                JS
                touch $out
              '';
              r-lock-rejects-stale = rLockFailure ''
                Package: nullkommafixture
                Imports: digest
                Remotes: r-lib/withr@main
              '' "DESCRIPTION depends on digest, which the lockfile lacks.";
              r-lock-rejects-constraint = rLockFailure ''
                Package: nullkommafixture
                Suggests: testthat (>= 99.0)
              '' "DESCRIPTION requires testthat (>= 99.0)";
              r-lock-rejects-remotes = rLockFailure ''
                Package: nullkommafixture
                Remotes: r-lib/withr@main
              '' "DESCRIPTION has `Remotes: r-lib/withr@main`, which the lockfile lacks.";
              r-tests-use-working-tree = pkgs.runCommand "nullkomma-r-working-tree" { } ''
                cp -r ${../../tests/fixtures/r} project
                chmod -R u+w project
                cd project
                printf '\nImports: digest\n' > DESCRIPTION
                if ${lib.getExe (perSystem fixtures.r).nullkomma.tests.r-lock.package} > failure.log 2>&1; then
                  echo "R lock test ignored the edited DESCRIPTION" >&2
                  exit 1
                fi
                grep -qF "DESCRIPTION depends on digest, which the lockfile lacks." failure.log || {
                  cat failure.log >&2
                  exit 1
                }
                cp ${../../tests/fixtures/r/DESCRIPTION} DESCRIPTION
                echo 'stop("local-r-source-marker")' >> R/hello.R
                if ${lib.getExe (perSystem fixtures.r).nullkomma.tests.r-cmd-check.package} > failure.log 2>&1; then
                  echo "R CMD check ignored the edited package source" >&2
                  exit 1
                fi
                grep -qF local-r-source-marker failure.log || {
                  cat failure.log >&2
                  exit 1
                }
                touch $out
              '';
              quarto-site = pkgs.runCommand "nullkomma-quarto-site" { } ''
                site=${fixtures.quarto.packages.${system}.site}
                ${pkgs.python3}/bin/python - "$site/index.html" <<'PY'
                from html.parser import HTMLParser
                from pathlib import Path
                import sys

                class Document(HTMLParser):
                    def handle_data(self, data):
                        self.text.append(data)

                document = Document()
                document.text = []
                document.feed(Path(sys.argv[1]).read_text())
                text = "".join(document.text)
                assert "Fixture home" in text
                assert "{ answer = 42; }" in text
                PY
                cmp ${../../tests/fixtures/quarto/_headers} "$site/_headers"
                cmp ${../../tests/fixtures/quarto/_redirects} "$site/_redirects"
                test ! -e "$site/privacy.html"
                touch $out
              '';
              quarto-branded-site =
                pkgs.runCommand "nullkomma-quarto-branded-site" { nativeBuildInputs = [ pkgs.python3 ]; }
                  ''
                    python - ${fixtures.quarto-branded.packages.${system}.site} ${
                      brandedCloudflare.packages.${system}.site
                    } <<'PY'
                    from html.parser import HTMLParser
                    from pathlib import Path
                    import sys

                    class Document(HTMLParser):
                        def handle_data(self, data):
                            self.text.append(data)

                    def text(path):
                        document = Document()
                        document.text = []
                        document.feed(Path(path).read_text())
                        return " ".join("".join(document.text).split())

                    branded, english = sys.argv[1:]
                    assert "Hello from an extension" in text(f"{branded}/index.html")
                    privacy = text(f"{branded}/privacy.html")
                    assert "Privacy Policy" in privacy
                    assert "Generated by nullkomma" not in privacy
                    assert "nav-tabs" in Path(f"{branded}/privacy.html").read_text()
                    assert privacy.index("English") < privacy.index("Deutsch") < privacy.index("Local section in English") < privacy.index("Lokaler Abschnitt auf Deutsch")
                    assert "Cloudflare" not in privacy
                    privacy = text(f"{english}/privacy.html")
                    assert "Deutsch" not in privacy
                    assert privacy.index("Hosting, delivery, security and web analytics by Cloudflare") < privacy.index("Local section in English")
                    PY
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
                    site=${cloudflare.packages.${system}.site}
                    assets=$(jq -r .resource.cloudflare_workers_script.site.assets.directory ${tfConfig cloudflare})
                    cp -r "$site" expected-assets
                    chmod -R u+w expected-assets
                    rm expected-assets/_headers expected-assets/_redirects
                    diff -r expected-assets "$assets"
                    jq -e '.terraform.backend.s3.key == "fixture-site.tfstate"' ${tfConfig cloudflare}
                    jq -e '.terraform.backend.s3.key == "bare-site.tfstate"' ${tfConfig (raw bareCloudflare)}
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
                    plan ${tfConfig (raw bareCloudflare)} | jq -e '
                      keys == ["cloudflare_workers_script.site", "cloudflare_workers_script_subdomain.site"]
                        and (."cloudflare_workers_script.site".assets.config | .headers == null and .redirects == null)
                    '
                    bareAssets=$(jq -r .resource.cloudflare_workers_script.site.assets.directory ${tfConfig (raw bareCloudflare)})
                    diff -r ${(raw bareCloudflare).packages.${system}.site} "$bareAssets"
                    touch $out
                  '';
              quarto-preview =
                let
                  quarto = pkgs.writeShellScriptBin "quarto" ''
                    printf '%s\n' "$PWD" "$@" > "$CALLED"
                  '';
                  flake = callFlakeWith (
                    { self, ... }:
                    {
                      nullkomma.quarto.root = self.outPath + "/docs";
                      perSystem.nullkomma.quarto.package = quarto;
                    }
                  ) ../../tests/fixtures/quarto;
                  preview = lib.getExe (perSystem flake).nullkomma.tasks.preview.package;
                in
                pkgs.runCommand "nullkomma-quarto-preview" { nativeBuildInputs = [ pkgs.git ]; } ''
                  export CALLED=$PWD/called
                  mkdir -p repo/docs/sub && cd repo/docs/sub && git init -q ../..
                  ${preview} --no-browser
                  printf '%s\n' "$(cd ../.. && pwd)/docs" preview --no-browser > expected
                  cmp expected "$CALLED"
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
                  flake = raw {
                    imports = [ bareCloudflare ];
                    perSystem.terranix.terranixConfigurations.deploy.terraformWrapper.package = lib.mkForce tofu;
                  };
                  deploy = lib.getExe flake.packages.${system}.deploy;
                  tasks = (perSystem flake).nullkomma.tasks;
                in
                pkgs.runCommand "nullkomma-cloudflare-deploy" { } ''
                  export CALLED=$PWD/called CLOUDFLARE_STATE_BUCKET=state
                  for invalid in "" cfat_offline-test-token short 0000000000000000000000000000000g; do
                    if CLOUDFLARE_ACCOUNT_ID="$invalid" ${deploy} > failure.log 2>&1; then
                      echo "Deploy accepted an invalid account ID" >&2
                      exit 1
                    fi
                    test ! -f "$CALLED"
                    printf '%s\n' "CLOUDFLARE_ACCOUNT_ID must be the 32-character account ID, not an API token" > expected
                    cmp expected failure.log
                  done
                  export CLOUDFLARE_ACCOUNT_ID=0123456789abcdef0123456789abcdef
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
                    mkdir ../branded
                    cd ../branded
                    git init --quiet
                    generate=${lib.getExe (perSystem fixtures.quarto-branded).nullkomma.tasks.generate-files.package}
                    mkdir -p _extensions/greeting
                    touch _extensions/greeting/stale.lua
                    $generate
                    test -f _extensions/greeting/greeting.lua
                    test ! -e _extensions/greeting/stale.lua
                    test -w _extensions/greeting/greeting.lua
                    head -n 1 privacy.qmd | grep -q '^<!-- Generated by nullkomma.* -->$'
                    $generate
                    printf 'own policy' > privacy.qmd
                    git add privacy.qmd
                    if $generate; then
                      echo "Tracked file was overwritten by a generated one" >&2
                      exit 1
                    fi
                    test "$(cat privacy.qmd)" = 'own policy'
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
