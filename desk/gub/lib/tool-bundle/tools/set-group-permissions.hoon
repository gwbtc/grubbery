/<  tools  /lib/tools.hoon
^-  tool:tools
=<
|%
++  name  'set_group_permissions'
++  description  'Set the roads the user opens to a usergroup (make/poke/peek, comma-separated paths; a path ending in / is a subtree). Replaces the user\'s own contribution; apps\' contributions are unaffected.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['group' [%string 'Group name as path (e.g. "/friends")']]
      ['make' [%string 'Comma-separated make roads']]
      ['poke' [%string 'Comma-separated poke roads']]
      ['peek' [%string 'Comma-separated peek roads']]
  ==
++  required  ~['group']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  grp  (~(get by args.st) 'group')
  ?.  ?=([~ %s *] grp)  (pure:m [%error 'Missing required argument: group'])
  =/  field
    |=  k=@t
    ^-  [@t json]
    =/  v  (~(get by args.st) k)
    [k ?.(?=([~ %s *] v) [%a ~] (str-list p.u.v))]
  =/  req=json
    (pairs:enjs:format ~[['group' s+p.u.grp] (field 'make') (field 'poke') (field 'peek')])
  ;<  ~  bind:m  (poke:io groups-sig [[/ %json] req])
  (pure:m [%text (crip "Set roads on {(trip p.u.grp)}")])
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
