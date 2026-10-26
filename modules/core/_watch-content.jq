def changed:
  . as $path
  | (file_meta) as $meta
  | if $meta.dir then false
    else
      (if $meta == null then null else file_hash end) as $hash
      | (kv_fetch($path) // {hash: $initial[$path]}) as $previous
      | ({hash: $hash} | kv_store($path))
      | $previous.hash != $hash
    end;

[.tags[]? | select(.kind == "path") | .absolute] as $paths
| if $paths == [] then true
  else
    [$paths[] | . as $path
      | if any($roots[]; . as $root | $path | startswith($root))
        then changed else true end]
    | any
  end
