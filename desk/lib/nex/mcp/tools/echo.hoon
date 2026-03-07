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
  =/  msg=@t  (~(dog jo:json-utils [%o args.st]) /message so:dejs:format)
  (pure:m [%text msg])
--
