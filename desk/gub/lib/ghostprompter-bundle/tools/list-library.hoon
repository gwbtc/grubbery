/<  tools  /lib/tools.hoon
::  list_library: the user's reference library — every document name
::  under /apps/ghostprompter/library. The agent weir clamps this to
::  read-only reach.
::
!:
^-  tool:tools
|%
++  name  'list_library'
++  description  'List every document in the user\'s library by name. Read one with read_doc.'
++  parameters  *(map @t parameter-def:tools)
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek:io [%& %| /apps/ghostprompter/library] ~)
  =/  cs
    ?.  ?=([%ball *] dv)  ~
    ?~  fil.ball.dv  ~
    contents.u.fil.ball.dv
  =/  names=(list @ta)  ~(tap in ~(key by cs))
  ?~  names  (pure:m [%text 'The library is empty.'])
  %-  pure:m
  :-  %text
  (crip (zing (turn `(list @ta)`names |=(n=@ta (weld (trip n) "\0a")))))
--
