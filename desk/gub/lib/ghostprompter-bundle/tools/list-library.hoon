/<  tools  /lib/tools.hoon
::  list_library: the user's reference library — every document under
::  /apps/ghostprompter/library with its size and line count, so the
::  agent knows to read a whole note directly and a book by range.
::  The agent weir clamps this to read-only reach.
::
!:
^-  tool:tools
|%
++  name  'list_library'
++  description  'List every document in the user\'s library: name, size, line count. Read one with read_doc (by line range for long ones).'
++  parameters  *(map @t parameter-def:tools)
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek:io [%& %| /apps/ghostprompter/library] ~)
  =/  cs
    ?.  ?=([%ball *] dv)  ~
    ?~  fil.ball.dv  ~
    contents.u.fil.ball.dv
  =/  names=(list @ta)  (sort ~(tap in ~(key by cs)) aor)
  ::  a file peek with the mime mark yields the bytes (the shallow dir
  ::  view above does not carry them); ten files, ten peeks, fine
  =/  rows=(list [n=@ta size=@ud lines=@ud])  ~
  |-
  ?^  names
    ;<  fv=view:nexus  bind:m
      (peek:io [%& %& /apps/ghostprompter/library i.names] `[/ %mime])
    =/  row=[n=@ta size=@ud lines=@ud]
      ?.  ?=([%file *] fv)  [i.names 0 0]
      =/  mv=(unit mime)  (mole |.(!<(mime (need-vase:tarball sang.fv))))
      ?~  mv  [i.names 0 0]
      =/  bytes=@ud  p.q.u.mv
      =/  nl=@ud
        =/  t=@  q.q.u.mv
        =/  i=@ud  0
        =/  k=@ud  0
        |-
        ?:  (gte i bytes)  k
        $(i +(i), k ?:(=(10 (cut 3 [i 1] t)) +(k) k))
      [i.names bytes +(nl)]
    $(names t.names, rows (snoc rows row))
  ?~  rows  (pure:m [%text 'The library is empty.'])
  %-  pure:m
  :-  %text
  %-  crip
  %-  zing
  %+  turn  rows
  |=  [n=@ta size=@ud lines=@ud]
  "{(trip n)}  ({(a-co:co lines)} lines, {(a-co:co (div size 1.024))} KB)\0a"
--
