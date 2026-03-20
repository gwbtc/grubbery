::  clear-weir: clear all sandbox rules from a directory
::
!:
^-  tool:tools
|%
++  name  'clear_weir'
++  description  'Clear all sandbox (weir) rules from a directory, giving it unrestricted access'
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['path' [%string 'Directory to clear the weir from']]])
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  weir-path=@t  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
  ;<  ~  bind:m  (sand:io /weir [%& %| (stab weir-path)] ~)
  (pure:m [%text (crip "Cleared weir from {(trip weir-path)}")])
--
