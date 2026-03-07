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
  =/  file-path=@t  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  file-name=@t  (~(dog jo:json-utils [%o args.st]) /name so:dejs:format)
  =/  pax=path  (stab file-path)
  ;<  [grub-name=@ta =seen:nexus]  bind:m
    (lookup-grub:tools pax file-name)
  ?.  ?=([%& %file *] seen)
    (pure:m [%error (crip "Not found: {(trip file-path)}/{(trip file-name)}")])
  (render-grub-content:tools seen)
--
