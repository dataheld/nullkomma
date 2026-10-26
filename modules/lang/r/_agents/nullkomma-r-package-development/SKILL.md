---
name: nullkomma-r-package-development
description: Develop and check R packages using nullkomma's project workflows.
---

# Developing R packages

Use the R plugin's `tasks` workflows instead of invoking R tooling directly.
Run them inside the project's development shell:

- `tasks r-document` to regenerate package documentation and `NAMESPACE`.
- `tasks r-test` to run the package's testthat tests.
- `tasks r-check` to run `R CMD check`.

Use `direnv exec . <command>` or, without direnv,
`nix develop --command <command>`. First run `tasks` to confirm which optional
workflows the project enables. Do not run `R`, `Rscript`, or `R CMD` outside
the development shell.
