::  keys: build cache key map
::
::    (map rail:tarball @uv)
::    Maps each source file to its build cache key.
::
/+  tarball
|_  keys=(map rail:tarball @uv)
++  grad  %noun
++  grow
  |%
  ++  noun  keys
  ++  json
    ^-  ^json
    :-  %a
    %+  turn  ~(tap by keys)
    |=  [=rail:tarball key=@uv]
    %-  pairs:enjs:format
    :~  ['file' s+(crip (spud (snoc path.rail name.rail)))]
        ['key' s+(scot %uv key)]
    ==
  ++  mime
    ^-  ^mime
    [/application/json (as-octs:mimes:html (en:json:html json))]
  --
++  grab
  |%
  ++  noun  (map rail:tarball @uv)
  --
--
