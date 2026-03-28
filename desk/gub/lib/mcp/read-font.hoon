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
  =/  pax=@t  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  =road:tarball  (cord-to-road:tarball pax)
  ;<  res=(unit [=bend:tarball source=rail:tarball])  bind:m  (get-font:io /font road)
  ?~  res
    (pure:m [%text (crip "No code found governing {(trip pax)}")])
  =/  src=tape
    "{(spud path.source.u.res)}/{(trip name.source.u.res)}"
  (pure:m [%text (crip "Bend: {<bend.u.res>}\0aSource: {src}")])
--
