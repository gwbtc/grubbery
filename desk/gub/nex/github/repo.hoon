::  github/repo nexus: git object store + atomic checkout
::
::  Stores pack data, index, refs, HEAD. On reload, checks out
::  the tree at HEAD and builds commit log + branch list.
::
::  Ball layout (inputs — written by parent):
::    pack.dat       raw pack bytes (mime)
::    pack.idx       index: "hex-hash offset\n" per line (mime)
::    HEAD           commit hash to checkout (mime text)
::    ref            branch name for commit log (mime text)
::    refs.json      {"branch": "hash", ...} (json)
::
::  Ball layout (outputs — built by on-load):
::    tree/          checked out files
::    commits.json   commit log from HEAD (50 max)
::    branches.json  branch name list
::    current.json   {"hash": "<HEAD>"}
::
/<  git-pack  /lib/git/pack.hoon
/<  git-repo  /lib/git/repository.hoon
/<  git-transport  /lib/git/transport.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      ::  check for pack data
      =/  pack-content=(unit content:tarball)
        (~(get ba:tarball ball) [/ %'pack.dat'])
      ?~  pack-content  [sand gain ball]
      =/  pack-mim=mime  !<(mime q.sage.u.pack-content)
      ?:  =(0 p.q.pack-mim)  [sand gain ball]
      ::  check for HEAD
      =/  head-content=(unit content:tarball)
        (~(get ba:tarball ball) [/ %'HEAD'])
      ?~  head-content  [sand gain ball]
      =/  head-mim=mime  !<(mime q.sage.u.head-content)
      =/  head-text=tape  (trip q.q.head-mim)
      =/  commit-hash=(unit @ux)
        (rust head-text parse-hash-sha-1:git-transport)
      ?~  commit-hash  [sand gain ball]
      ::  check for index
      =/  idx-content=(unit content:tarball)
        (~(get ba:tarball ball) [/ %'pack.idx'])
      ?~  idx-content  [sand gain ball]
      =/  idx-mim=mime  !<(mime q.sage.u.idx-content)
      =/  idx-text=tape  (trip q.q.idx-mim)
      ::  rebuild pack from index (no full reparse)
      =/  idx=pack-index:git-pack
        (rebuild-index (split:git-transport idx-text `@t`10))
      =/  sea=bays:bytestream  (from-octs:bytestream q.pack-mim)
      =/  entries=(list [key=hash:git-repo val=@ud])
        (tap:pack-on:git-pack idx)
      =/  pak=pack:git-pack
        [%sha-1 (lent entries) idx p.q.pack-mim sea]
      ::  read refs from refs.json
      =/  built-refs=(axal ref:git-repo)
        (read-refs-from-json ball)
      =/  repo=repository:git-repo
        [%sha-1 [~ ~[pak]] built-refs ~ ~]
      =/  sto  store:~(. git-repo repo)
      ::  resolve HEAD -> commit -> tree
      =/  com=commit:git-repo  (got-commit:sto u.commit-hash)
      ~&  >>  ["%repo: checkout" (scag 7 head-text)]
      =/  get-tree=$-(@ux (unit tree-dir:git-repo))
        |=(h=@ux (get-tree:sto h))
      =/  get-blob=$-(@ux (unit octs))
        |=(h=@ux (get-blob:sto h))
      ::  checkout tree
      =/  files=(list [path octs])
        (checkout:git-transport get-tree get-blob tree.com)
      ~&  >>  ["%repo: checked out" (lent files) "files"]
      =/  tree-ball=ball:tarball  (files-to-ball files)
      ::  build derived data — commit log from branch tip, not HEAD
      =/  ref-content=(unit content:tarball)
        (~(get ba:tarball ball) [/ %'ref'])
      =/  log-start=hash:git-repo
        ?~  ref-content  u.commit-hash
        =/  ref-mim=mime  !<(mime q.sage.u.ref-content)
        =/  ref-name=@t  (crip (trip q.q.ref-mim))
        =/  refs-j=(unit content:tarball)
          (~(get ba:tarball ball) [/ %'refs.json'])
        ?~  refs-j  u.commit-hash
        =/  j=json  !<(json q.sage.u.refs-j)
        ?.  ?=(%o -.j)  u.commit-hash
        =/  branch-hash=(unit json)  (~(get by p.j) ref-name)
        ?~  branch-hash  u.commit-hash
        ?.  ?=(%s -.u.branch-hash)  u.commit-hash
        =/  h=(unit @ux)
          (rust (trip p.u.branch-hash) parse-hash-sha-1:git-transport)
        (fall h u.commit-hash)
      =/  commits=json  (build-commit-log sto log-start 50)
      =/  branches=json  (build-branch-list ball)
      =/  hex=@t  (crip head-text)
      =/  current=json  (pairs:enjs:format ~[['hash' s+hex]])
      ::  write outputs into ball (preserving inputs)
      =.  ball  ball(dir (~(put by dir.ball) 'tree' tree-ball))
      =.  ball
        (~(put ba:tarball ball) [/ %'commits.json'] [~ [/ %json] !>(commits)])
      =.  ball
        (~(put ba:tarball ball) [/ %'branches.json'] [~ [/ %json] !>(branches)])
      =.  ball
        (~(put ba:tarball ball) [/ %'current.json'] [~ [/ %json] !>(current)])
      [sand gain ball]
    ::
    ++  on-file
      |=  [=rail:tarball =mark]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      stay:m
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Git repository data.'
            ~
          'Git object store. Stores pack, index, refs. Checkout via reload.'
        ==
          %|
        ?+  rail.p.mana  'File under repo.'
          [~ %'pack.dat']   'Raw git pack bytes.'
          [~ %'pack.idx']   'Pack index: hash->offset map.'
          [~ %'HEAD']       'Target commit hash for checkout.'
          [~ %'ref']        'Branch name for commit log.'
          [~ %'refs.json']  'Branch refs: name->hash.'
        ==
      ==
    --
::
|%
::  +read-refs-from-json: parse refs.json into axal
::
++  read-refs-from-json
  |=  =ball:tarball
  ^-  (axal ref:git-repo)
  =/  refs-content=(unit content:tarball)
    (~(get ba:tarball ball) [/ %'refs.json'])
  ?~  refs-content  [~ ~]
  =/  j=json  !<(json q.sage.u.refs-content)
  ?.  ?=(%o -.j)  [~ ~]
  %+  roll  ~(tap by p.j)
  |=  [[name=@t hash-cord=json] r=(axal ref:git-repo)]
  ?.  ?=(%s -.hash-cord)  r
  =/  h=(unit @ux)
    (rust (trip p.hash-cord) parse-hash-sha-1:git-transport)
  ?~  h  r
  (~(put of r) [~['refs' 'heads' name] u.h])
::
::  +rebuild-index: parse index text lines into pack-index
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
::
::  +build-commit-log: walk parent chain, return JSON array
::
++  build-commit-log
  |=  [sto=_store:~(. git-repo *repository:git-repo) start=hash:git-repo max=@ud]
  ^-  json
  =|  acc=(list json)
  =|  count=@ud
  =/  h=hash:git-repo  start
  |-
  ?:  (gte count max)  [%a (flop acc)]
  =/  com=(unit commit:git-repo)  (get-commit:sto h)
  ?~  com  [%a (flop acc)]
  =/  hex=@t  (crip (print-hash-sha-1:git-transport h))
  =/  short=@t  (crip (scag 7 (print-hash-sha-1:git-transport h)))
  =/  msg=@t  (crip (scag 72 (take-first-line message.u.com)))
  =/  full-msg=@t  (crip message.u.com)
  =/  author-name=@t  (crip name.author.u.com)
  =/  author-email=@t  (crip email.author.u.com)
  =/  committer-name=@t  (crip name.committer.u.com)
  =/  committer-email=@t  (crip email.committer.u.com)
  =/  tree-hex=@t  (crip (print-hash-sha-1:git-transport tree.u.com))
  =/  parent-hashes=(list json)
    (turn parents.u.com |=(p=@ux s+(crip (print-hash-sha-1:git-transport p))))
  =/  entry=json
    %-  pairs:enjs:format
    :~  ['hash' s+hex]
        ['short' s+short]
        ['message' s+msg]
        ['body' s+full-msg]
        ['author' s+author-name]
        ['authorEmail' s+author-email]
        ['date' (time:enjs:format date.author-time.u.com)]
        ['committer' s+committer-name]
        ['committerEmail' s+committer-email]
        ['commitDate' (time:enjs:format date.commit-time.u.com)]
        ['tree' s+tree-hex]
        ['parents' [%a parent-hashes]]
    ==
  ?~  parents.u.com  [%a (flop [entry acc])]
  $(h i.parents.u.com, count +(count), acc [entry acc])
::
++  take-first-line
  |=  t=tape
  ^-  tape
  =/  idx=(unit @ud)  (find "\0a" t)
  ?~  idx  t
  (scag u.idx t)
::
::  +build-branch-list: extract branch names from refs.json
::
++  build-branch-list
  |=  =ball:tarball
  ^-  json
  =/  refs-content=(unit content:tarball)
    (~(get ba:tarball ball) [/ %'refs.json'])
  ?~  refs-content  [%a ~]
  =/  j=json  !<(json q.sage.u.refs-content)
  ?.  ?=(%o -.j)  [%a ~]
  [%a (turn ~(tap in ~(key by p.j)) |=(n=@t s+n))]
::
::  +files-to-ball: convert checkout output to ball tree
::
++  files-to-ball
  |=  files=(list [=path data=octs])
  ^-  ball:tarball
  =|  tree=ball:tarball
  |-
  ?~  files  tree
  =/  file-path=path  path.i.files
  ?~  file-path  $(files t.files)
  =/  name=@ta  (rear file-path)
  =/  dir=path  (snip `path`file-path)
  =/  content-type=path  (guess-mime name)
  =/  =mime  [content-type data.i.files]
  =/  =content:tarball  [*metadata:tarball [/ %mime] !>(mime)]
  =/  segs=(list @t)
    ?~  dir  ~[name]
    (weld dir ~[name])
  =.  tree  (insert-file tree segs content)
  $(files t.files)
::
++  insert-file
  |=  [tree=ball:tarball segs=(list @ta) =content:tarball]
  ^-  ball:tarball
  ?~  segs  tree
  ?~  t.segs
    =/  =lump:tarball
      (fall fil.tree [*metadata:tarball ~ ~])
    =.  contents.lump  (~(put by contents.lump) i.segs content)
    tree(fil `lump)
  =/  kid=ball:tarball
    (fall (~(get by dir.tree) i.segs) [~ ~])
  =.  kid  $(tree kid, segs t.segs)
  tree(dir (~(put by dir.tree) i.segs kid))
::
++  guess-mime
  |=  filename=@t
  ^-  path
  =/  ext=@t
    =/  =tape  (trip filename)
    =/  idx=(unit @ud)  (find "." (flop tape))
    ?~  idx  ''
    (crip (slag (sub (lent tape) u.idx) tape))
  ?+  ext  /application/octet-stream
    %hoon  /text/plain
    %txt   /text/plain
    %md    /text/plain
    %json  /application/json
    %html  /text/html
    %css   /text/css
    %js    /application/javascript
    %ts    /text/plain
    %py    /text/plain
    %rs    /text/plain
    %c     /text/plain
    %h     /text/plain
    %go    /text/plain
    %toml  /text/plain
    %yaml  /text/plain
    %yml   /text/plain
    %xml   /text/xml
    %svg   /image/'svg+xml'
    %sh    /text/plain
    %nix   /text/plain
  ==
--
