/<  tools  /lib/tools.hoon
::  read_code: read a source file from the root /code nexus (the Grubbery
::  source tree). The host agent's weir clamps reads to /code.
::
!:
^-  tool:tools
|%
++  name  'read_code'
++  description
  'Read a source file from the root /code nexus (the Grubbery source tree). Path like /lib/nexus.hoon or /nex/shell/docs-agent.hoon; a leading /code is optional.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'file path under /code, e.g. /lib/tarball.hoon']]
  ==
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  p=(unit @t)  (~(deg jo:json-utils [%o args.st]) /path so:dejs:format)
  ?~  p  (pure:m [%error 'Missing required argument: path'])
  =/  raw=tape  (trip u.p)
  =/  full=@t
    ?:  =("/code" (scag 5 raw))  u.p
    (crip (weld "/code" raw))
  =/  parsed=(each path @t)  (parse-path:tools full)
  ?:  ?=(%| -.parsed)  (pure:m [%error p.parsed])
  ?~  p.parsed  (pure:m [%error 'empty path'])
  ;<  [nm=@ta view=view:nexus]  bind:m
    (lookup-grub:tools (snip `path`p.parsed) (rear `path`p.parsed))
  ?.  ?=([%file *] view)
    (pure:m [%error (crip "not found: {(trip full)}")])
  (render-grub-content:tools view)
--
