/<  tools  /lib/nex/tools.hoon
::  copy-grub: copy a file within the grubbery ball
::
!:
^-  tool:tools
|%
++  name  'copy_grub'
++  description  'Copy a file within the grubbery ball. Source and destination are absolute paths.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['src_path' [%string 'Source directory (e.g. "/code/lib/nex")']]
      ['src_name' [%string 'Source filename (e.g. "tools.hoon")']]
      ['dst_path' [%string 'Destination directory (e.g. "/claw.claw_app/agents/testing/apps/code/lib/nex")']]
      ['dst_name' [%string 'Destination filename (defaults to src_name if omitted)']]
  ==
++  required  ~['src_path' 'src_name' 'dst_path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  src-path=(unit @t)  (bind (~(get by args.st) 'src_path') |=(j=json ?>(?=(%s -.j) p.j)))
  =/  src-name=(unit @t)  (bind (~(get by args.st) 'src_name') |=(j=json ?>(?=(%s -.j) p.j)))
  =/  dst-path=(unit @t)  (bind (~(get by args.st) 'dst_path') |=(j=json ?>(?=(%s -.j) p.j)))
  =/  dst-name=(unit @t)  (bind (~(get by args.st) 'dst_name') |=(j=json ?>(?=(%s -.j) p.j)))
  ?~  src-path  (pure:m [%error 'Missing required argument: src_path'])
  ?~  src-name  (pure:m [%error 'Missing required argument: src_name'])
  ?~  dst-path  (pure:m [%error 'Missing required argument: dst_path'])
  =/  dn=@ta  (fall dst-name u.src-name)
  =/  src-road=road:tarball  [%& %& (stab u.src-path) u.src-name]
  =/  dst-road=road:tarball  [%& %& (stab u.dst-path) dn]
  ::  read source
  ;<  =seen:nexus  bind:m  (peek:io src-road ~)
  ?.  ?=([%& %file *] seen)
    (pure:m [%error (crip "Source not found: {(trip u.src-path)}/{(trip u.src-name)}")])
  ::  write destination
  ;<  exists=?  bind:m  (peek-exists:io dst-road)
  ?:  exists
    ;<  ~  bind:m  (over:io dst-road sage.p.seen)
    (pure:m [%text (crip "Copied {(trip u.src-path)}/{(trip u.src-name)} -> {(trip u.dst-path)}/{(trip dn)}")])
  ;<  ~  bind:m  (make:io dst-road |+[%.n sage.p.seen ~])
  (pure:m [%text (crip "Copied {(trip u.src-path)}/{(trip u.src-name)} -> {(trip u.dst-path)}/{(trip dn)}")])
--
