::  get-ship: return the current ship name
::
!:
^-  tool:tools
|%
++  name  'get_ship'
++  description  'Get the current ship name'
++  parameters  *(map @t parameter-def:tools)
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
  (pure:m [%text (scot %p our.bowl)])
--
