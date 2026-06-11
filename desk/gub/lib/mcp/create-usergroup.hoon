/<  tools  /lib/nex/tools.hoon
::  create-usergroup: create a new usergroup with optional members and permissions
::
^-  tool:tools
=<
|%
++  name  'create_usergroup'
++  description  'Create a new usergroup. Name is a path like /friends. Optionally set members (comma-separated ~ships) and permissions (comma-separated paths for make/poke/peek).'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['group' [%string 'Group name as path (e.g. "/friends", "/dev/core")']]
      ['members' [%string 'Comma-separated ships (e.g. "~zod,~bus")']]
      ['make' [%string 'Comma-separated make permission paths (e.g. "/,/apps")']]
      ['poke' [%string 'Comma-separated poke permission paths']]
      ['peek' [%string 'Comma-separated peek permission paths']]
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
  =/  grp-dir=path  (weld /sys/ames/usergroups grp)
  =/  members=(set @p)
    =/  raw  (~(get jo:json-utils [%o args.st]) /members)
    ?~  raw  ~
    ?.  ?=([%s *] u.raw)  ~
    %-  ~(gas in *(set @p))
    (murn (split-comma p.u.raw) |=(t=@t (slaw %p (crip (trim (trip t))))))
  =/  =weir:nexus
    =/  parse-roads
      |=  key=@t
      ^-  (set road:tarball)
      =/  raw  (~(get jo:json-utils [%o args.st]) /[key])
      ?~  raw  ~
      ?.  ?=([%s *] u.raw)  ~
      %-  ~(gas in *(set road:tarball))
      %+  murn  (split-comma p.u.raw)
      |=  t=@t
      ^-  (unit road:tarball)
      =/  pax=path  (fall (rush (crip (trim (trip t))) stap) ~)
      ?~  pax  ~
      `[%& %| pax]
    [(parse-roads 'make') (parse-roads 'poke') (parse-roads 'peek')]
  =/  who-road=road:tarball  [%& %& grp-dir %'who.ships']
  =/  how-road=road:tarball  [%& %& grp-dir %'how.weir']
  ;<  ~  bind:m  (make:io who-road |+[[[/ %ships] members] ~])
  ;<  ~  bind:m  (make:io how-road |+[[[/ %weir] weir] ~])
  (pure:m [%text (crip "Created usergroup {(spud grp)} with {(a-co:co ~(wyt in members))} members")])
--
|%
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
--
