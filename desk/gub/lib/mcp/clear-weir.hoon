/<  tools  /lib/nex/tools.hoon
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
  =/  parsed=(each @t tang)
    (mule |.((~(dog jo:json-utils [%o args.st]) /path so:dejs:format)))
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid argument: path'])
  =/  weir-path=@t  p.parsed
  ;<  ~  bind:m  (sand:io /weir [%& %| (stab weir-path)] ~)
  (pure:m [%text (crip "Cleared weir from {(trip weir-path)}")])
--
