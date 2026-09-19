/<  tools  /lib/tools.hoon
::  delete_file: remove one attachment (or an entire subfolder) from an
::  itinerary's files root.
::
!:
=<  ^-  tool:tools
    |%
++  name  'delete_file'
++  description
  '''
  Delete a file (or a whole subfolder) from an itinerary's attachments.
  path is relative to the itinerary's files root, e.g. "old-notes.md" or
  "drafts". Cannot delete the root itself.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'file or folder path relative to the files root']]
  ==
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  rel=(unit @t)   (deg /path so:dejs:format)
  ?~  rel
    (pure:m [%error 'Missing required argument'])
  ;<  tu=(unit @ud)  bind:m  trip-up:tools
  ?~  tu  (pure:m [%error 'not running inside a trip agent'])
  =/  up=@ud  u.tu
  =/  parsed=(each path @t)  (rel-path u.rel)
  ?:  ?=(%| -.parsed)  (pure:m [%error p.parsed])
  ?~  p.parsed  (pure:m [%error 'refusing to delete the files root'])
  =/  full=path  (weld `path`/files p.parsed)
  =/  frail=road:tarball  [%| up %& (snip full) (rear full)]
  ;<  exists=?  bind:m  (peek-exists:io frail)
  ?:  exists
    ;<  ~  bind:m  (cull:io frail)
    (pure:m [%text (crip "Deleted {(trip u.rel)}")])
  ;<  dv=view:nexus  bind:m  (peek:io [%| up %| full] ~)
  ?.  ?=([%ball *] dv)
    (pure:m [%error (crip "No such file or folder: {(trip u.rel)}")])
  ;<  ~  bind:m  (cull:io [%| up %| full])
  (pure:m [%text (crip "Deleted folder {(trip u.rel)}/")])
--
|%
++  rel-path
  |=  rel=@t
  ^-  (each path @t)
  ?:  =('' rel)  [%& ~]
  =/  t=tape  (trip rel)
  =/  t=tape  ?~(t t ?:(=('/' i.t) t.t t))
  =/  t=tape  ?~(t t ?:(=('/' (rear t)) (snip `tape`t) t))
  ?~  t  [%& ~]
  ::  split on '/' by hand: names are whatever the explorer stored
  ::  (spaces, parens, capitals — phone uploads), not knot-only
  =/  segs=(list @ta)
    =/  rest=tape  t
    =|  acc=(list @ta)
    =|  cur=tape
    |-  ^-  (list @ta)
    ?~  rest  (flop [(crip (flop cur)) acc])
    ?:  =('/' i.rest)  $(rest t.rest, acc [(crip (flop cur)) acc], cur ~)
    $(rest t.rest, cur [i.rest cur])
  ?:  (lien segs |=(s=@ta |(=('' s) =('..' s) =('.' s))))
    [%| 'path must not contain empty, "." or ".." segments']
  [%& segs]
--
