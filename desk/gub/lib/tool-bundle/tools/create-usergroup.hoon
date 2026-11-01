/<  tools  /lib/tools.hoon
^-  tool:tools
=<
|%
++  name  'create_usergroup'
++  description  'Create a usergroup (declare its name in the user\'s section of the shell\'s record). Name is a path like /friends. Optionally set members (comma-separated ~ships) and roads (comma-separated paths for make/poke/peek).'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['group' [%string 'Group name as path (e.g. "/friends", "/dev/core")']]
      ['members' [%string 'Comma-separated ships (e.g. "~zod,~bus")']]
      ['make' [%string 'Comma-separated make roads (e.g. "/apps/x/,/apps/y/file.json")']]
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
  =/  g=@t  p.u.grp
  =/  field
    |=  k=@t
    ^-  (list [@t json])
    =/  v  (~(get by args.st) k)
    ?.  ?=([~ %s *] v)  ~
    [k (str-list p.u.v)]~
  =/  req=json
    %-  pairs:enjs:format
    ;:  weld
      ['group' s+g]~
      (field 'members')
      (field 'make')
      (field 'poke')
      (field 'peek')
    ==
  ;<  ~  bind:m  (poke:io groups-sig [[/ %json] req])
  (pure:m [%text (crip "Declared usergroup {(trip g)}")])
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
