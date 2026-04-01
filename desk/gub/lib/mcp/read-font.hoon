/<  tools  /lib/nex/tools.hoon
^-  tool:tools
|%
++  name  'read_font'
++  description  'Find which code namespace governs a path.'
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['path' [%string 'Path to query']]])
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
  =/  pax=@t  p.parsed
  =/  =road:tarball  (cord-to-road:tarball pax)
  ;<  res=(unit bend:tarball)  bind:m  (get-font:io /font road)
  ?~  res
    (pure:m [%text (crip "No code found governing {(trip pax)}")])
  (pure:m [%text (crip "Bend: {<u.res>}")])
--
