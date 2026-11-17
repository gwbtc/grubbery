::  lib/shell/contacts: the people record, a service of the shell.
::
::  Three directories. profiles: what a ship publishes, as this ship last
::  read it. overlays: yours alone, the name you call them, labels, notes.
::  Both hold one file per ship, named without the sig. share: what YOU
::  publish, a facet per usergroup — /friends sees one profile, /public
::  another. Apps find all of it by NAME: /sys/link/contacts points at the
::  shell's /contacts directory.
::
::    <shell>/contacts/main.sig                 pokes: set / del / facet / pull
::    <shell>/contacts/profiles/<ship>.json     as that ship publishes it
::    <shell>/contacts/overlays/<ship>.json     your overlay on that ship
::    <shell>/contacts/share/<group>/profile.json   your facet for that group
::    <shell>/ui/contacts/*                     the page, at /grubbery/contacts
::    GET /grubbery/contacts/api/{overlays,profiles,facets}   each as one object
::
::  There is no file for your own ship under profiles/: your profile is not
::  something you read back, it is something you serve.
::
::  A facet is published by the WEIR, not by a send: the shell contributes
::  a peek road on share/<group>/profile.json to that group's weir (see
::  +gather-groups in nex/shell.hoon), so a ship in the group can peek the
::  file and no other ship can. A reader in two of your groups peeks both
::  and sees the union; that is what +pull does on the reading side.
::
::  Every road below is relative to the serving grub, so the service
::  reads and writes only its own directory wherever the shell lives, and
::  a facet is a file like any other.
::
|%
::  +serve: the main.sig loop. Takes pokes forever; a malformed poke is
::  skipped, never fatal.
::
::    {"action": "set", "ship": "~zod", "overlay": {...}}
::      your overlay on that ship, replaced whole
::    {"action": "del", "ship": "~zod"}
::      your overlay on that ship and its profile both go
::    {"action": "facet", "group": "/friends", "profile": {...}}
::      the profile this ship publishes to that usergroup, replaced whole
::    {"action": "facet", "group": "/friends", "remove": true}
::      that facet goes, and the group stops being told anything
::    {"action": "pull", "ship": "~zod", "groups": ["/public", "/friends"]}
::      read that ship's facets for those groups (its own group names, the
::      ones it told you about) and keep the union as its profile. A group
::      you are not in simply answers nothing. `groups` defaults to
::      ["/public"].
::    {"action": "sync-ames"}
::      every ship ames knows that has no overlay yet gets one, marked
::      {"source": "ames"}. Only on request, never at start, and only
::      the ships not already here: a ship with thousands of peers
::      writes each once and never again.
::
++  serve
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ;<  [* =sage:tarball]  bind:m  take-poke-from:io
  ::  the start's kick and any other non-json poke are nobody's action
  ?.  =([/ %json] p.sage)  $
  =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
  ?.  ?=([%o *] jon)  $
  =/  act=@t  (gs jon 'action')
  ?:  =('set' act)
    =/  who=(unit @p)  (slaw %p (gs jon 'ship'))
    ?~  who  $
    ;<  ~  bind:m  (write (ship-file /overlays u.who) (gj jon 'overlay'))
    $
  ?:  =('del' act)
    =/  who=(unit @p)  (slaw %p (gs jon 'ship'))
    ?~  who  $
    ;<  *  bind:m  (cull-soft:io (ship-file /overlays u.who))
    ;<  *  bind:m  (cull-soft:io (ship-file /profiles u.who))
    $
  ?:  =('facet' act)
    =/  grp=(unit path)  (rush (gs jon 'group') stap)
    ?:  |(?=(~ grp) ?=(~ u.grp))  $
    ?:  =(`[%b %.y] (~(get by p.jon) 'remove'))
      ;<  *  bind:m  (cull-soft:io (facet-file u.grp))
      ;<  *  bind:m  (cull-soft:io [%| 0 [%| (weld /share u.grp)]])
      $
    ;<  ~  bind:m  (ensure-fold:io [%| 0 [%| /share]] (facet-fold u.grp))
    ;<  ~  bind:m  (write (facet-file u.grp) (gj jon 'profile'))
    $
  ?:  =('pull' act)
    =/  who=(unit @p)  (slaw %p (gs jon 'ship'))
    ?~  who  $
    =/  groups=(list path)
      =/  v  (~(get by p.jon) 'groups')
      =/  asked=(list path)
        ?.  ?=([~ %a *] v)  ~
        %+  murn  p.u.v
        |=(j=json ?.(?=([%s *] j) ~ (rush p.j stap)))
      ?~(asked ~[/public] asked)
    ;<  *  bind:m  ((with-timeout:io ,~) /pull ~s45 (pull u.who groups))
    $
  ?:  =('sync-ames' act)
    ;<  ~  bind:m  sync-ames
    $
  $
::  +sync-ames: the ships ames knows, as overlays, for those not here yet
::
++  sync-ames
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ;<  peers=(map ship ?(%alien %known))  bind:m
    (typed-scry:io (map ship ?(%alien %known)) %ames-peers /ax//peers)
  ;<  have=(list [who=@p doc=json])  bind:m  (read-dir [%| 0 [%| /overlays]])
  =/  had=(set @p)  (silt (turn have |=([who=@p *] who)))
  =/  new=(list @p)
    %+  murn  ~(tap by peers)
    |=  [who=@p val=?(%alien %known)]
    ?:  |(=(who our) ?=(%alien val) (~(has in had) who))  ~
    `who
  |-  ^-  form:m
  ?~  new  (pure:m ~)
  ;<  ~  bind:m
    (write (ship-file /overlays i.new) (pairs:enjs:format ~[['source' s+'ames']]))
  $(new t.new)
::  +read-dir: every ship's json in one of the two directories
::
++  read-dir
  |=  =road:tarball
  =/  m  (fiber:fiber:nexus ,(list [who=@p doc=json]))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  =/  =lump:tarball  (fall fil.ball.view *lump:tarball)
  %-  pure:m
  %+  murn  ~(tap by contents.lump)
  |=  [name=@ta =sang:tarball gain=? bang=(unit tang)]
  ^-  (unit [@p json])
  =/  stem=tape  (trip name)
  =/  len=@ud  (lent stem)
  ?.  &((gth len 5) =(".json" (slag (sub len 5) stem)))  ~
  =/  who=(unit @p)  (slaw %p (crip ['~' (scag (sub len 5) stem)]))
  ?~  who  ~
  =/  doc=(unit json)  (mole |.(!<(json (need-vase:tarball sang))))
  ?~  doc  ~
  `[u.who u.doc]
::  +ship-file: a ship's file in one of the two directories, the ship
::  without its sig
::
++  ship-file
  |=  [dir=path who=@p]
  ^-  road:tarball
  [%| 0 [%& dir (rap 3 (rsh [3 1] (scot %p who)) '.json' ~)]]
::  +facet-file: where the facet for one usergroup lives. The group path
::  IS the directory path, so /guestbook/readers nests the same way it
::  does in the registry, and /public needs no special case.
::
++  facet-file
  |=  grp=path
  ^-  road:tarball
  [%| 0 [%& (weld /share grp) %'profile.json']]
::  +facet-fold: the directories one group's facet needs under /share,
::  for +ensure-fold (which leaves the facets already there alone).
::
++  facet-fold
  |=  grp=path
  ^-  bole:tarball
  (put-bole:loader empty-dir:loader grp empty-dir:loader)
::  +facet-list: every facet under a /share directory, group path and the
::  profile published to it. Both the page (its own directory) and the
::  group derivation (the shell's, to grant a peek per facet) read this.
::
++  facet-list
  |=  =road:tarball
  =/  m  (fiber:fiber:nexus ,(list [grp=path prof=json]))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  (pure:m (facets-in ball.view))
::  +facets-in: the facets in a share tree, by group path. Every file in
::  the ball carries its rail, and a profile.json's path from the share
::  root IS the group it is published to, however deep it nests.
::
++  facets-in
  |=  bal=ball:tarball
  ^-  (list [grp=path prof=json])
  %+  murn  ~(tap ba:tarball bal)
  |=  [=rail:tarball =sang:tarball]
  ^-  (unit [grp=path prof=json])
  ?.  =(%'profile.json' name.rail)  ~
  ?~  path.rail  ~
  ?:  (is-boom:tarball sang)  ~
  =/  res=(each json tang)  (mule |.(!<(json (need-vase:tarball sang))))
  ?.  ?=(%& -.res)  ~
  ?.  ?=([%o *] p.res)  ~
  `[path.rail p.res]
::  +pull: read a ship's facets for the groups it told you it has you in,
::  and keep the union as its profile. Each road is absolute and remote:
::  the file sits in that ship's shell, and its group's weir decides
::  whether we may read it — a group we are not in answers %veto, which
::  is not an error here, just silence. '_from' records which groups
::  answered, so the page can show what this profile is made of.
::
++  pull
  |=  [who=@p groups=(list path)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  WITH the sig: /sys/ames/ships/~zod/root/..., the spelling +slav reads
  ::  (the file names under profiles/ drop it, the roads never do)
  =/  s=@ta  (scot %p who)
  =|  got=(list [grp=path prof=json])
  |-  ^-  form:m
  ?^  groups
    ;<  =view:nexus  bind:m  (peek:io (peer-facet s i.groups) ~)
    =/  prof=(unit json)
      ?.  ?=([%file *] view)  ~
      ?:  (is-boom:tarball sang.view)  ~
      =/  res=(each json tang)  (mule |.(!<(json (need-vase:tarball sang.view))))
      ?.  ?=(%& -.res)  ~
      ?.(?=([%o *] p.res) ~ `p.res)
    $(groups t.groups, got ?~(prof got (snoc got [i.groups u.prof])))
  ?~  got  (pure:m ~)
  ::  +roll and +turn walk their list to ~, so they take the list, not
  ::  the non-empty type the ?~ above narrowed it to
  =/  read=(list [grp=path prof=json])  got
  =/  union=(map @t json)
    %+  roll  read
    |=  [[* prof=json] acc=(map @t json)]
    ?.  ?=([%o *] prof)  acc
    (~(uni by acc) p.prof)
  =/  from=json  a+(turn read |=([grp=path *] s+(spat grp)))
  (write (ship-file /profiles who) [%o (~(put by union) '_from' from)])
::  +peer-facet: another ship's facet for one of ITS groups. The shell's
::  own place, like the storefront road in nex/shell.hoon.
::
++  peer-facet
  |=  [s=@ta grp=path]
  ^-  road:tarball
  :+  %&  %&
  :-  (weld /sys/ames/ships/[s]/root/apps/shell/contacts/share grp)
  %'profile.json'
::  +write: one json file, made or replaced. Anything but an object is
::  written as an empty one.
::
++  write
  |=  [=road:tarball doc=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (put:io road [[/ %json] ?:(?=([%o *] doc) doc [%o ~])])
::  +serve-page: one request under /grubbery/contacts: a file of the page
::  (ui/contacts/<name>), the index by default. Owner only. The page
::  reads and writes through the kernel's namespace api itself.
::
++  serve-page
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  eyre-id=@ta  name.rail
  ;<  [src=@p req=inbound-request:eyre]  bind:m
    (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)
    ;<  ~  bind:m  (send-simple:http-res:io eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
    (pure:m ~)
  =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
  =/  suffix=path
    %+  skip  (slag (lent `path`/grubbery/contacts) site)
    |=(seg=@ta =('' seg))
  ::  /api/overlays and /api/profiles: one object, every ship's file
  ::  under its name with the sig, which is how an app spells a ship
  ?:  ?=([%api ?(%overlays %profiles) ~] suffix)
    =/  dir=path  ?:(?=(%overlays i.t.suffix) /overlays /profiles)
    ;<  rows=(list [who=@p doc=json])  bind:m
      (read-dir (nex-road:io rail [%| (weld /contacts dir)]))
    =/  out=json  [%o (malt (turn rows |=([who=@p doc=json] [`@t`(scot %p who) doc])))]
    ;<  ~  bind:m
      %+  send-simple:http-res:io  eyre-id
      [[200 ~[['content-type' 'application/json']]] `(as-octs:mimes:html (en:json:html out))]
    (pure:m ~)
  ::  /api/facets: every facet of our own profile, by the group it is
  ::  published to. The page's editor reads this
  ?:  ?=([%api %facets ~] suffix)
    ;<  rows=(list [grp=path prof=json])  bind:m
      (facet-list (nex-road:io rail [%| /contacts/share]))
    =/  out=json  [%o (malt (turn rows |=([grp=path prof=json] [(spat grp) prof])))]
    ;<  ~  bind:m
      %+  send-simple:http-res:io  eyre-id
      [[200 ~[['content-type' 'application/json']]] `(as-octs:mimes:html (en:json:html out))]
    (pure:m ~)
  =/  filename=@ta
    ?~  suffix  'index.html'
    i.suffix
  ;<  file-view=view:nexus  bind:m
    (peek:io (nex-road:io rail [%& /ui/contacts filename]) `[/ %mime])
  ?.  ?=([%file *] file-view)
    ;<  ~  bind:m  (send-simple:http-res:io eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
    (pure:m ~)
  =/  =mime  !<(mime (need-vase:tarball sang.file-view))
  ;<  ~  bind:m  (send-simple:http-res:io eyre-id (mime-response:http-utils mime))
  (pure:m ~)
++  gs
  |=  [jon=json k=@t]
  ^-  @t
  =/  v=json  (gj jon k)
  ?:(?=([%s *] v) p.v '')
++  gj
  |=  [jon=json k=@t]
  ^-  json
  ?.  ?=([%o *] jon)  ~
  (fall (~(get by p.jon) k) ~)
--
