/<  tools  /lib/nex/tools.hoon
::  list-usergroups: show all usergroups with members and permissions
::
^-  tool:tools
|%
++  name  'list_usergroups'
++  description  'List all usergroups with their members and permissions (weir rules)'
++  parameters
  ^-  (map @t parameter-def:tools)
  ~
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  ug-seen=seen:nexus  bind:m  (peek:io [%& %| /sys/ames/usergroups] ~)
  =/  ug-ball=ball:tarball
    ?.  ?=([%& %ball *] ug-seen)  [~ ~]
    ball.p.ug-seen
  =/  names=(list @ta)  (sort ~(tap in ~(key by dir.ug-ball)) aor)
  =/  road-text
    |=  roads=(set road:tarball)
    ^-  tape
    ?:  =(~ roads)  "(none)"
    %+  roll  ~(tap in roads)
    |=  [r=road:tarball acc=tape]
    =/  t=tape
      ?-  -.r
        %&  ?-(-.p.r %& "{(spud path.p.p.r)}/{(trip name.p.p.r)}", %| (spud p.p.r))
        %|  ?-(-.q.p.r %& "{(spud path.p.q.p.r)}/{(trip name.p.q.p.r)}", %| (spud p.q.p.r))
      ==
    ?~  acc  t
    "{acc}, {t}"
  =/  out=wall
    %+  turn  names
    |=  name=@ta
    ^-  tape
    =/  grp=ball:tarball  (~(dip ba:tarball ug-ball) /[name])
    =/  who-c=(unit sang:tarball)  (~(get ba:tarball grp) [/ %'who.ships'])
    =/  how-c=(unit sang:tarball)  (~(get ba:tarball grp) [/ %'how.weir'])
    =/  members=(set @p)
      ?~  who-c  ~
      =/  res  (mule |.(!<((set @p) (need-vase:tarball u.who-c))))
      ?:(?=(%| -.res) ~ p.res)
    =/  =weir:nexus
      ?~  how-c  *weir:nexus
      =/  res  (mule |.(!<(weir:nexus (need-vase:tarball u.how-c))))
      ?:(?=(%| -.res) *weir:nexus p.res)
    =/  mem-text=tape
      ?:  =(~ members)  "(none)"
      %+  roll  ~(tap in members)
      |=  [s=@p acc=tape]
      ?~  acc  (trip (scot %p s))
      "{acc}, {(trip (scot %p s))}"
    ;:  weld
      "/{(trip name)}:\0a"
      "  members: {mem-text}\0a"
      "  make: {(road-text make.weir)}\0a"
      "  poke: {(road-text poke.weir)}\0a"
      "  peek: {(road-text peek.weir)}"
    ==
  ?~  out
    (pure:m [%text 'No usergroups found'])
  (pure:m [%text (crip (zing (join "\0a" out)))])
--
