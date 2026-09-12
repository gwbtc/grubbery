/<  tools  /lib/tools.hoon
::  write_entry: add or update one pin or zone in an itinerary document.
::  Mirrors the itinerary nexus's put-entry: read the doc, put the entry
::  under the field, write the doc back.
::
!:
^-  tool:tools
|%
++  name  'write_entry'
++  description
  '''
  Add or update a pin or zone in an itinerary. field is "pins" or "zones".
  entry is the JSON object as a string. A pin: {"name","lat","lng","cat","desc","from":[],"notes"}.
  A zone: {"name","cat","points":[[lat,lng],...] (3+ points),"desc","notes"}.
  cat must be one of the itinerary's category keys (read_itinerary shows them).
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['itinerary' [%string 'the itinerary id, e.g. turin']]
      ['field' [%string '"pins" or "zones"']]
      ['id' [%string 'the entry id, kebab-case, e.g. caffe-torino']]
      ['entry' [%string 'the pin or zone as a JSON object string']]
  ==
++  required  ~['itinerary' 'field' 'id' 'entry']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  itin=(unit @t)   (deg /itinerary so:dejs:format)
  =/  field=(unit @t)  (deg /field so:dejs:format)
  =/  eid=(unit @t)    (deg /id so:dejs:format)
  =/  entry=(unit @t)  (deg /entry so:dejs:format)
  ?:  |(?=(~ itin) ?=(~ field) ?=(~ eid) ?=(~ entry))
    (pure:m [%error 'Missing required argument'])
  ?.  |(=('pins' u.field) =('zones' u.field))
    (pure:m [%error 'field must be "pins" or "zones"'])
  =/  ej=(unit json)  (de:json:html u.entry)
  ?~  ej  (pure:m [%error 'entry is not valid JSON'])
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
    [%o (~(put by p.doc) u.field [%o (~(put by old) `@t`u.eid u.ej)])]
  ;<  ~  bind:m  (over:io doc-road [[/ %json] updated])
  (pure:m [%text (crip "Wrote {(trip u.field)}/{(trip u.eid)} in {(trip u.itin)}")])
--
