/<  tools  /lib/tools.hoon
::  move-folder: move/rename a folder in the grubbery ball
::
!:
^-  tool:tools
|%
++  name  'move_folder'
++  description  'Move or rename a folder in the grubbery ball'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['from' [%string 'Source folder path (e.g. "/apps/old.desk")']]
      ['to' [%string 'Destination folder path (e.g. "/apps/shell.shell/desks/old.desk")']]
  ==
++  required  ~['from' 'to']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  pf=(each @t tang)
    (mule |.((~(dog jo:json-utils [%o args.st]) /from so:dejs:format)))
  ?:  ?=(%| -.pf)
    (pure:m [%error 'Missing or invalid argument: from'])
  =/  pt=(each @t tang)
    (mule |.((~(dog jo:json-utils [%o args.st]) /to so:dejs:format)))
  ?:  ?=(%| -.pt)
    (pure:m [%error 'Missing or invalid argument: to'])
  =/  src=road:tarball  [%& %| (stab p.pf)]
  =/  dst=road:tarball  [%& %| (stab p.pt)]
  ;<  ~  bind:m  (move-fold:io src dst)
  (pure:m [%text (crip "Moved {(trip p.pf)} -> {(trip p.pt)}")])
--
