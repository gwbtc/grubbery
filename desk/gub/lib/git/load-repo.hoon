::  /lib/git/load-repo: rebuild an in-memory git `repository` from a repo's
::  /data files in the namespace, so a nexus other than git/repo (e.g. forge's
::  docs feature, CI) can load a repo and read blobs at arbitrary commits via
::  blob-at-commit:repository. Lifted from nex/git/repo.hoon's +load-repo-maybe
::  and helpers, but taking the repo's /data path as a parameter (the original
::  resolved it relative to the git/repo nexus's own position).
::
/<  git-obj  /lib/git/object.hoon
/<  git-pack  /lib/git/pack.hoon
/<  git-repo  /lib/git/repository.hoon
/<  git-transport  /lib/git/transport.hoon
|%
::  +load-repo-from-ns: rebuild a repository from `base` (the repo's /data dir,
::  e.g. /repos/<name>.git_repo/data), peeked through nexus rail `rail`.
::  ~ when there's no pack data.
++  load-repo-from-ns
  |=  [=rail:tarball base=path]
  =/  m  (fiber:fiber:nexus ,(unit repository:git-repo))
  ^-  form:m
  ;<  packs-view=view:nexus  bind:m
    (peek:io (nex-road:io rail [%| (weld base /packs)]) ~)
  ?.  ?=([%ball *] packs-view)  (pure:m ~)
  =/  archive=(list pack:git-pack)  (load-packs-from-ball ball.packs-view)
  ?~  archive  (pure:m ~)
  ;<  heads-view=view:nexus  bind:m
    (peek:io (nex-road:io rail [%| (weld base /refs/heads)]) ~)
  =/  built-refs=(axal ref:git-repo)
    ?.  ?=([%ball *] heads-view)  [~ ~]
    (refs-from-ball ball.heads-view ~['refs' 'heads'])
  ;<  obj-view=view:nexus  bind:m
    (peek:io (nex-road:io rail [%| (weld base /objects)]) ~)
  =/  loose=(map hash:git-repo object:git-obj)
    ?.  ?=([%ball *] obj-view)  ~
    (read-loose-from-ball ball.obj-view)
  =/  repo=repository:git-repo
    [%sha-1 [loose archive] built-refs ~ ~]
  (pure:m `repo)
::  +refs-from-ball: read ref files from a ball directory into an axal
++  refs-from-ball
  |=  [=ball:tarball prefix=path]
  ^-  (axal ref:git-repo)
  ?~  fil.ball  [~ ~]
  %+  roll  ~(tap by contents.u.fil.ball)
  |=  [[name=@t =sang:tarball gain=? bang=(unit tang)] r=(axal ref:git-repo)]
  =/  m=mime  !<(mime (need-vase:tarball sang))
  ?:  =(0 p.q.m)  r
  =/  h=(unit @ux)
    (rust (trip q.q.m) parse-hash-sha-1:git-transport)
  ?~  h  r
  (~(put of r) [(weld prefix ~[name]) u.h])
::
++  read-loose-from-ball
  |=  =ball:tarball
  ^-  (map hash:git-repo object:git-obj)
  ?~  fil.ball  ~
  =/  entries=(list [name=@t =sang:tarball gain=? bang=(unit tang)])
    ~(tap by contents.u.fil.ball)
  %+  roll  entries
  |=  [[name=@t =sang:tarball gain=? bang=(unit tang)] acc=(map hash:git-repo object:git-obj)]
  =/  h=(unit hash:git-repo)
    (rust (trip name) parse-hash-sha-1:git-transport)
  ?~  h  acc
  =/  m=mime  !<(mime (need-vase:tarball sang))
  =/  raw=raw-object:git-obj  (raw-from-octs:git-obj q.m)
  =/  obj=object:git-obj  (parse-raw:git-obj %sha-1 raw)
  (~(put by acc) u.h obj)
::  +load-packs-from-ball: read all pack-N.pack + pack-N.idx pairs
++  load-packs-from-ball
  |=  =ball:tarball
  ^-  (list pack:git-pack)
  ?~  fil.ball  ~
  =/  all-files=(list @ta)  ~(tap in ~(key by contents.u.fil.ball))
  =/  pack-nums=(list @ud)
    %+  murn  all-files
    |=  name=@ta
    =/  t=tape  (trip name)
    ?.  =("pack-" (scag 5 t))  ~
    ?.  =(".pack" (slag (sub (lent t) 5) t))  ~
    =/  num-text=tape  (slag 5 (scag (sub (lent t) 5) t))
    (rust num-text dem)
  =/  sorted=(list @ud)  (sort pack-nums lth)
  %+  murn  sorted
  |=  n=@ud
  ^-  (unit pack:git-pack)
  =/  pack-name=@ta  (crip "pack-{(a-co:co n)}.pack")
  =/  idx-name=@ta  (crip "pack-{(a-co:co n)}.idx")
  =/  pack-content=(unit [=sang:tarball gain=? bang=(unit tang)])
    (~(get by contents.u.fil.ball) pack-name)
  =/  idx-content=(unit [=sang:tarball gain=? bang=(unit tang)])
    (~(get by contents.u.fil.ball) idx-name)
  ?~  pack-content  ~
  ?~  idx-content  ~
  =/  pack-mim=mime  !<(mime (need-vase:tarball sang.u.pack-content))
  ?:  =(0 p.q.pack-mim)  ~
  =/  idx-mim=mime  !<(mime (need-vase:tarball sang.u.idx-content))
  =/  idx-text=tape  (trip q.q.idx-mim)
  =/  idx=pack-index:git-pack
    (rebuild-index (split:git-transport idx-text `@t`10))
  =/  sea=bays:bytestream  (from-octs:bytestream q.pack-mim)
  =/  entries=(list [key=hash:git-repo val=@ud])
    (tap:pack-on:git-pack idx)
  `[%sha-1 (lent entries) idx p.q.pack-mim sea]
::
++  rebuild-index
  |=  lines=(list tape)
  ^-  pack-index:git-pack
  =|  idx=pack-index:git-pack
  |-
  ?~  lines  idx
  =/  line=tape  i.lines
  ?:  =(~ line)  $(lines t.lines)
  =/  parts=(list tape)  (split:git-transport line ' ')
  ?.  =((lent parts) 2)  $(lines t.lines)
  =/  hex=tape  (snag 0 parts)
  =/  off=tape  (snag 1 parts)
  =/  h=hash:git-repo  (scan hex parse-hash-sha-1:git-transport)
  =/  o=@ud  (scan off dum:ag)
  $(lines t.lines, idx (put:pack-on:git-pack idx h o))
--
