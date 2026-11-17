::  lib/shell/contacts: the people record, a service of the shell.
::
::  Three directories, two of them the same shape. share: what YOU
::  publish, a facet per usergroup — /friends sees one profile, /public
::  another. profiles: what other ships publish, as read, kept the same
::  way — a directory per ship holding a file per group of THEIRS, so what
::  they told each group stays apart and two of their groups disagreeing
::  is something you can see. overlays: yours alone, the name you call
::  them, labels, notes; one file per ship. Apps find all of it by NAME:
::  /sys/link/contacts points at the shell's /contacts directory.
::
::    <shell>/contacts/main.sig                 pokes: set / del / facet / pull
::    <shell>/contacts/profiles/<ship>/<group>/profile.json
::                                              what that group of theirs
::                                              was told, as we read it
::    <shell>/contacts/overlays/<ship>.json     your overlay on that ship
::    <shell>/contacts/share/<group>/profile.json   your facet for that group
::    <shell>/ui/contacts/*                     the page, at /grubbery/contacts
::    GET /grubbery/contacts/api/overlays   yours on them, by ship
::    GET /grubbery/contacts/api/profiles   their facets unioned, by ship
::    GET /grubbery/contacts/api/peers      their facets apart, + clashes
::    GET /grubbery/contacts/api/facets     your own, by group
::
::  There is no file for your own ship under profiles/: your profile is not
::  something you read back, it is something you serve.
::
::  A facet is published by the WEIR, not by a send: the shell contributes
::  a peek road on share/<group>/profile.json to that group's weir (see
::  +gather-groups in nex/shell.hoon), so a ship in the group can peek the
::  file and no other ship can. A reader in two of your groups peeks both,
::  keeps both (+pull), and unions them only when something asks.
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
::      ones it told you about) and keep each one under the group that
::      told it. A group you are not in answers %veto: whatever we held
::      for it is dropped. `groups` defaults to ["/public"].
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
    ;<  *  bind:m  (cull-soft:io (peer-dir u.who))
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
::  and keep each one AS ITS OWN FILE, under that group's name. The stored
::  tree mirrors the published tree: profiles/<ship>/<group>/profile.json
::  is what that group of theirs was told, as we read it.
::
::  Kept apart rather than merged because the disagreement is the
::  interesting part: a key with one value in /public and another in
::  /friends is a thing you want to SEE, with both groups named, and a
::  merge throws that evidence away. The union is a view (+union-of),
::  computed when something asks.
::
::  A group we are not in answers %veto, and a facet we used to be able to
::  read and now cannot is dropped — so a group that stopped telling us
::  stops being something we claim to know. Any other non-answer (an
::  unreachable ship) leaves what we have alone.
::
++  pull
  |=  [who=@p groups=(list path)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  WITH the sig: /sys/ames/ships/~zod/root/..., the spelling +slav reads
  ::  (only the directory name under profiles/ drops it)
  =/  s=@ta  (scot %p who)
  |-  ^-  form:m
  ?~  groups  (pure:m ~)
  ;<  =view:nexus  bind:m  (peek:io (peer-facet s i.groups) ~)
  =/  prof=(unit json)
    ?.  ?=([%file *] view)  ~
    ?:  (is-boom:tarball sang.view)  ~
    =/  res=(each json tang)  (mule |.(!<(json (need-vase:tarball sang.view))))
    ?.  ?=(%& -.res)  ~
    ?.(?=([%o *] p.res) ~ `p.res)
  ?^  prof
    ;<  ~  bind:m
      (ensure-fold:io [%| 0 [%| /profiles]] (peer-fold who i.groups))
    ;<  ~  bind:m  (write (peer-file who i.groups) u.prof)
    $(groups t.groups)
  ?.  ?=([%veto *] view)  $(groups t.groups)
  ::  the group dir goes with the file: an empty directory under their
  ::  name says we know a group of theirs, and a refusal says we do not
  ;<  *  bind:m  (cull-soft:io (peer-file who i.groups))
  ;<  *  bind:m  (cull-soft:io (peer-group-dir who i.groups))
  $(groups t.groups)
::  +peer-name: a ship as a directory name, without its sig
::
++  peer-name
  |=  who=@p
  ^-  @ta
  (rsh [3 1] (scot %p who))
::  +peer-dir: everything we have read from one ship
::
++  peer-dir
  |=  who=@p
  ^-  road:tarball
  [%| 0 [%| (snoc `path`/profiles (peer-name who))]]
::  +peer-file: one group's facet of one ship, as we read it
::
++  peer-file
  |=  [who=@p grp=path]
  ^-  road:tarball
  [%| 0 [%& (weld (snoc `path`/profiles (peer-name who)) grp) %'profile.json']]
::  +peer-group-dir: the directory one of their groups' facet sits in
::
++  peer-group-dir
  |=  [who=@p grp=path]
  ^-  road:tarball
  [%| 0 [%| (weld (snoc `path`/profiles (peer-name who)) grp)]]
::  +peer-fold: the directories that file needs under /profiles
::
++  peer-fold
  |=  [who=@p grp=path]
  ^-  bole:tarball
  (put-bole:loader empty-dir:loader [(peer-name who) grp] empty-dir:loader)
::  +peer-rows: every facet we hold of every ship, as [ship, their group,
::  profile]. One peek: a rail's path under /profiles is <ship>/<group>,
::  so the walk that reads our own facets reads these too.
::
++  peer-rows
  |=  =road:tarball
  =/  m  (fiber:fiber:nexus ,(list [who=@t grp=path prof=json]))
  ^-  form:m
  ;<  rows=(list [grp=path prof=json])  bind:m  (facet-list road)
  %-  pure:m
  %+  murn  rows
  |=  [pax=path prof=json]
  ^-  (unit [@t path json])
  ?~  pax  ~
  =/  who=(unit @p)  (slaw %p (crip ['~' (trip i.pax)]))
  ?~  who  ~
  `[(scot %p u.who) t.pax prof]
::  +union-of: the facets of one ship as a single profile. A reader in two
::  of their groups sees both, so this is simply everything they told us.
::  Where two of their groups disagree it keeps ONE, arbitrarily — there
::  is no truth to pick and no order that means anything. That is what
::  +clashes is for: the disagreement is the finding, not a tie to break.
::
++  union-of
  |=  rows=(list [grp=path prof=json])
  ^-  json
  :-  %o
  %+  roll  rows
  |=  [[* prof=json] acc=(map @t json)]
  ?.  ?=([%o *] prof)  acc
  (~(uni by acc) p.prof)
::  +clashes: the keys their groups were told different things about,
::  each with the value per group — {key: {group: value}}. Empty when a
::  ship told every group the same story.
::
++  clashes
  |=  rows=(list [grp=path prof=json])
  ^-  json
  =/  by-key=(map @t (map @t json))
    %+  roll  rows
    |=  [[grp=path prof=json] acc=(map @t (map @t json))]
    ?.  ?=([%o *] prof)  acc
    %+  roll  ~(tap by p.prof)
    |=  [[k=@t v=json] a=_acc]
    (~(put by a) k (~(put by (~(gut by a) k *(map @t json))) (spat grp) v))
  :-  %o
  %-  malt
  %+  murn  ~(tap by by-key)
  |=  [k=@t per=(map @t json)]
  ^-  (unit [@t json])
  ?:  (lth ~(wyt in (silt ~(val by per))) 2)  ~
  `[k [%o per]]
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
  ::  /api/overlays: one object, every ship's overlay under its name with
  ::  the sig, which is how an app spells a ship
  ?:  ?=([%api %overlays ~] suffix)
    ;<  rows=(list [who=@p doc=json])  bind:m
      (read-dir (nex-road:io rail [%| /contacts/overlays]))
    =/  out=json  [%o (malt (turn rows |=([who=@p doc=json] [`@t`(scot %p who) doc])))]
    ;<  ~  bind:m
      %+  send-simple:http-res:io  eyre-id
      [[200 ~[['content-type' 'application/json']]] `(as-octs:mimes:html (en:json:html out))]
    (pure:m ~)
  ::  /api/profiles: a ship's facets as one profile — the union, which is
  ::  what an app asking "who is this" wants. /api/peers is the honest
  ::  version, with the facets kept apart.
  ?:  ?=([%api ?(%profiles %peers) ~] suffix)
    =/  deep=?  ?=(%peers i.t.suffix)
    ;<  rows=(list [who=@t grp=path prof=json])  bind:m
      (peer-rows (nex-road:io rail [%| /contacts/profiles]))
    =/  per=(jar @t [grp=path prof=json])
      %+  roll  rows
      |=  [[who=@t grp=path prof=json] a=(jar @t [grp=path prof=json])]
      (~(add ja a) who [grp prof])
    =/  out=json
      :-  %o
      %-  ~(run by `(map @t (list [grp=path prof=json]))`per)
      |=  fs=(list [grp=path prof=json])
      ^-  json
      ?.  deep  (union-of fs)
      %-  pairs:enjs:format
      :~  ['profile' (union-of fs)]
          ['facets' [%o (malt (turn fs |=([grp=path prof=json] [(spat grp) prof])))]]
          ['clashes' (clashes fs)]
      ==
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
