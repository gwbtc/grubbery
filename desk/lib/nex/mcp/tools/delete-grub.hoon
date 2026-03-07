::  delete-grub: delete a grub (file) from the grubbery ball
::
!:
^-  tool:tools
|%
++  name  'delete_grub'
++  description  'Delete a grub (file) from the grubbery ball'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Directory containing the grub (e.g. "/mcp/tools")']]
      ['name' [%string 'Grub filename to delete']]
  ==
++  required  ~['path' 'name']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  file-path=@t  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  file-name=@t  (~(dog jo:json-utils [%o args.st]) /name so:dejs:format)
  ;<  ~  bind:m  (cull:io /delete [%& %& (stab file-path) file-name])
  (pure:m [%text (crip "Deleted {(trip file-path)}/{(trip file-name)}")])
--
