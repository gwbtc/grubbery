/<  tools  /lib/nex/tools.hoon
::  list-usergroups: show all usergroups with members and permissions
::
^-  tool:tools
=<
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
  ;<  ug-view=view:nexus  bind:m  (peek:io [%& %| /sys/ames/usergroups] ~)
  =/  ug-ball=ball:tarball
    ?.  ?=([%ball *] ug-view)  [~ ~]
    ball.ug-view
  =/  groups=(list [name=path grp=ball:tarball])  (find-groups / ug-ball)
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
    %+  turn  groups
    |=  [name=path grp=ball:tarball]
    ^-  tape
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
      "{(spud name)}:\0a"
      "  members: {mem-text}\0a"
      "  make: {(road-text make.weir)}\0a"
      "  poke: {(road-text poke.weir)}\0a"
      "  peek: {(road-text peek.weir)}"
    ==
  ?~  out
    (pure:m [%text 'No usergroups found'])
  (pure:m [%text (crip (zing (join "\0a" out)))])
--
|%
++  is-grp-name
  |=  name=@ta
  ^-  ?
  =/  t=tape  (trip name)
  =/  len=@ud  (lent t)
  ?&  (gte len 5)
      =(".grp" (slag (sub len 4) t))
  ==
::
++  strip-grp-suffix
  |=  name=@ta
  ^-  @ta
  =/  t=tape  (trip name)
  (crip (scag (sub (lent t) 4) t))
::
++  find-groups
  |=  [pax=path ug=ball:tarball]
  ^-  (list [name=path grp=ball:tarball])
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.ug)
  =|  acc=(list [name=path grp=ball:tarball])
  |-
  ?~  kids  acc
  =/  [kid-name=@ta kid=ball:tarball]  i.kids
  ?:  (is-grp-name kid-name)
    $(kids t.kids, acc [[(snoc pax (strip-grp-suffix kid-name)) kid] acc])
  $(kids t.kids, acc (weld acc ^$(pax (snoc pax kid-name), ug kid)))
--
