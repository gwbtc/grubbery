/<  tools  /lib/nex/tools.hoon
^-  tool:tools
|%
++  name  'read_bang'
++  description  'Check if a nexus directory or file has an error (bang). For directories returns the nexus bang and per-file errors, for files returns the file error.'
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['path' [%string 'Path to query (e.g. "/claude.claude/" for nexus, "/claude.claude/config.json" for file)']]])
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
  ;<  res=(each bangs:nexus (unit tang))  bind:m  (get-bang:io /bang road)
  ?:  ?=(%| -.res)
    ::  File error
    ::
    ?~  p.res
      (pure:m [%text (crip "No error for {(trip pax)}")])
    =/  rendered=tape
      %-  zing
      %+  turn  (flop u.p.res)
      |=(=tank (weld ~(ram re tank) "\0a"))
    (pure:m [%text (crip "BANG file {(trip pax)}\0a{rendered}")])
  ::  Directory bangs
  ::
  ?~  bang.p.res
    (pure:m [%text (crip "No nexus error at {(trip pax)}")])
  =/  rendered=tape
    %-  zing
    %+  turn  (flop u.bang.p.res)
    |=(=tank (weld ~(ram re tank) "\0a"))
  (pure:m [%text (crip "BANG nexus {(trip pax)}\0a{rendered}")])
--
