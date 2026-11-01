/<  tools  /lib/tools.hoon
^-  tool:tools
=<
|%
++  name  'set_group_members'
++  description  'Set the members of a usergroup in the user\'s section of the shell\'s record (apps\' own contributions are unaffected).'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['group' [%string 'Group name as path (e.g. "/friends")']]
      ['members' [%string 'Comma-separated ships (e.g. "~zod,~bus"); empty clears']]
  ==
++  required  ~['group' 'members']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  grp  (~(get by args.st) 'group')
  =/  mem  (~(get by args.st) 'members')
  ?.  &(?=([~ %s *] grp) ?=([~ %s *] mem))
    (pure:m [%error 'Missing required arguments: group, members'])
  =/  req=json  (pairs:enjs:format ~[['group' s+p.u.grp] ['members' (str-list p.u.mem)]])
  ;<  ~  bind:m  (poke:io groups-sig [[/ %json] req])
  (pure:m [%text (crip "Set members on {(trip p.u.grp)}")])
--
|%
::  every write to usergroups is a contribution poked at the shell's
::  groups.sig; from a tool under the shell it lands in the user's section
++  groups-sig  `road:tarball`[%& %& /apps/shell %'groups.sig']
++  split-comma
  |=  t=@t
  ^-  (list @t)
  =/  tape=(list @)  (trip t)
  =|  acc=(list @t)
  =|  cur=(list @)
  |-
  ?~  tape
    =/  s=@t  (crip (flop cur))
    (flop ?:(=('' s) acc [s acc]))
  ?:  =(i.tape ',')
    $(tape t.tape, acc [(crip (flop cur)) acc], cur ~)
  $(tape t.tape, cur [i.tape cur])
++  trim
  |=  t=tape
  ^-  tape
  |-
  ?~  t  ~
  ?.  =(i.t ' ')  t
  $(t t.t)
++  str-list
  |=  t=@t
  ^-  json
  a+(murn (split-comma t) |=(x=@t =/(c=tape (trim (trip x)) ?~(c ~ `s+(crip c)))))
--
