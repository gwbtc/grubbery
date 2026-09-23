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
  :~  ['field' [%string 'which list the entry is in. One of: pins | zones.']]
      ['id' [%string 'the id of the entry to delete, as shown in read_itinerary (kebab-case, e.g. caffe-torino)']]
  ==
++  required  ~['field' 'id']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  field=(unit @t)  (deg /field so:dejs:format)
  =/  eid=(unit @t)    (deg /id so:dejs:format)
  ?:  |(?=(~ field) ?=(~ eid))
    (pure:m [%error 'Missing required argument'])
  ?.  |(=('pins' u.field) =('zones' u.field))
    (pure:m [%error 'field must be "pins" or "zones"'])
  ;<  dr=(unit road:tarball)  bind:m  trip-doc:tools
  ?~  dr  (pure:m [%error 'not running inside a trip agent'])
  =/  doc-road=road:tarball  u.dr
  ;<  fv=view:nexus  bind:m  (peek:io doc-road `[/ %json])
  ?.  ?=([%file *] fv)
    (pure:m [%error (crip "No itinerary document in this trip")])
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
  (pure:m [%text (crip "Deleted {(trip u.field)}/{(trip u.eid)}")])
--
