/<  tools  /lib/tools.hoon
::  read_itinerary: return one itinerary document (pins, zones, categories)
::  as JSON text.
::
!:
^-  tool:tools
|%
++  name  'read_itinerary'
++  description  'Read one itinerary document in full by id (e.g. "turin"). Returns its JSON: name, center, zoom, categories, pins, zones.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['id' [%string 'the itinerary id, e.g. turin']]
  ==
++  required  ~['id']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  id=(unit @t)  (~(deg jo:json-utils [%o args.st]) /id so:dejs:format)
  ?~  id  (pure:m [%error 'Missing required argument: id'])
  =/  fname=@ta  (crip "{(trip u.id)}.json")
  ;<  fv=view:nexus  bind:m
    (peek:io [%& %& /apps/itinerary/itineraries fname] `[/ %json])
  ?.  ?=([%file *] fv)
    (pure:m [%error (crip "No itinerary with id {(trip u.id)}")])
  =/  jon=json  (fall (mole |.(!<(json (need-vase:tarball sang.fv)))) *json)
  (pure:m [%text (en:json:html jon)])
--
