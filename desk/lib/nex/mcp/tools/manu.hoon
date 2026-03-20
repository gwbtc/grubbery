::  manu: look up documentation for any path in the grubbery ball
::
!:
^-  tool:tools
|%
++  name  'read_manual'
++  description  'Look up documentation for a path in the grubbery ball. Returns the on-manu documentation from the nexus responsible for that path. Use this to understand what a directory or file is, what processes run there, and how things are structured.'
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['path' [%string 'Path to look up (e.g. "/" or "/claude.claude/" or "/claude.claude/config.json")']]])
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  pax=@t  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  =road:tarball  (cord-to-road:tarball pax)
  ;<  doc=@t  bind:m  (manu:io /manu |+road)
  ?:  =('' doc)
    (pure:m [%text (crip "No documentation found for {(trip pax)}")])
  (pure:m [%text doc])
--
