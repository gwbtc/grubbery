/<  tools  /lib/nex/tools.hoon
::  set-group-permissions: set weir permissions on a usergroup
::
^-  tool:tools
=<
|%
++  name  'set_group_permissions'
++  description  'Set make/poke/peek permissions on a usergroup. Each is a comma-separated list of paths. Replaces existing permissions.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['group' [%string 'Group name as path (e.g. "/friends")']]
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
  =/  grp-dir=path  (grp-storage-path grp)
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
    =/  clean=tape  (trim (trip t))
    ?~  clean  ~
    =/  pax=path  (fall (rush (crip clean) stap) ~)
    ?~  pax  ~
    `[%& %| pax]
  =/  =weir:nexus
    [(parse-roads 'make') (parse-roads 'poke') (parse-roads 'peek')]
  ;<  ~  bind:m  (over:io [%& %& grp-dir %'how.weir'] [[/ %weir] weir])
  ;<  ~  bind:m  (reg-poke:io [%gc ~])
  (pure:m [%text (crip "Set permissions on {(spud grp)}")])
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
