/<  tools  /lib/tools.hoon
::  read_itinerary: return this trip's itinerary document (pins, zones,
::  categories, schedule, todos) as JSON text. The trip is the one the
::  agent lives in — there is no other.
::
!:
^-  tool:tools
|%
++  name  'read_itinerary'
++  description  'Read the itinerary document in full. Returns its JSON: name, desc, dates, tz, center, zoom, categories, pins, zones, schedule, todos.'
++  parameters
  ^-  (map @t parameter-def:tools)
  ~
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  dr=(unit road:tarball)  bind:m  trip-doc:tools
  ?~  dr  (pure:m [%error 'not running inside a trip agent'])
  ;<  fv=view:nexus  bind:m  (peek:io u.dr `[/ %json])
  ?.  ?=([%file *] fv)
    (pure:m [%error 'No itinerary document in this trip'])
  =/  jon=json  (fall (mole |.(!<(json (need-vase:tarball sang.fv)))) *json)
  (pure:m [%text (en:json:html jon)])
--
