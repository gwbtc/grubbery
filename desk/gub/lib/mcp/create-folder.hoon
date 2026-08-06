/<  tools  /lib/nex/tools.hoon
::  create-folder: create a folder in the grubbery ball
::
!:
^-  tool:tools
|%
++  name  'create_folder'
++  description  'Create a folder in the grubbery ball. Optionally set a nexus to make it a managed namespace.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Parent directory path (e.g. "/")']]
      ['name' [%string 'Folder name']]
      ['nexus' [%string 'Nexus path, parsed as a path with a leading slash (e.g. "/logbook", "/counter/app"). Omit for a plain folder. NOTE: this is what installs an app - the folder NAME alone never does, even a name like foo.foo_app.']]
  ==
++  required  ~['path' 'name']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each [@t @t] tang)
    %-  mule  |.
    :-  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
    (~(dog jo:json-utils [%o args.st]) /name so:dejs:format)
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid required arguments (path, name)'])
  =/  [parent-path=@t folder-name=@t]  p.parsed
  =/  nexus-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /nexus so:dejs:format)
  =/  dir-name=@ta  folder-name
  =/  folder-path=path  (snoc (stab parent-path) dir-name)
  =/  nec=(unit neck:tarball)
    ?~  nexus-raw  ~
    =/  pax=path  (stab u.nexus-raw)
    ?~  pax  ~
    `[(snip `path`pax) (rear pax)]
  =/  new-bole=bole:tarball  [`[nec ~ %.n ~] ~]
  ;<  ~  bind:m  (make:io [%& %| folder-path] &+new-bole)
  =/  msg=tape
    ?~  nexus-raw  "Created folder {(spud folder-path)}"
    "Created folder {(spud folder-path)} with nexus {(trip u.nexus-raw)}"
  (pure:m [%text (crip msg)])
--
