/<  tools  /lib/tools.hoon
::  delete_field: remove any field from an itinerary document by slash path.
::
=>  |%
    ++  del-at
      |=  [doc=json pat=(list @t)]
      ^-  json
      ?~  pat  doc
      ?.  ?=([%o *] doc)  doc
      ?~  t.pat  [%o (~(del by p.doc) i.pat)]
      =/  sub=(unit json)  (~(get by p.doc) i.pat)
      ?~  sub  doc
      [%o (~(put by p.doc) i.pat $(doc u.sub, pat t.pat))]
    ::  split a slash path into segments, dropping empties
    ++  split-path
      |=  pat=@t
      ^-  (list @t)
      =/  t=tape  (trip pat)
      =|  acc=(list tape)
      =|  cur=tape
      |-  ^-  (list @t)
      ?~  t
        %+  murn  (flop [cur acc])
        |=(s=tape ?~(s ~ `(crip (flop s))))
      ?:  =('/' i.t)  $(acc [cur acc], cur ~, t t.t)
      $(cur [i.t cur], t t.t)
    --
!:
^-  tool:tools
|%
++  name  'delete_field'
++  description
  'Delete any field from an itinerary document by slash path, e.g. "pins/tre-galli", "categories/landmark", "zones/po-walk/notes".'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'slash path from the document root']]
  ==
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  pat=(unit @t)   (deg /path so:dejs:format)
  ?:  |(?=(~ pat))
    (pure:m [%error 'Missing required argument'])
  =/  segs=(list @t)  (split-path u.pat)
  ?~  segs  (pure:m [%error 'path is empty'])
  ;<  dr=(unit road:tarball)  bind:m  trip-doc:tools
  ?~  dr  (pure:m [%error 'not running inside a trip agent'])
  =/  doc-road=road:tarball  u.dr
  ;<  fv=view:nexus  bind:m  (peek:io doc-road `[/ %json])
  ?.  ?=([%file *] fv)
    (pure:m [%error (crip "No itinerary document in this trip")])
  =/  doc=json  (fall (mole |.(!<(json (need-vase:tarball sang.fv)))) *json)
  =/  updated=json  (del-at doc segs)
  ;<  ~  bind:m  (over:io doc-road [[/ %json] updated])
  (pure:m [%text (crip "Deleted {(trip u.pat)}")])
--
