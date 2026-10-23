/<  tools  /lib/tools.hoon
::  read-grub: read a grub (file) from the grubbery ball
::
!:
^-  tool:tools
|%
++  name  'read_grub'
++  description  'Read a grub (file) from the grubbery ball. Returns JSON content directly, other marks as text.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Directory path (e.g. "/mcp.mcp")']]
      ['name' [%string 'Grub filename (e.g. "telegram.json")']]
  ==
++  required  ~['path' 'name']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  file-path=(unit @t)  (~(deg jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  file-name=(unit @t)  (~(deg jo:json-utils [%o args.st]) /name so:dejs:format)
  ?~  file-path
    (pure:m [%error 'Missing required argument: path'])
  ?~  file-name
    (pure:m [%error 'Missing required argument: name'])
  =/  pax-parsed=(each path @t)  (parse-path:tools u.file-path)
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  pax=path  p.pax-parsed
  ;<  [grub-name=@ta =view:nexus]  bind:m
    (lookup-grub:tools pax u.file-name)
  ?.  ?=([%file *] view)
    (pure:m [%error (crip "Not found: {(trip u.file-path)}/{(trip u.file-name)}")])
  ::  a mark this nexus has no conversion for is converted where the
  ::  grub lives: the peek asks for mime, and the kernel resolves the
  ::  tube from the grub's own position
  =/  known=?
    ?:  ?=(%| -.q.sang.view)  &
    =/  nm=@tas  name.p.sang.view
    |((is-text-blot:tools nm) =(%mime nm))
  ?:  known  (render-grub-content:tools view)
  ;<  as-mime=view:nexus  bind:m  (peek:io [%& %& pax u.file-name] `[/ %mime])
  (render-grub-content:tools as-mime)
--
