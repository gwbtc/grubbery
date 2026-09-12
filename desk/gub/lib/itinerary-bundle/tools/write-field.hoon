/<  tools  /lib/tools.hoon
::  write_field: set any field in an itinerary document by slash path.
::  "desc" sets the trip description, "categories/landmark" a category,
::  "pins/tre-galli" a pin, "center" the map center. An empty path
::  replaces the whole document (value must then be an object).
::
=>  |%
    ++  put-at
      |=  [doc=json pat=(list @t) val=json]
      ^-  json
      ?~  pat  val
      =/  obj=(map @t json)  ?.(?=([%o *] doc) ~ p.doc)
      =/  sub=json  (fall (~(get by obj) i.pat) [%o ~])
      [%o (~(put by obj) i.pat $(doc sub, pat t.pat))]
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
++  name  'write_field'
++  description
  '''
  Set any field in an itinerary document. path is slash-separated from the
  document root: "desc" (markdown trip notes), "name", "center", "zoom",
  "categories/<key>" ({"label","color"}), "pins/<id>", "zones/<id>", or any
  nested field like "pins/<id>/notes". value is JSON as a string. An empty
  path replaces the entire document (value must be the full object).
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['itinerary' [%string 'the itinerary id, e.g. turin']]
      ['path' [%string 'slash path from the document root, e.g. desc or pins/tre-galli']]
      ['value' [%string 'the new value as a JSON string']]
  ==
++  required  ~['itinerary' 'path' 'value']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  itin=(unit @t)  (deg /itinerary so:dejs:format)
  =/  pat=(unit @t)   (deg /path so:dejs:format)
  =/  val=(unit @t)   (deg /value so:dejs:format)
  ?:  |(?=(~ itin) ?=(~ pat) ?=(~ val))
    (pure:m [%error 'Missing required argument'])
  =/  vj=(unit json)  (de:json:html u.val)
  ?~  vj  (pure:m [%error 'value is not valid JSON'])
  =/  segs=(list @t)  (split-path u.pat)
  =/  fname=@ta  (crip "{(trip u.itin)}.json")
  =/  doc-road  `road:tarball`[%& %& /apps/itinerary/itineraries fname]
  ;<  fv=view:nexus  bind:m  (peek:io doc-road `[/ %json])
  ?.  ?=([%file *] fv)
    (pure:m [%error (crip "No itinerary with id {(trip u.itin)}")])
  =/  doc=json  (fall (mole |.(!<(json (need-vase:tarball sang.fv)))) *json)
  ?:  &(?=(~ segs) !?=([%o *] u.vj))
    (pure:m [%error 'Replacing the whole document requires an object value'])
  =/  updated=json  (put-at doc segs u.vj)
  ;<  ~  bind:m  (over:io doc-road [[/ %json] updated])
  (pure:m [%text (crip "Set {(trip u.pat)} in {(trip u.itin)}")])
--
