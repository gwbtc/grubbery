::  create-folder: create a folder in the grubbery ball
::
!:
^-  tool:tools
|%
++  name  'create_folder'
++  description  'Create a folder in the grubbery ball.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Parent directory path (e.g. "/")']]
      ['name' [%string 'Folder name']]
  ==
++  required  ~['path' 'name']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parent-path=@t  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  folder-name=@t  (~(dog jo:json-utils [%o args.st]) /name so:dejs:format)
  =/  dir-name=@ta  folder-name
  =/  folder-path=path  (snoc (stab parent-path) dir-name)
  =/  new-ball=ball:tarball  [`[~ ~ ~] ~]
  ;<  ~  bind:m  (make:io /mkdir [%& %| folder-path] &+[*sand:nexus new-ball])
  (pure:m [%text (crip "Created folder {(spud folder-path)}")])
--
