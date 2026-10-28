/<  tools  /lib/tools.hoon
/<  dm     /lib/docs-mirror.hoon
::  read_source: read one source file from the documented target's mirror (the
::  whole mirrored target). Path is relative to the collection root, e.g.
::  /gub/lib/nexus.hoon, /mar/md.hoon, or /sys.kelvin. Collection from registry.
::
!:
^-  tool:tools
|%
++  name  'read_source'
++  description
  'Read a source file from the documented target (the mirrored desk). Path relative to the collection root, e.g. /gub/lib/nexus.hoon, /mar/md.hoon, or /sys.kelvin.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'file path within the target, e.g. /gub/lib/nexus.hoon']]
  ==
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  p=(unit @t)  (~(deg jo:json-utils [%o args.st]) /path so:dejs:format)
  ?~  p  (pure:m [%error 'Missing required argument: path'])
  ::  tolerate a missing leading slash
  =/  raw=tape  (trip u.p)
  =/  arg=@t  ?:(?&(?=(^ raw) =('/' i.raw)) u.p (crip ['/' raw]))
  =/  parsed=(each path @t)  (parse-path:tools arg)
  ?:  ?=(%| -.parsed)  (pure:m [%error p.parsed])
  ?~  p.parsed  (pure:m [%error 'empty path'])
  ;<  tv=view:nexus  bind:m  (peek:io targets-road:dm `[/ %json])
  =/  tg=json
    ?.  ?=([%file *] tv)  [%a ~]
    (fall (mole |.(!<(json (need-vase:tarball sang.tv)))) [%a ~])
  =/  rt  (roots-from:dm tg)
  ?~  rt  (pure:m [%error 'No documented collection is registered.'])
  =/  full=path  (welp src.u.rt `path`p.parsed)
  ;<  [nm=@ta view=view:nexus]  bind:m
    (lookup-grub:tools (snip full) (rear full))
  ?.  ?=([%file *] view)
    (pure:m [%error (crip "not found: {(spud `path`p.parsed)}")])
  =/  txt=(unit @t)  (src-of:dm sang.view)
  ?^  txt  (pure:m [%text u.txt])
  (render-grub-content:tools view)
--
