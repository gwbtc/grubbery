/<  tools  /lib/tools.hoon
::  list_itineraries: list itinerary ids. Peeks the itineraries directory;
::  the host agent's weir clamps this to the itinerary nexus data.
::
!:
^-  tool:tools
|%
++  name  'list_itineraries'
++  description  'List all itineraries by id (the id is the filename without .json).'
++  parameters  *(map @t parameter-def:tools)
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek:io [%& %| /apps/itinerary/itineraries] ~)
  =/  cs
    ?.  ?=([%ball *] dv)  ~
    ?~  fil.ball.dv  ~
    contents.u.fil.ball.dv
  =/  names=(list @ta)  ~(tap in ~(key by cs))
  ?~  names  (pure:m [%text 'No itineraries yet.'])
  %-  pure:m
  :-  %text
  (crip (zing (turn `(list @ta)`names |=(n=@ta (weld (trip n) "\0a")))))
--
