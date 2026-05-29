/<  tools  /lib/nex/tools.hoon
::  copy-dir: copy a directory within the grubbery ball
::
!:
^-  tool:tools
|%
++  name  'copy_dir'
++  description  'Copy a directory and all its contents within the grubbery ball. Source and destination are absolute paths.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['src' [%string 'Source directory path (e.g. "/code/lib/nex")']]
      ['dst' [%string 'Destination directory path (e.g. "/claw.claw_app/agents/testing/apps/code/lib/nex")']]
  ==
++  required  ~['src' 'dst']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  src=(unit @t)  (~(deg jo:json-utils [%o args.st]) /src so:dejs:format)
  =/  dst=(unit @t)  (~(deg jo:json-utils [%o args.st]) /dst so:dejs:format)
  ?~  src  (pure:m [%error 'Missing required argument: src'])
  ?~  dst  (pure:m [%error 'Missing required argument: dst'])
  =/  src-road=road:tarball  [%& %| (stab u.src)]
  =/  dst-road=road:tarball  [%& %| (stab u.dst)]
  ::  read source directory
  ;<  =seen:nexus  bind:m  (peek:io src-road ~)
  ?.  ?=([%& %ball *] seen)
    (pure:m [%error (crip "Source not found or not a directory: {(trip u.src)}")])
  ::  create destination with source's ball subtree
  ;<  ~  bind:m  (make:io dst-road &+(ball-to-bole:tarball ball.p.seen))
  (pure:m [%text (crip "Copied {(trip u.src)} -> {(trip u.dst)}")])
--
