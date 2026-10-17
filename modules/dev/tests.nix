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
        nullkomma.r-non-nix.enable = true;
      } ../../tests/fixtures/r;
      rWithWebsite = callFlakeWith {
        nullkomma.r.pkgdown.enable = true;
      } ../../tests/fixtures/r;
      rBranded = {
        nullkomma.r.pkgdown = {
          enable = true;
          assets = ../../tests/fixtures/r-brand/assets;
          override = {
            footer.components.brand = ''<span id="sandbox-brand">Sandbox brand footer · 🌲</span>'';
          };
          brand = {
            lib = {
              brand = ../../tests/fixtures/r-brand/_brand.yml;
              footer = builtins.toFile "fixture-footer.html" ''
                <footer id="shared-brand">Shared brand footer · 🌲 <a href="privacy.html">Privacy</a></footer>
              '';
            };
            flakeModules.privacy = {
              nullkomma.privacy.sections.brand = {
                order = 100;
                markdown = {
                  en = ../../tests/fixtures/quarto-branded/_privacy/local.en.md;
                  de = ../../tests/fixtures/quarto-branded/_privacy/local.de.md;
                };
              };
            };
          };
        };
      };
      rWithBrand = callFlakeWith rBranded ../../tests/fixtures/r;
      rWithPublishedBrand = callFlakeWith {
        nullkomma.r.pkgdown = {
          enable = true;
          brand = inputs.brand;
        };
        nullkomma.cloudflare = {
          enable = true;
          worker = "r-branded-fixture";
        };
      } ../../tests/fixtures/r;
      rPrivacy = {
        nullkomma.r.pkgdown.enable = true;
        nullkomma.cloudflare = {
          enable = true;
          worker = "r-fixture-site";
        };
        nullkomma.privacy.sections = {
          local = {
            order = 100;
            markdown = {
              en = ../../tests/fixtures/quarto-branded/_privacy/local.en.md;
              de = ../../tests/fixtures/quarto-branded/_privacy/local.de.md;
            };
          };
          disabled = {
            enable = false;
            markdown.en = ../../tests/fixtures/md/README.md;
          };
        };
      };
      rWithPrivacy = callFlakeWith rPrivacy ../../tests/fixtures/r;
      rWithoutPrivacy = callFlakeWith {
        imports = [ rPrivacy ];
        nullkomma.r.pkgdown.privacy.page = null;
      } ../../tests/fixtures/r;
      rEnglishPrivacy = callFlakeWith {
        imports = [ rPrivacy ];
        nullkomma.r.pkgdown.privacy.page = "legal.md";
        nullkomma.privacy.languages = [
          {
            code = "en";
            label = "English";
          }
        ];
      } ../../tests/fixtures/r;
      rWithShiny = callFlakeWith {
        nullkomma.r.extraPackages = [ "shinytest2" ];
      } ../../tests/fixtures/r;
      rWithQuality = callFlakeWith {
        nullkomma.r.lintr.enable = true;
        nullkomma.r.coverage.enable = true;
      } ../../tests/fixtures/r;
      rWithTreefmtLint = callFlakeWith {
        nullkomma.r = {
          lintr.enable = true;
          lintr.linters.line_length_linter = "lintr::line_length_linter(100L)";
          pkgdown.enable = true;
        };
        nullkomma.generatedPaths = [ "generated/**" ];
        nullkomma.lint.yaml = {
          ignore = [ "shared-ignore.yaml" ];
          rules.truthy.allowed-values = [
            "true"
            "false"
            "yes"
          ];
        };
        perSystem.nullkomma.files."managed" = {
          mode = "generated";
          directory = true;
          source = ../../tests/fixtures/r-brand/assets;
        };
      } ../../tests/fixtures/r;
      rNestedTreefmt = rawAt ../../tests/fixtures {
        imports = [ nullkomma.flakeModules.default ];
        nullkomma.r = {
          enable = true;
          root = ../../tests/fixtures/r;
          lintr.enable = true;
        };
      };
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
        callFlakeWith
          {
            imports = [ { nullkomma.cloudflare.worker = "fixture-site"; } ];
            nullkomma.${name}.enable = !fixtures.md.debug.config.nullkomma.${name}.enable;
          }
          (
            if
              lib.elem name [
                "r"
                "r-non-nix"
              ]
            then
              ../../tests/fixtures/r
            else
              ../../tests/fixtures/md
          )
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
      raw = rawAt ../../tests/fixtures/md;
      rawAt =
        src: module:
        inputs.flake-parts.lib.mkFlake
          {
            inputs.self.outPath = src;
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
          rPrivacyAssetCollision = callFlakeWith {
            imports = [ rPrivacy ];
            nullkomma.r.pkgdown.assets = pkgs.writeTextDir "privacy.html" "Project-owned asset";
          } ../../tests/fixtures/r;
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
            testRAttributeNames = {
              expr = map nullkomma.lib.r.attrName [
                "data.table"
                "import"
                "assert"
                "R6"
              ];
              expected = [
                "data_table"
                "r_import"
                "r_assert"
                "R6"
              ];
            };
            testRBuildignore = {
              expr =
                let
                  core = (perSystem fixtures.r).nullkomma.files.".Rbuildignore";
                  nested = callFlakeWith {
                    nullkomma.r.root = ../../tests/fixtures/r/R;
                    nullkomma.r.lockfile = ../../tests/fixtures/r/R + "/deps/selected.lock";
                  } ../../tests/fixtures/r;
                in
                {
                  source = core.mode;
                  baseline = core.initialSource == ../../tests/fixtures/r/.Rbuildignore;
                  externalFiles = lib.filter (lib.hasSuffix ".Rbuildignore") (
                    lib.attrNames (perSystem fixtures.r-production).nullkomma.files
                  );
                  preservesRules = lib.hasPrefix (builtins.readFile ../../tests/fixtures/r/.Rbuildignore) core.text;
                  uniqueRule = lib.length (lib.filter (line: line == "^[.]envrc$") (lib.splitString "\n" core.text));
                  nestedLock =
                    lib.hasInfix "^deps/selected\\.lock$"
                      (perSystem nested).nullkomma.files."R/.Rbuildignore".text;
                };
              expected = {
                source = "source";
                baseline = true;
                externalFiles = [ ];
                preservesRules = true;
                uniqueRule = 1;
                nestedLock = true;
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
                  inherit (nullkomma.lib.r-non-nix) withNonNixDocumentation;
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
                    nullkomma.lib.r-non-nix.nonNixDocumentation
                  ) (builtins.readFile ../../README.md);
                  disabledFiles = lib.any (f: (perSystem fixtures.r).nullkomma.files ? ${f}) [
                    ".Rprofile"
                    ".Renviron"
                    ".R/install.R"
                    "README.md"
                  ];
                  runtimeFields =
                    lib.hasInfix "NULLKOMMA_R_ALL_CONFIG_NEEDS=false"
                      (perSystem (
                        callFlakeWith {
                          nullkomma.r-non-nix.enable = true;
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
            testRNonNixPlugin = {
              expr =
                let
                  standalone = rawAt ../../tests/fixtures/r {
                    imports = [ plugins.r-non-nix ];
                    nullkomma.r-non-nix.enable = true;
                  };
                  core = rawAt ../../tests/fixtures/r {
                    imports = [ plugins.r ];
                    nullkomma.r.enable = true;
                  };
                  overlapping = rawAt ../../tests/fixtures/r {
                    imports = [
                      plugins.r
                      plugins.r-non-nix
                      nullkomma.modules.flake.r-non-nix
                    ];
                    nullkomma.r-non-nix.enable = true;
                  };
                  files = flake: (perSystem flake).nullkomma.files;
                  nested = callFlakeWith {
                    nullkomma.r-non-nix.enable = true;
                    nullkomma.r.root = ../../tests/fixtures/r/R;
                  } ../../tests/fixtures/r;
                  conflict = raw {
                    imports = [ plugins.r-non-nix ];
                    nullkomma.r-non-nix.enable = true;
                    nullkomma.r.enable = false;
                  };
                in
                {
                  enablesR = standalone.debug.config.nullkomma.r.enable;
                  standaloneFiles = lib.attrNames (files standalone);
                  duplicateImports = summary standalone == summary overlapping;
                  coreFiles = lib.attrNames (files core);
                  coreLibrary = lib.hasInfix "R_LIBS_USER" (perSystem core).nullkomma.devshell.shellHook;
                  coreHasCompanion = core.debug.options.nullkomma ? r-non-nix;
                  defaultDisabled = fixtures.r.debug.config.nullkomma.r-non-nix.enable;
                  nestedProfile = files nested ? "R/.Rprofile";
                  nestedIgnore = lib.elem "R/.R/library/" nested.debug.config.nullkomma.gitignore;
                  disabledDependency = (builtins.tryEval conflict.debug.config.nullkomma.r.enable).success;
                };
              expected = {
                enablesR = true;
                standaloneFiles = [
                  ".R/install.R"
                  ".Rbuildignore"
                  ".Renviron"
                  ".Rprofile"
                  "README.md"
                ];
                duplicateImports = true;
                coreFiles = [ ".Rbuildignore" ];
                coreLibrary = true;
                coreHasCompanion = false;
                defaultDisabled = false;
                nestedProfile = true;
                nestedIgnore = true;
                disabledDependency = false;
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
                  withoutDescription =
                    (builtins.tryEval (builtins.deepSeq (perSystem rWithoutDescription).nullkomma.r.packages null))
                    .success;
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
                withoutDescription = false;
              };
            };
            testRPkgdownBrand = {
              expr = {
                assets = (perSystem rWithBrand).nullkomma.files."pkgdown/assets".mode;
                directory = (perSystem rWithBrand).nullkomma.files."pkgdown/assets".directory;
                ignored = lib.hasInfix "/pkgdown/assets\n" (perSystem rWithBrand).nullkomma.files.".gitignore".text;
                brandPackage = lib.elem "brand.yml" (perSystem rWithBrand).nullkomma.r.packages;
                defaultBrandPackage = lib.elem "brand.yml" (perSystem rWithWebsite).nullkomma.r.packages;
                defaultAssets = (perSystem rWithWebsite).nullkomma.files ? "pkgdown/assets";
                privacyOrder = rWithBrand.debug.config.nullkomma.privacy.sections.brand.order;
                privacy =
                  lib.hasInfix "Local section in English"
                    (perSystem rWithBrand).nullkomma.files."pkgdown/privacy.md".text;
                footer = rWithBrand.debug.config.nullkomma.r.pkgdown.config.footer.components.brand;
              };
              expected = {
                assets = "generated";
                directory = true;
                ignored = true;
                brandPackage = true;
                defaultBrandPackage = false;
                defaultAssets = false;
                privacyOrder = 100;
                privacy = true;
                footer = ''
                  <div id="shared-brand">Shared brand footer · 🌲 <a href="privacy.html">Privacy</a></div>
                '';
              };
            };
            testRPkgdownPrivacy = {
              expr =
                let
                  files = (perSystem rWithPrivacy).nullkomma.files;
                  english = (perSystem rEnglishPrivacy).nullkomma.files."legal.md".text;
                  missing = callFlakeWith {
                    imports = [ rPrivacy ];
                    nullkomma.privacy.languages = [
                      {
                        code = "fr";
                        label = "Français";
                      }
                    ];
                  } ../../tests/fixtures/r;
                in
                {
                  generated = files."pkgdown/privacy.md".mode;
                  bilingual =
                    lib.hasInfix "Local section in English" files."pkgdown/privacy.md".text
                    && lib.hasInfix "Lokaler Abschnitt auf Deutsch" files."pkgdown/privacy.md".text;
                  singleLanguage =
                    lib.hasInfix "Local section in English" english
                    && !(lib.hasInfix "Deutsch" english)
                    && !(lib.hasInfix "<details" english);
                  plain = (perSystem rWithWebsite).nullkomma.files ? "pkgdown/privacy.md";
                  disabled = (perSystem rWithoutPrivacy).nullkomma.files ? "pkgdown/privacy.md";
                  missingLanguage =
                    (builtins.tryEval (
                      builtins.deepSeq (perSystem missing).nullkomma.files."pkgdown/privacy.md".text true
                    )).success;
                  excluded = lib.hasInfix "^pkgdown/privacy\\.md$" rWithPrivacy.debug.config.nullkomma.r.buildIgnore;
                  ignored = lib.hasInfix "/pkgdown/privacy.md\n" files.".gitignore".text;
                  renamedExcluded = lib.hasInfix "^legal\\.md$" rEnglishPrivacy.debug.config.nullkomma.r.buildIgnore;
                  rejectsUnsafePages =
                    lib.all
                      (
                        page:
                        !(builtins.tryEval (
                          builtins.deepSeq
                            (callFlakeWith {
                              imports = [ rPrivacy ];
                              nullkomma.r.pkgdown.privacy.page = page;
                            } ../../tests/fixtures/r).debug.config.nullkomma.r.pkgdown.privacy.page
                            true
                        )).success
                      )
                      [
                        "../privacy.md"
                        "pkgdown/../privacy.md"
                        "/privacy.md"
                        "pkgdown/nested/privacy.md"
                        "pkgdown/README.md"
                        "index.md"
                        "authors.md"
                        "pkgdown/cran-comments.md"
                        "pkgdown/bad\nname.md"
                      ];
                };
              expected = {
                generated = "generated";
                bilingual = true;
                singleLanguage = true;
                plain = false;
                disabled = false;
                missingLanguage = false;
                excluded = true;
                ignored = true;
                renamedExcluded = true;
                rejectsUnsafePages = true;
              };
            };
            testRWorkflowSelection = {
              expr = {
                tasks = lib.filter (lib.hasPrefix "r-") (lib.attrNames (perSystem fixtures.r).nullkomma.tasks);
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
                mkdir "$out/.R"
                cp .R/install.R "$out/.R/"
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
              gitleaks = pkgs.runCommand "gitleaks-treefmt" { } ''
                scan=${(perSystem fixtures.md).treefmt.settings.formatter.gitleaks.command}
                printf 'ordinary project text\n' > clean.txt
                "$scan" clean.txt
                printf '%s%s\n' 'ghp_' 'xcW3BwhFZwDiTfeZpXyE2KJm6RQbnVhqUsa7' > secret.txt
                if "$scan" clean.txt secret.txt > scan.log 2>&1; then
                  echo 'Secret scanner accepted a synthetic credential' >&2
                  exit 1
                fi
                ! grep -qF 'xcW3BwhFZwDiTfeZpXyE2KJm6RQbnVhqUsa7' scan.log
                cp secret.txt allowed.txt
                cat > .gitleaks.toml <<'TOML'
                [extend]
                useDefault = true
                [[allowlists]]
                paths = ["^allowed[.]txt$"]
                TOML
                "$scan" allowed.txt
                if "$scan" secret.txt > scan.log 2>&1; then
                  echo 'Native allowlist disabled unrelated default rules' >&2
                  exit 1
                fi
                rm .gitleaks.toml
                printf 'secret.txt:github-pat:1\n' > .gitleaksignore
                "$scan" secret.txt
                mkdir docs
                cp secret.txt docs/generated.md
                touch flake.nix
                ${lib.getExe (perSystem rWithWebsite).treefmt.build.wrapper} --no-cache --fail-on-change docs/generated.md
                touch "$out"
              '';
              r-pkgdown-brand = pkgs.runCommand "r-pkgdown-brand" { } ''
                site=${rWithBrand.packages.${system}.site}
                grep -qF 'Sandbox brand footer · 🌲' "$site/index.html"
                grep -qF 'Local section in English' "$site/privacy.html"
                grep -qF 'Lokaler Abschnitt auf Deutsch' "$site/privacy.html"
                for text in 'Browse source code' 'Report a bug' 'CC0' 'Citing nullkommafixture' 'Developers'; do
                  grep -qF "$text" "$site/index.html"
                done
                grep -qF 'https://github.com/dataheld/nullkomma/issues' "$site/index.html"
                ! grep -qF 'View on CRAN' "$site/index.html"
                test -s "$site"/deps/bootstrap-*/bootstrap.bundle.min.js
                test -s "$site"/deps/bootstrap-*/bootstrap.bundle.min.js.map
                grep -qF '#123456' "$site"/deps/bootstrap-*/*.css
                cmp ${../../tests/fixtures/r-brand/assets/brand.svg} "$site/brand.svg"
                test ! -e "$site/.nullkomma-generated"
                test -s "$site/deps/headroom-0.11.0/headroom.min.js"
                test -s "$site/deps/headroom-0.11.0/jQuery.headroom.min.js"
                test -s "$site/deps/bootstrap-toc-1.0.1/bootstrap-toc.min.js"
                test -s "$site/deps/clipboard.js-2.0.11/clipboard.min.js"
                test -s "$site/deps/search-1.0.0/fuse.min.js"
                test -s "$site/deps/search-1.0.0/autocomplete.jquery.min.js"
                test -s "$site/deps/search-1.0.0/mark.min.js"
                touch "$out"
              '';
              r-pkgdown-published-brand =
                pkgs.runCommand "r-pkgdown-published-brand"
                  {
                    nativeBuildInputs = [ pkgs.python3 ];
                  }
                  ''
                    site=${rWithPublishedBrand.packages.${system}.site}
                    grep -qF '<div class="maxheld-footer">' "$site/index.html"
                    grep -qF 'Max Held' "$site/index.html"
                    grep -qF 'https://www.maxheld.de/imprint.html' "$site/index.html"
                    grep -qF 'href="/privacy.html"' "$site/index.html"
                    grep -qF '#453AA4' "$site"/deps/bootstrap-*/*.css
                    grep -qF 'system-ui' "$site"/deps/bootstrap-*/*.css
                    for text in 'Controller' 'Verantwortlicher' 'Cloudflare'; do
                      grep -qF "$text" "$site/privacy.html"
                    done
                    python - "$site" <<'PY'
                    import sys
                    from html.parser import HTMLParser
                    from pathlib import Path
                    from urllib.parse import urlparse

                    class Assets(HTMLParser):
                        def handle_starttag(self, tag, attrs):
                            attrs = dict(attrs)
                            url = attrs.get("src") if tag == "script" else attrs.get("href") if tag == "link" and attrs.get("rel") != "canonical" else None
                            if url:
                                assert not urlparse(url).netloc, url

                    for page in Path(sys.argv[1]).rglob("*.html"):
                        Assets().feed(page.read_text())
                    PY
                    touch "$out"
                  '';
              r-pkgdown-brand-local = pkgs.runCommand "r-pkgdown-brand-local" { } ''
                cp -R ${../../tests/fixtures/r} project
                chmod -R u+w project
                cd project
                export HOME="$TMPDIR/home" HTTPS_PROXY=http://127.0.0.1:1 HTTP_PROXY=http://127.0.0.1:1
                mkdir -p "$HOME"
                ${pkgs.git}/bin/git init -q
                ${lib.getExe (perSystem rWithBrand).nullkomma.tasks.generate-files.package}
                test -f pkgdown/assets/.nullkomma-generated
                export LC_ALL=C LANG=C
                build_site() {
                  ${lib.getExe (perSystem rWithBrand).nullkomma.tasks.r-pkgdown.package} > build.log 2>&1 || { cat build.log; exit 1; }
                  cat build.log
                  ! grep -qE "Permission denied|Failed to copy over bootstrap's javascript files" build.log
                }
                build_site
                grep -qF 'Shared brand footer · 🌲' docs/index.html
                grep -qF '<div id="shared-brand">' docs/index.html
                test "$(grep -o '<footer' docs/index.html | wc -l)" -eq 1
                grep -qF 'Local section in English' docs/privacy.html
                grep -qF 'Lokaler Abschnitt auf Deutsch' docs/privacy.html
                test ! -e privacy.md
                for text in 'Browse source code' 'Report a bug' 'CC0' 'Citing nullkommafixture' 'Developers'; do
                  grep -qF "$text" docs/index.html
                done
                grep -qF 'https://github.com/dataheld/nullkomma/issues' docs/index.html
                ! grep -qF 'View on CRAN' docs/index.html
                test -s docs/deps/bootstrap-*/bootstrap.bundle.min.js
                test -s docs/deps/bootstrap-*/bootstrap.bundle.min.js.map
                grep -qF '#123456' docs/deps/bootstrap-*/*.css
                cmp ${../../tests/fixtures/r-brand/assets/brand.svg} docs/brand.svg
                test ! -e docs/.nullkomma-generated
                test -s docs/deps/headroom-0.11.0/headroom.min.js
                touch pkgdown/assets/stale.txt
                substituteInPlace DESCRIPTION \
                  --replace-fail 'nullkomma/issues' 'nullkomma/issues/new' \
                  --replace-fail 'person("nullkomma"' 'person("Updated Author"'
                printf 'home:\n  links:\n  - text: Extra documentation\n    href: https://example.com/extra\n  sidebar:\n    structure: [authors, links, custom, license]\n    components:\n      custom:\n        title: Extra details\n        text: Offline **Markdown**\n' > _pkgdown.yml
                build_site
                grep -qF 'Updated Author' docs/index.html
                grep -qF 'https://github.com/dataheld/nullkomma/issues/new' docs/index.html
                grep -qF 'https://example.com/extra' docs/index.html
                grep -qF 'Extra details' docs/index.html
                grep -qF '<strong>Markdown</strong>' docs/index.html
                developers="$(grep -n 'data-toc-skip>Developers' docs/index.html | cut -d: -f1)"
                links="$(grep -n 'data-toc-skip>Links' docs/index.html | cut -d: -f1)"
                custom="$(grep -n 'data-toc-skip>Extra details' docs/index.html | cut -d: -f1)"
                test "$developers" -lt "$links"
                test "$links" -lt "$custom"
                test ! -e pkgdown/assets/stale.txt
                printf 'home:\n  sidebar: false\n' > _pkgdown.yml
                build_site
                ! grep -qF 'Browse source code' docs/index.html
                printf '<p id="custom-sidebar">Consumer sidebar</p>\n' > pkgdown/sidebar.html
                printf 'home:\n  sidebar:\n    html: pkgdown/sidebar.html\n' > _pkgdown.yml
                build_site
                grep -qF 'id="custom-sidebar"' docs/index.html
                ! grep -qF 'Browse source code' docs/index.html
                rm pkgdown/assets/.nullkomma-generated
                printf 'project-owned asset\n' > pkgdown/assets/keep.txt
                if ${lib.getExe (perSystem rWithBrand).nullkomma.tasks.r-pkgdown.package} > failure.log 2>&1; then
                  echo "Project-owned pkgdown assets were overwritten" >&2
                  exit 1
                fi
                grep -qF 'pkgdown/assets is project-owned' failure.log
                test "$(cat pkgdown/assets/keep.txt)" = 'project-owned asset'
                rm -rf pkgdown
                ln -s "$TMPDIR" pkgdown
                if ${lib.getExe (perSystem rWithBrand).nullkomma.tasks.r-pkgdown.package} > failure.log 2>&1; then
                  echo "Symlinked pkgdown sources were overwritten" >&2
                  exit 1
                fi
                grep -qF 'Refusing symlinked privacy source: pkgdown/privacy.md' failure.log
                test -L pkgdown
                touch "$out"
              '';
              r-pkgdown-privacy = pkgs.runCommand "r-pkgdown-privacy" { nativeBuildInputs = [ pkgs.python3 ]; } ''
                site=${rWithPrivacy.packages.${system}.site}
                english=${rEnglishPrivacy.packages.${system}.site}
                disabled=${rWithoutPrivacy.packages.${system}.site}
                test ! -e "$disabled/privacy.html"
                python - "$site/privacy.html" "$english/legal.html" <<'PY'
                import sys
                from html.parser import HTMLParser
                from pathlib import Path

                class Text(HTMLParser):
                    def __init__(self, path):
                        super().__init__()
                        self.parts = []
                        self.feed(Path(path).read_text())
                    def handle_data(self, data):
                        self.parts.append(data)

                policy, english = (" ".join(Text(path).parts) for path in sys.argv[1:])
                assert "Privacy Policy" in policy
                assert "Generated by nullkomma" not in policy
                assert policy.index("Local section in English") < policy.index("Hosting, delivery, security and web analytics by Cloudflare")
                assert "Lokaler Abschnitt auf Deutsch" in policy
                assert "Local section in English" in english
                assert "Deutsch" not in english
                PY
                touch "$out"
              '';
              r-pkgdown-privacy-local = pkgs.runCommand "r-pkgdown-privacy-local" { } ''
                cp -R ${../../tests/fixtures/r} project
                chmod -R u+w project
                cd project
                export HOME="$TMPDIR/home"
                mkdir -p "$HOME"
                printf 'home:\n  sidebar: false\n' > _pkgdown.yml
                ${pkgs.git}/bin/git init -q
                ${lib.getExe (perSystem rWithPrivacy).nullkomma.tasks.write-files.package}
                ${lib.getExe (perSystem rWithPrivacy).nullkomma.tasks.r-pkgdown.package}
                test -s docs/privacy.html
                test ! -e docs/pkgdown/privacy.html
                test ! -e privacy.md
                grep -qF 'Local section in English' docs/privacy.html
                grep -qF 'Lokaler Abschnitt auf Deutsch' docs/privacy.html
                head -n 1 pkgdown/privacy.md | grep -q '^<!-- Generated by nullkomma.* -->$'
                ${pkgs.git}/bin/git check-ignore -q pkgdown/privacy.md
                grep -qxF '^pkgdown/privacy\.md$' .Rbuildignore
                cp pkgdown/privacy.md "$TMPDIR/generated-privacy.md"
                rm pkgdown/privacy.md
                ${lib.getExe (perSystem rWithPrivacy).nullkomma.tasks.generate-files.package}
                cmp pkgdown/privacy.md "$TMPDIR/generated-privacy.md"
                pkgdown=${lib.getExe (perSystem rWithPrivacy).nullkomma.tasks.r-pkgdown.package}
                rejects() {
                  if "$pkgdown" > failure.log 2>&1; then
                    echo "Expected privacy staging to reject $1" >&2
                    exit 1
                  fi
                  grep -qF "$1" failure.log || { cat failure.log; exit 1; }
                }
                chmod u+w pkgdown/privacy.md
                printf 'own policy\n' > pkgdown/privacy.md
                rejects 'set nullkomma.r.pkgdown.privacy.page = null'
                test "$(cat pkgdown/privacy.md)" = 'own policy'
                rm pkgdown/privacy.md
                mkdir pkgdown/privacy.md
                rejects 'set nullkomma.r.pkgdown.privacy.page = null'
                test -d pkgdown/privacy.md
                rmdir pkgdown/privacy.md
                ln -s "$TMPDIR/generated-privacy.md" pkgdown/privacy.md
                rejects 'Refusing symlinked privacy source'
                test -L pkgdown/privacy.md
                rm pkgdown/privacy.md
                ln -s "$TMPDIR/missing.md" pkgdown/privacy.md
                rejects 'Refusing symlinked privacy source'
                test -L pkgdown/privacy.md
                rm pkgdown/privacy.md
                for collision in privacy.md .github/privacy.md pkgdown/assets/privacy.html; do
                  mkdir -p "$(dirname "$collision")"
                  printf 'own page\n' > "$collision"
                  rejects 'Privacy output collision'
                  test "$(cat "$collision")" = 'own page'
                  test ! -e pkgdown/privacy.md
                  rm "$collision"
                done
                rm -rf pkgdown
                ln -s "$TMPDIR" pkgdown
                rejects 'Refusing symlinked privacy source'
                test -L pkgdown
                test ! -e "$TMPDIR/privacy.md"
                rm pkgdown
                pkgdown=${lib.getExe (perSystem rPrivacyAssetCollision).nullkomma.tasks.r-pkgdown.package}
                rejects 'Privacy output collision in nullkomma.r.pkgdown.assets'
                test ! -e pkgdown/privacy.md
                touch "$out"
              '';
              treefmt-linters = pkgs.runCommand "treefmt-linters" { } ''
                cp -R ${../../tests/fixtures/r} project
                chmod -R u+w project
                cd project
                export HOME="$TMPDIR/home"
                mkdir -p "$HOME"
                format() {
                  ${lib.getExe (perSystem rWithTreefmtLint).treefmt.build.wrapper} \
                    --no-cache --walk=filesystem "$@"
                }
                rejects() {
                  rule="$1"
                  shift
                  if format "$@" > failure.log 2>&1; then
                    echo "Expected treefmt to reject $rule" >&2
                    exit 1
                  fi
                  grep -qF "$rule" failure.log || { cat failure.log; exit 1; }
                }
                for directory in docs/nested managed/nested generated/nested; do
                  mkdir -p "$directory"
                  printf 'x <- (\n' > "$directory/bad.R"
                  printf 'broken: [\n' > "$directory/bad.yaml"
                  printf '[broken]()\n' > "$directory/bad.md"
                done
                format
                format docs/nested/bad.R managed/nested/bad.yaml generated/nested/bad.md
                printf '# Title\n\n<div>HTML is allowed.</div>\n\n' > allowed.md
                printf 'long line %.0s' {1..15} >> allowed.md
                printf '\n' >> allowed.md
                format allowed.md
                printf '# Title\n\n[broken]()\n' > 'literal[1].md'
                rejects MD042 'literal[1].md'
                printf 'MD042: false\n' > .markdownlint.yml
                printf 'globs: ["docs/nested/bad.md"]\nignores: ["ignored.md"]\n' > .markdownlint-cli2.yaml
                printf '# Title\n\n[broken]()\n' > ignored.md
                format 'literal[1].md' allowed.md ignored.md
                printf 'MD013: true\n' > .markdownlint.yml
                rejects MD013 allowed.md
                mkdir nested-config
                cp allowed.md nested-config/allowed.md
                printf 'MD013: false\nMD033: true\n' > nested-config/.markdownlint.yaml
                rejects MD033 nested-config/allowed.md
                rm .markdownlint.yml
                format ignored.md
                rejects MD042 'literal[1].md'
                printf 'config: {MD042: false}\nglobs: ["docs/nested/bad.md"]\n' > .markdownlint-cli2.yaml
                format 'literal[1].md' allowed.md
                rm -r .markdownlint-cli2.yaml allowed.md 'literal[1].md' ignored.md nested-config
                printf 'name: value\n' > custom.yaml
                printf 'rules:\n  quoted-strings: {required: true}\nignore-from-file: .yamlignore\n' > .yamllint
                printf 'ignored.yaml\n' > .yamlignore
                cp custom.yaml ignored.yaml
                cp custom.yaml shared-ignore.yaml
                rejects quoted-strings custom.yaml
                format ignored.yaml shared-ignore.yaml
                printf 'name: "%0120d"\n' 0 > long.yaml
                format long.yaml
                printf 'rules:\n  line-length: {max: 20}\n' > .yamllint
                rejects line-length long.yaml
                printf 'rules: {}\n' > .yamllint
                format custom.yaml long.yaml
                printf 'rules:\n  truthy: {check-keys: false}\n' > .yamllint
                printf 'name: yes\n' > partial.yaml
                format partial.yaml
                printf 'name: on\n' > partial.yaml
                rejects truthy partial.yaml
                rm .yamllint .yamlignore custom.yaml long.yaml ignored.yaml shared-ignore.yaml partial.yaml
                printf 'fnd foobaar teh\n' > DESCRIPTION.spelling
                cp DESCRIPTION DESCRIPTION.original
                printf '\nConfig/nullkomma/test: fnd foobaar teh\n' >> DESCRIPTION
                printf '[default.extend-words]\nfoobaar = "foobaar"\n[files]\nextend-exclude = ["ignored.txt"]\n[type.r-description.extend-words]\nfnd = "find"\n' > .typos.toml
                printf 'teh\n' > ignored.txt
                format --formatters typos DESCRIPTION DESCRIPTION.spelling ignored.txt
                grep -q 'test: fnd foobaar the' DESCRIPTION
                grep -qx 'find foobaar the' DESCRIPTION.spelling
                grep -qx teh ignored.txt
                mkdir nested-config
                printf '[default.extend-words]\nfnd = "find"\n' > nested-config/.typos.toml
                printf 'fnd teh\n' > nested-config/words.txt
                format --formatters typos nested-config/words.txt
                grep -qx 'find the' nested-config/words.txt
                mv DESCRIPTION.original DESCRIPTION
                rm -r .typos.toml DESCRIPTION.spelling ignored.txt nested-config
                printf 'CamelCaseObjectWithAnIntentionallyLongName <- 1L\n# %090d\n' 0 > R/policy.R
                format R/policy.R
                printf '# %0101d\n' 0 >> R/policy.R
                rejects line_length_linter R/policy.R
                printf 'linters: linters_with_defaults(object_usage_linter = NULL)\n' > .lintr
                rejects line_length_linter R/policy.R
                sed -i '$d' R/policy.R
                format R/policy.R
                printf 'linters: linters_with_defaults(object_name_linter())\n' > .lintr
                rejects object_name_linter R/policy.R
                printf 'linters <- linters_with_defaults(line_length_linter(120L))\n' > R/.lintr.R
                printf '# %0101d\n' 0 >> R/policy.R
                format R/policy.R
                printf '# %0121d\n' 0 >> R/policy.R
                rejects line_length_linter R/policy.R
                printf 'exclusions <- list("policy.R")\n' > R/.lintr.R
                format R/policy.R
                printf 'linters <- list()\n' > R/.lintr.R
                format R/policy.R
                cd ..
                mkdir nested
                cp -R ${../../tests/fixtures/r} nested/r
                chmod -R u+w nested/r
                cd nested
                touch flake.nix
                ${lib.getExe (perSystem rNestedTreefmt).treefmt.build.wrapper} \
                  --no-cache --walk=filesystem r/R/hello.R
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
              r-files =
                pkgs.runCommand "nullkomma-r-files"
                  {
                    nativeBuildInputs = [
                      pkgs.git
                      pkgs.R
                    ];
                  }
                  ''
                    cp -R ${../../tests/fixtures/r} project
                    chmod -R u+w project
                    cd project
                    git init -q
                    ${lib.getExe (perSystem fixtures.r).nullkomma.tasks.write-files.package}
                    test ! -e .Rprofile
                    test ! -e .Renviron
                    test ! -e .R/install.R
                    grep -qxF '^project-only[.]txt$' .Rbuildignore
                    test "$(grep -xcF '^[.]envrc$' .Rbuildignore)" = 1
                    mkdir -p nix .github/workflows .vscode .direnv .R/library
                    touch flake.lock nix/helper.nix .github/workflows/ci.yml .vscode/settings.json \
                      .direnv/cache .R/library/sentinel .envrc project-only.txt
                    export HOME="$TMPDIR/home"
                    mkdir -p "$HOME"
                    R CMD build --no-build-vignettes --no-manual .
                    tar -tf nullkommafixture_0.0.1.tar.gz > package-files
                    if grep -E '([.]nix$|/(flake[.]lock|pkg[.]lock|[.]R|[.]envrc|[.]direnv|[.]github|[.]vscode|project-only[.]txt)(/|$))' package-files; then
                      echo "Development-only files leaked into the Nix-only package source" >&2
                      exit 1
                    fi
                    grep -qx 'nullkommafixture/R/hello.R' package-files
                    touch "$out"
                  '';
              r-interactive =
                pkgs.runCommand "nullkomma-r-interactive"
                  { nativeBuildInputs = (perSystem fixtures.r).nullkomma.devshell.packages; }
                  ''
                    export HOME="$TMPDIR/home"
                    mkdir -p "$HOME"
                    unset R_PROFILE_USER R_ENVIRON_USER
                    echo 'profile_loaded <- TRUE' > .Rprofile
                    Rscript --vanilla -e 'restore_me <- TRUE; save(restore_me, file = ".RData")'
                    sha256sum .RData > workspace-before
                    printf 'if (exists("restore_me") || !exists("profile_loaded")) q(status = 1)\ncreated <- TRUE\nq()\n' | R --interactive > session.log 2>&1
                    sha256sum -c workspace-before
                    rm .RData
                    printf 'created <- TRUE\nq()\n' | R --interactive >> session.log 2>&1
                    test ! -e .RData
                    if grep -E 'R version|Copyright|Save workspace|save workspace|Restored' session.log; then
                      echo "Interactive R printed startup chatter or asked to save" >&2
                      exit 1
                    fi
                    R CMD config CC > compiler
                    test -s compiler
                    Rscript --vanilla -e 'stopifnot(!exists("profile_loaded"))'
                    touch "$out"
                  '';
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
                    export R_LIBS_USER="$HOME/user-library"
                    export R_LIBS_SITE="$HOME/site-library"
                    mkdir -p "$R_LIBS_USER" "$R_LIBS_SITE"
                    R CMD INSTALL --library="$R_LIBS_USER" .
                    R CMD INSTALL --library="$R_LIBS_SITE" .
                    find "$HOME" -type f -exec sha256sum {} + | sort > external-before
                    test -s external-before
                    Rscript -e '
                      stopifnot(startsWith(.libPaths()[1], file.path(getwd(), ".R", "library")))
                      stopifnot(!any(file.path(Sys.getenv("HOME"), c("user-library", "site-library")) %in% .libPaths()))
                      stopifnot(!requireNamespace("nullkommafixture", quietly = TRUE))
                      stopifnot(getOption("repos")[["CRAN"]] == Sys.getenv("NULLKOMMA_PPM_URL"))
                      stopifnot(all(c("Config/Needs/development", "Config/Needs/website") %in% getOption("nullkomma.r.dependencies")))
                    '
                    Rscript -e '
                      install.packages(".", repos = NULL, type = "source")
                      stopifnot(startsWith(find.package("nullkommafixture"), getOption("nullkomma.r.library")))
                      remove.packages("nullkommafixture", lib = getOption("nullkomma.r.library"))
                    '
                    find "$HOME" -type f -exec sha256sum {} + | sort > external-after
                    cmp external-before external-after
                    if Rscript --vanilla .R/install.R > failure.log 2>&1; then
                      echo "Installer accepted a missing project profile" >&2
                      exit 1
                    fi
                    grep -qF 'with its .Rprofile enabled' failure.log
                    if IN_NIX_SHELL=impure Rscript .R/install.R > failure.log 2>&1; then
                      echo "Installer accepted a Nix environment" >&2
                      exit 1
                    fi
                    grep -qF 'outside Nix' failure.log
                    Rscript - <<'RS'
                      local({
                        library <- getOption("nullkomma.r.library")
                        options(nullkomma.r.library = tempdir())
                        failure <- tryCatch(source(".R/install.R"), error = conditionMessage)
                        stopifnot(identical(failure, "The project library must be first in .libPaths(); restart R from the project directory."))
                        options(nullkomma.r.library = library)
                        on.exit(Sys.chmod(library, "0755"))
                        Sys.chmod(library, "0555")
                        failure <- tryCatch(source(".R/install.R"), error = conditionMessage)
                        stopifnot(identical(failure, paste0("The project R library is not writable: ", library)))
                      })
                    RS
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
              r-tests-use-working-tree = pkgs.runCommand "nullkomma-r-working-tree" { } ''
                cp -r ${../../tests/fixtures/r} project
                chmod -R u+w project
                cd project
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
              cloudflare-validation-local =
                let
                  nix = pkgs.writeShellScriptBin "nix" ''
                    set -eu
                    test "$*" = 'build --no-link --print-out-paths .#deploy.config'
                    echo ${tfConfig (raw bareCloudflare)}
                  '';
                  flake = raw {
                    imports = [ bareCloudflare ];
                    perSystem.nullkomma.tests.cloudflare.packages = lib.mkForce [ nix ];
                  };
                in
                pkgs.runCommand "nullkomma-cloudflare-validation-local" { } ''
                  export HOME="$TMPDIR"
                  ${lib.getExe (perSystem flake).nullkomma.tests.cloudflare.package}
                  touch "$out"
                '';
              cloudflare-devshell =
                (raw {
                  imports = [ bareCloudflare ];
                  nullkomma.devshell.enable = true;
                  perSystem =
                    { pkgs, ... }:
                    {
                      packages.site = lib.mkForce (pkgs.runCommand "unbuildable-site" { } "exit 1");
                    };
                }).devShells.${system}.default;
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
                  nix = pkgs.writeShellScriptBin "nix" ''
                    set -eu
                    test "$1" = run
                    target="$2"
                    shift 2
                    if [[ "''${1-}" == -- ]]; then shift; fi
                    case "$target" in
                      .#deploy) exec ${deploy} "$@" ;;
                      .#deploy.init) exec ${lib.getExe flake.packages.${system}.deploy.init} "$@" ;;
                      .#deploy.terraform) exec ${lib.getExe flake.packages.${system}.deploy.terraform} "$@" ;;
                      *) exit 1 ;;
                    esac
                  '';
                  flake = raw {
                    imports = [ bareCloudflare ];
                    perSystem = {
                      terranix.terranixConfigurations.deploy.terraformWrapper.package = lib.mkForce tofu;
                      nullkomma.tasks = {
                        deploy.packages = lib.mkForce [ nix ];
                        terraform.packages = lib.mkForce [ nix ];
                      };
                    };
                  };
                  deploy = lib.getExe flake.packages.${system}.deploy;
                  tasks = (perSystem flake).nullkomma.tasks;
                in
                pkgs.runCommand "nullkomma-cloudflare-deploy" { } ''
                  export CALLED=$PWD/called CLOUDFLARE_ACCOUNT_ID=account CLOUDFLARE_STATE_BUCKET=state
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
