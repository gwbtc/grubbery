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
  :~  ['path' [%string 'Directory path (e.g. "/config/creds")']]
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
  ;<  [grub-name=@ta =seen:nexus]  bind:m
    (lookup-grub:tools pax u.file-name)
  ?.  ?=([%& %file *] seen)
    (pure:m [%error (crip "Not found: {(trip u.file-path)}/{(trip u.file-name)}")])
  (render-grub-content:tools seen)
--
