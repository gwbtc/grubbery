/<  tools  /lib/nex/tools.hoon
^-  tool:tools
|%
++  name  'read_boom'
++  description  'Check if a nexus directory or file has a boom (error). For directories returns the nexus error, for files returns the file error.'
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['path' [%string 'Path to query (e.g. "/claude.claude/" for nexus, "/claude.claude/config.json" for file)']]])
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  pax=@t  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  =road:tarball  (cord-to-road:tarball pax)
  ;<  res=(each boom:nexus (unit tang))  bind:m  (get-boom:io /boom road)
  ?:  ?=(%| -.res)
    ::  File boom
    ?~  p.res
      (pure:m [%text (crip "No error for {(trip pax)}")])
    =/  rendered=tape
      %-  zing
      %+  turn  (flop u.p.res)
      |=(=tank (weld ~(ram re tank) "\0a"))
    (pure:m [%text (crip "BOOM file {(trip pax)}\0a{rendered}")])
  ::  Directory boom — extract this node's fol
  =/  node=[fol=(unit tang) fil=(map @ta tang)]
    (fall fil.p.res [~ ~])
  ?~  fol.node
    (pure:m [%text (crip "No nexus error at {(trip pax)}")])
  =/  rendered=tape
    %-  zing
    %+  turn  (flop u.fol.node)
    |=(=tank (weld ~(ram re tank) "\0a"))
  (pure:m [%text (crip "BOOM nexus {(trip pax)}\0a{rendered}")])
--
