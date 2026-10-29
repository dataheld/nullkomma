def changed:
  . as $path
  | (file_meta) as $meta
  | if ($meta // {}).dir then false
    else
      (if $meta == null then null else file_hash end) as $hash
      | (kv_fetch($path) // {hash: $initial[$path]}) as $previous
      | ({hash: $hash} | kv_store($path))
      | $previous.hash != $hash
    end;

def content:
  . as $path
  | any($roots[]; . as $root
      | $path == $root or ($path | startswith($root + "/")));

# inotify reports in-place writes before they finish,
# so decide on content files only once the writer closes them.
(first(.tags[]? | select(.kind == "fs") | .full) // "") as $kind
| ($kind == "Access(Close(Write))") as $closed
| [.tags[]? | select(.kind == "path") | .absolute] as $paths
| if ($kind | startswith("Access(")) and ($closed | not) then false
  elif $paths == [] then true
  else
    [$paths[]
      | if content then
          if $closed then changed
          elif $inotify and ($kind | startswith("Create(") or startswith("Modify(Data("))
          then false
          else changed end
        else ($closed | not) end]
    | any
  end
