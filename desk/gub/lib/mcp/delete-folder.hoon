/<  tools  /lib/nex/tools.hoon
::  delete-folder: delete a folder and all its contents
::
!:
^-  tool:tools
|%
++  name  'delete_folder'
++  description  'Delete a folder and all its contents from the grubbery ball'
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['path' [%string 'Path of the folder to delete (e.g. "/old/stuff")']]])
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each @t tang)
    (mule |.((~(dog jo:json-utils [%o args.st]) /path so:dejs:format)))
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid argument: path'])
  =/  folder-path=@t  p.parsed
  ;<  ~  bind:m  (cull:io /delete [%& %| (stab folder-path)])
  (pure:m [%text (crip "Deleted folder {(trip folder-path)}")])
--
