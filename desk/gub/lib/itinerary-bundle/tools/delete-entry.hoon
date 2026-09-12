/<  tools  /lib/tools.hoon
::  delete_entry: remove one pin or zone from an itinerary document.
::
!:
^-  tool:tools
|%
++  name  'delete_entry'
++  description  'Delete a pin or zone from an itinerary. field is "pins" or "zones".'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['itinerary' [%string 'the itinerary id, e.g. turin']]
      ['field' [%string '"pins" or "zones"']]
      ['id' [%string 'the entry id to delete']]
  ==
++  required  ~['itinerary' 'field' 'id']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  itin=(unit @t)   (deg /itinerary so:dejs:format)
  =/  field=(unit @t)  (deg /field so:dejs:format)
  =/  eid=(unit @t)    (deg /id so:dejs:format)
  ?:  |(?=(~ itin) ?=(~ field) ?=(~ eid))
    (pure:m [%error 'Missing required argument'])
  ?.  |(=('pins' u.field) =('zones' u.field))
    (pure:m [%error 'field must be "pins" or "zones"'])
  =/  fname=@ta  (crip "{(trip u.itin)}.json")
  =/  doc-road  `road:tarball`[%& %& /apps/itinerary/itineraries fname]
  ;<  fv=view:nexus  bind:m  (peek:io doc-road `[/ %json])
  ?.  ?=([%file *] fv)
    (pure:m [%error (crip "No itinerary with id {(trip u.itin)}")])
  =/  doc=json  (fall (mole |.(!<(json (need-vase:tarball sang.fv)))) *json)
  ?.  ?=([%o *] doc)
    (pure:m [%error 'Bad itinerary format'])
  =/  old=(map @t json)
    =/  p=(unit json)  (~(get by p.doc) u.field)
    ?.  ?=([~ %o *] p)  ~
    p.u.p
  =/  updated=json
    [%o (~(put by p.doc) u.field [%o (~(del by old) `@t`u.eid)])]
  ;<  ~  bind:m  (over:io doc-road [[/ %json] updated])
  (pure:m [%text (crip "Deleted {(trip u.field)}/{(trip u.eid)} from {(trip u.itin)}")])
--
