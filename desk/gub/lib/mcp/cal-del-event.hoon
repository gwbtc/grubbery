/<  tools  /lib/nex/tools.hoon
::  cal-del-event: remove an event from a calendar instance
::
^-  tool:tools
|%
++  name  'cal_del_event'
++  description
  'Delete an event from a calendar nexus instance by id. Use cal_events to find ids.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Calendar instance dir (e.g. "/apps/calendar.calendar")']]
      ['id' [%string 'Event id']]
  ==
++  required  ~['path' 'id']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  gs
    |=  k=@t
    ^-  @t
    =/  j=(unit json)  (~(get by args.st) k)
    ?~  j  ''
    ?.  ?=(%s -.u.j)  ''
    p.u.j
  =/  pax-parsed=(each path @t)  (parse-path:tools (gs 'path'))
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  ?:  =('' (gs 'id'))
    (pure:m [%error 'Missing id'])
  =/  jon=json
    %-  pairs:enjs:format
    ~[['action' s+'del-event'] ['id' s+(gs 'id')]]
  =/  road=road:tarball  [%& %& p.pax-parsed %'calendar.calendar']
  ;<  ~  bind:m  (poke:io road [[/ %json] jon])
  (pure:m [%text (crip "Event {(trip (gs 'id'))} deleted")])
--
