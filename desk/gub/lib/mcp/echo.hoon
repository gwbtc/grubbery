/<  tools  /lib/nex/tools.hoon
::  echo: simple test tool that echoes back its input
::
^-  tool:tools
|%
++  name  'echo'
++  description  'Echoes back the provided message'
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['message' [%string 'The message to echo back']]])
++  required  ~['message']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each @t tang)
    (mule |.((~(dog jo:json-utils [%o args.st]) /message so:dejs:format)))
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid argument: message'])
  =/  msg=@t  p.parsed
  (pure:m [%text msg])
--
