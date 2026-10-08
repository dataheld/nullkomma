# Makes `flake.flakeModules.<name>` mergeable, so several files can each
# contribute to the same exported module (and adds den-ready `flake.modules.flake`).
{ inputs, ... }:
{
  imports = [ inputs.flake-parts.flakeModules.flakeModules ];
}
