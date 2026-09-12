::  lattice-mcp: shared helpers for the lattice knowledge-store MCP tools
::  (lib/mcp/lattice-*.hoon). The tools run inside the mcp nexus's fibers, so
::  every road here is ABSOLUTE (/apps/lattice.lattice_app/...) and writes poke
::  the lattice writer directly: in-ship, no HTTP hop, no session cookie,
::  nothing to go stale. Reads mirror the nexus's own vault walk. JSON shapes
::  are compact mirrors of the know-* HTTP responses.
/<  lk  /lib/lattice-know.hoon
|%
::  +base: where the lattice instance lives.
::
::    This moves with the release that makes lattice a stock desk, and it has to
::    move in the SAME release: once lattice's code leaves the ball, the old
::    instance at /apps/lattice.lattice_app keeps its data but loses its marks,
::    so every typed grub there reads as a boom. +walk skips booms, which means
::    pointing at the old path after the move reports an EMPTY vault rather than
::    an error - memory that answers "nothing remembered", forever, quietly.
::
::    Between the release landing and the user granting the new instance's
::    roads, this path has no data yet and the tools report an empty vault for
::    the same reason. That window is the upgrade prompt's length and is
::    accepted; the permanent version of it is not.
++  base
  `path`/apps/'shell.shell'/desks/'lattice.desk'/desk/data/'lattice.lattice_app'
::  +read-vault: every live knowledge entry, keyed by its path-like key.
::
++  read-vault
  =/  m  (fiber:fiber:nexus ,(map path know-entry:lk))
  ^-  form:m
  ;<  seen=view:nexus  bind:m  (peek:io [%& %| (weld base /know/vault)] ~)
  ?.  ?=([%ball *] seen)  (pure:m ~)
  (pure:m (walk ~ ball.seen))
::  +walk: collect entry leaves under each key-directory (booms skipped).
::
++  walk
  |=  [at=path b=ball:tarball]
  ^-  (map path know-entry:lk)
  =/  acc=(map path know-entry:lk)
    ?~  fil.b  ~
    =/  got  (~(get by contents.u.fil.b) entry-leaf:lk)
    ?~  got  ~
    ?:  (is-boom:tarball sang.u.got)  ~
    =/  res  (mule |.(!<(know-entry:lk (need-vase:tarball sang.u.got))))
    ?:  ?=(%| -.res)  ~
    (my [at p.res] ~)
  =/  kids=(list [seg=@ta kid=ball:tarball])  ~(tap by dir.b)
  |-
  ?~  kids  acc
  =.  acc  (~(uni by acc) (walk (snoc at seg.i.kids) kid.i.kids))
  $(kids t.kids)
::  +poke-writer: one serialized mutation through lattice's action writer,
::  the same path every other lattice client takes, so index maintenance and
::  the change beacon fire identically.
::
++  poke-writer
  |=  act=know-action:lk
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (poke:io [%& %& base %'main.sig'] [[/lattice %know-action] act])
::  +parse-key: 'user/ai-models' -> /user/ai-models. Rejects the empty key.
::
++  parse-key
  |=  k=@t
  ^-  (unit path)
  =/  t=tape  (trip k)
  =/  full=tape  ?:(?=([%'/' *] t) t ['/' t])
  =/  res  (mule |.((stab (crip full))))
  ?:(?=(%& -.res) ?~(p.res ~ `p.res) ~)
::  +arg: one required string argument out of a tool's args. ~ when it is
::  absent or not a string. The mule guard is what turns a wrong-typed
::  argument into a tool %error instead of a crashed fiber, so every tool
::  draws it from here rather than carrying its own copy of the prologue.
::
++  arg
  |=  [args=(map @t json) pax=path]
  ^-  (unit @t)
  =/  res=(each @t tang)
    %-  mule  |.
    (~(dog jo:json-utils [%o args]) pax so:dejs:format)
  ?:(?=(%| -.res) ~ `p.res)
::  +low: case-fold a cord for substring matching.
::
++  low  |=(t=@t (crip (cass (trip t))))
::  +has-sub: case-insensitive substring test.
::
++  has-sub
  |=  [needle=@t hay=@t]
  ^-  ?
  ?~((find (cass (trip needle)) (cass (trip hay))) | &)
::  ── JSON renderers ──
::
++  tags-json
  |=  tags=(set @t)
  ^-  [@t json]
  ['tags' %a (turn ~(tap in tags) |=(t=@t s+t))]
++  list-json
  |=  es=(map path know-entry:lk)
  ^-  json
  %-  pairs:enjs:format
  :~  ['count' (numb:enjs:format ~(wyt by es))]
      :-  'keys'
      :-  %a
      %+  turn  ~(tap by es)
      |=  [kp=path e=know-entry:lk]
      %-  pairs:enjs:format
      :~  ['key' s+(spat kp)]
          ['updated' s+(scot %da updated.e)]
          ['bytes' (numb:enjs:format (met 3 body.e))]
          (tags-json tags.e)
      ==
  ==
++  entry-json
  |=  [kp=path e=know-entry:lk]
  ^-  json
  %-  pairs:enjs:format
  :~  ['key' s+(spat kp)]
      ['body' s+body.e]
      ['updated' s+(scot %da updated.e)]
      (tags-json tags.e)
  ==
--
