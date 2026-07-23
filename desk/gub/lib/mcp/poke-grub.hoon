/<  tools  /lib/nex/tools.hoon
::  poke-grub: poke a file's fiber with a dart
::
!:
^-  tool:tools
|%
++  name  'poke_grub'
++  description
  ^~  %-  crip
  ;:  weld
    "Poke a file in the grubbery ball. "
    "Unlike write_grub (which overwrites content), this sends a dart (action) "
    "to the file's running fiber. The fiber decides how to handle it. "
    "Content is parsed as JSON and delivered as a json-blot poke."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Directory path (e.g. "/apps/mirror.mirror")']]
      ['name' [%string 'Filename (e.g. "main.json")']]
      ['content' [%string 'JSON content to poke with']]
  ==
++  required  ~['path' 'name' 'content']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each [@t @t @t] tang)
    %-  mule  |.
    :+  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
      (~(dog jo:json-utils [%o args.st]) /name so:dejs:format)
    (~(dog jo:json-utils [%o args.st]) /content so:dejs:format)
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid required arguments (path, name, content)'])
  =/  [file-path=@t file-name=@t content=@t]  p.parsed
  =/  pax-parsed=(each path @t)  (parse-path:tools file-path)
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  pax=path  p.pax-parsed
  =/  road=road:tarball  [%& %& pax file-name]
  =/  jon=(unit json)  (de:json:html content)
  ?~  jon
    (pure:m [%error 'Failed to parse content as JSON'])
  ;<  ~  bind:m  (poke:io road [[/ %json] u.jon])
  (pure:m [%text (crip "Poked {(trip file-path)}/{(trip file-name)}")])
--
