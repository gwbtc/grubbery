/<  tools  /lib/tools.hoon
::  delete-usergroup: delete a usergroup
::
^-  tool:tools
=<
|%
++  name  'delete_usergroup'
++  description  'Delete a usergroup and all its data.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['group' [%string 'Group name as path (e.g. "/friends")']]
  ==
++  required  ~['group']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  name-parsed=(each @t tang)
    (mule |.((~(dog jo:json-utils [%o args.st]) /group so:dejs:format)))
  ?:  ?=(%| -.name-parsed)
    (pure:m [%error 'Missing required argument: group'])
  =/  grp=path  (stab p.name-parsed)
  =/  grp-dir=path  (grp-storage-path grp)
  ;<  *  bind:m  (cull-soft:io [%& %| grp-dir])
  ;<  ~  bind:m  (reg-poke:io [%gc ~])
  (pure:m [%text (crip "Deleted usergroup {(spud grp)}")])
--
|%
++  grp-storage-path
  |=  grp=path
  ^-  path
  ?~  grp  /sys/ames/usergroups
  %+  weld  /sys/ames/usergroups
  (snoc (snip `path`grp) (cat 3 (rear grp) '.grp'))
--
