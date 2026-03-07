::  create-folder: create a folder in the grubbery ball
::
!:
^-  tool:tools
|%
++  name  'create_folder'
++  description  'Create a folder in the grubbery ball. Optionally set a nexus (neck) by providing a name like "mydir.nexus-name".'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Parent directory path (e.g. "/")']]
      ['name' [%string 'Folder name. Append .nexus to set a neck (e.g. "chat.claude" creates folder "chat" with nexus "claude")']]
  ==
++  required  ~['path' 'name']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parent-path=@t  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  folder-name=@t  (~(dog jo:json-utils [%o args.st]) /name so:dejs:format)
  =/  dir-ext=(unit @ta)  (parse-extension:tarball folder-name)
  =/  [dir-name=@ta dir-neck=(unit neck:tarball)]
    ?~  dir-ext  [folder-name ~]
    =/  ext-text=tape  (trip u.dir-ext)
    =/  full-text=tape  (trip folder-name)
    =/  name-len=@ud  (sub (lent full-text) (add 1 (lent ext-text)))
    [(crip (scag name-len full-text)) `u.dir-ext]
  =/  folder-path=path  (snoc (stab parent-path) dir-name)
  =/  new-ball=ball:tarball  [`[~ dir-neck ~] ~]
  ;<  ~  bind:m  (make:io /mkdir [%& %| folder-path] &+[*sand:nexus new-ball])
  =/  neck-msg=tape  ?~(dir-neck "" " (nexus: {(trip u.dir-neck)})")
  (pure:m [%text (crip "Created folder {(spud folder-path)}{neck-msg}")])
--
