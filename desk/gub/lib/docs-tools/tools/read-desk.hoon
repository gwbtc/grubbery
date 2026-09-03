/<  tools  /lib/tools.hoon
::  read_desk: read a file from the raw Grubbery Clay desk — the full source
::  desk, including runtime/kernel and non-/code files. The host agent's weir
::  clamps reads to /sys/clay/desks/grubbery.
::
!:
^-  tool:tools
|%
++  name  'read_desk'
++  description
  'Read a file from the raw Grubbery Clay desk (the full source desk — includes marks, man pages, sys.kelvin, and runtime files not in /code). Path like /mar/md.hoon or /man/mcp/readme.md.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'file path within the desk, e.g. /mar/md.hoon']]
  ==
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  p=(unit @t)  (~(deg jo:json-utils [%o args.st]) /path so:dejs:format)
  ?~  p  (pure:m [%error 'Missing required argument: path'])
  =/  full=@t  (crip (weld "/sys/clay/desks/grubbery" (trip u.p)))
  =/  parsed=(each path @t)  (parse-path:tools full)
  ?:  ?=(%| -.parsed)  (pure:m [%error p.parsed])
  ?~  p.parsed  (pure:m [%error 'empty path'])
  ;<  [nm=@ta view=view:nexus]  bind:m
    (lookup-grub:tools (snip `path`p.parsed) (rear `path`p.parsed))
  ?.  ?=([%file *] view)
    (pure:m [%error (crip "not found: {(trip u.p)}")])
  (render-grub-content:tools view)
--
