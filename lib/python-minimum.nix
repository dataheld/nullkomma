# Lower bound of a PEP 440 `requires-python` as `major.minor`; null without one.
lib: spec: lib.mapNullable lib.last (builtins.match ".*(>=?|~=|===?) *([0-9]+\\.[0-9]+).*" spec)
