/<  tools  /lib/tools.hoon
::  set-group-members: set the members of a usergroup
::
^-  tool:tools
=<
|%
++  name  'set_group_members'
++  description  'Set the members of a usergroup. Replaces existing members.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['group' [%string 'Group name as path (e.g. "/friends")']]
      ['members' [%string 'Comma-separated ships (e.g. "~zod,~bus")']]
  ==
++  required  ~['group' 'members']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each [@t @t] tang)
    %-  mule  |.
    :-  (~(dog jo:json-utils [%o args.st]) /group so:dejs:format)
    (~(dog jo:json-utils [%o args.st]) /members so:dejs:format)
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing required arguments: group, members'])
  =/  [name=@t mem-text=@t]  p.parsed
  =/  grp=path  (stab name)
  =/  grp-dir=path  (grp-storage-path grp)
  =/  members=(set @p)
    %-  ~(gas in *(set @p))
    %+  murn  (split-comma mem-text)
    |=  t=@t
    (slaw %p (crip (trim (trip t))))
  ;<  ~  bind:m  (over:io [%& %& grp-dir %'who.ships'] [[/ %ships] members])
  ;<  ~  bind:m  (reg-poke:io [%gc ~])
  (pure:m [%text (crip "Set {(a-co:co ~(wyt in members))} members on {(spud grp)}")])
--
|%
++  split-comma
  |=  t=@t
  ^-  (list @t)
  =/  tape=(list @)  (trip t)
  =|  acc=(list @t)
  =|  cur=(list @)
  |-
  ?~  tape  (flop [(crip (flop cur)) acc])
  ?:  =(i.tape ',')
    $(tape t.tape, acc [(crip (flop cur)) acc], cur ~)
  $(tape t.tape, cur [i.tape cur])
++  grp-storage-path
  |=  grp=path
  ^-  path
  ?~  grp  /sys/ames/usergroups
  %+  weld  /sys/ames/usergroups
  (snoc (snip `path`grp) (cat 3 (rear grp) '.grp'))
::
++  trim
  |=  t=tape
  ^-  tape
  |-
  ?~  t  ~
  ?.  =(i.t ' ')  t
  $(t t.t)
--
