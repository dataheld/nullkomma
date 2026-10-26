## nullkomma

This project's development environment comes from [nullkomma](https://github.com/dataheld/nullkomma).
Run commands inside its dev shell:
`direnv exec . <command>`, or `nix develop --command <command>` without direnv.
`tasks` lists the project's workflows.

Before you report a change as done, run `tasks all` and fix what fails.
It runs formatting, linting and the checks locally, faster than CI.

Skills for nullkomma itself are in `.agents/skills/nullkomma-*`;
if they are missing, run `nk-generate-files`.
