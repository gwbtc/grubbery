::  git repository: object store, refs, remotes
::
::  Ported from hoon-git. Simplified config (no mip dependency).
::
/<  *  /lib/git/object.hoon
/<  *  /lib/git/refs.hoon
/<  *  /lib/git/refspec.hoon
/<  git-pack  /lib/git/pack.hoon
/<  git-bundle  /lib/git/bundle.hoon
=>  |%
+$  object-store  $:  loose=(map hash object)
                      archive=(list pack:git-pack)
                  ==
+$  remote  $:  url=@t
                fetch=(list refspec)
                push=(list refspec)
            ==
+$  branch  $:  remote=@tas
                push-remote=@tas
                merge=(list refname)
            ==
::
+$  repository
  $+  repository
  $:  =hash-algo
      =object-store
      =refs
      remotes=(map @tas remote)
      branches=(map refname branch)
  ==
--
::
::  Git repository engine
::
|_  repo=repository
+*  this  .
++  clone-from-bundle
  |=  =bundle:git-bundle
  ^-  repository
  ?^  need.header.bundle
    ~|  "Bundle contains prerequisites"  !!
  =.  repo  (add-pack:store pack.bundle)
  ?<  ?=(~ archive.object-store.repo)
  %=  repo
    refs
    %+  roll  refs.header.bundle
      |=  [ref=(pair path hash) =^refs]
      ?>  (has:store q.ref)
      (~(put of refs) ref)
  ==
++  remote
  |%
  ++  get-url
    |=  remote=@ta
    ^-  (unit @t)
    =+  remote=(~(get by remotes.repo) remote)
    ?~  remote  ~
    `url.u.remote
  ++  got-url
    |=  remote=@ta
    (need (get-url remote))
  --
++  store
  |%
  ++  add-pack
    |=  =pack:git-pack
    ^-  repository
    repo(archive.object-store [pack archive.object-store.repo])
  ++  get
    |=  =hash
    ^-  (unit object)
    =+  loose=(~(get by loose.object-store.repo) hash)
    ?^  loose
      loose
    %+  bind  (get-raw hash)
    (cury parse-raw %sha-1)
  ++  get-commit
    |=  =hash
    ^-  (unit commit)
    =+  obj=(get hash)
    ?~  obj  ~
    ?>  ?=(%commit -.u.obj)
    (some commit.u.obj)
  ++  get-tree
    |=  =hash
    ^-  (unit tree-dir)
    =+  obj=(get hash)
    ?~  obj  ~
    ?>  ?=(%tree -.u.obj)
    (some tree-dir.u.obj)
  ++  get-blob
    |=  =hash
    ^-  (unit octs)
    =+  obj=(get hash)
    ?~  obj  ~
    ?>  ?=(%blob -.u.obj)
    (some data.u.obj)
  ++  got
    |=  =hash
    ^-  object
    (need (get hash))
  ++  got-commit
    |=  =hash
    ^-  commit
    =+  obj=(got hash)
    ?>  ?=(%commit -.obj)
    commit.obj
  ++  got-tree
    |=  =hash
    ^-  tree-dir
    =+  obj=(got hash)
    ?>  ?=(%tree -.obj)
    tree-dir.obj
  ++  got-blob
    |=  =hash
    ^-  octs
    =+  obj=(got hash)
    ?>  ?=(%blob -.obj)
    data.obj
  ++  get-header
    |=  =hash
    ^-  (unit object-header)
    =+  loose=(~(get by loose.object-store.repo) hash)
    ?^  loose
      `[-.u.loose size.u.loose]
    %+  roll  archive.object-store.repo
      |=  [=pack:git-pack obj=(unit object-header)]
      ?~  obj
        (~(get-header git-pack pack) hash)
      obj
  ++  got-header
    |=  =hash
    ^-  object-header
    (need (get-header hash))
  ++  get-raw
    |=  =hash
    ^-  (unit raw-object)
    =+  loose=(~(get by loose.object-store.repo) hash)
    ?^  loose
      (some (obj-to-raw hash-algo.repo u.loose))
    %+  roll  archive.object-store.repo
      |=  [=pack:git-pack obj=(unit raw-object)]
      ?~  obj
        =+  rob=(~(get-raw-thin git-pack pack) hash get-raw)
        rob
      obj
  ++  has
    |=  =hash
    ^-  ?
    ?|  (~(has by loose.object-store.repo) hash)
        %+  lien  archive.object-store.repo
          |=(=pack:git-pack (~(has git-pack pack) hash))
    ==
  ++  find-by-key
    |=  a=@ta
    ^-  (unit hash)
    =+  kex=(txt-to-hash a)
    =+  key=[(met 3 a) kex]
    =/  match=(list hash)
      %+  skim  ~(tap in ~(key by loose.object-store.repo))
      (cury (cury match-key:git-pack 40) key)
    ?^  match
      (some (head match))
    =|  match=(list hash)
    =.  match
      %+  roll  archive.object-store.repo
        |=  [=pack:git-pack =_match]
        %+  weld
          (~(find-by-key git-pack pack) a)
        match
    ?~  match  ~
    (some (head match))
  --
++  refs
  |%
  ++  has
    |=  =refname
    ^-  ?
    ?=(^ (~(get of refs.repo) refname))
  ++  resolve
    |=  =refname
    ^-  (unit ^refname)
    =+  fil=(~(get of refs.repo) refname)
    ?~  fil  ~
    ?@  u.fil
      (some refname)
    (some refname.u.fil)
  ++  get
    |=  =refname
    ^-  (unit hash)
    =+  fil=(~(get of refs.repo) refname)
    ?~  fil  ~
    ?@  u.fil
      fil
    $(refname refname.u.fil)
  ++  got
    |=  =refname
    ^-  hash
    =+  ref=(get refname)
    ?~  ref
      ~|  "Refname {<refname>} not found"  !!
    u.ref
  ++  tap  (tap-prefix ~)
  ++  tap-prefix
    |=  prefix=refname
    ^-  (list [refname hash])
    %+  turn
      ~(tap of (~(dip of refs.repo) prefix))
    |=  [=refname =ref]
    ?@  ref
      [refname ref]
    [refname (got refname)]
  ++  tap-prefix-full
    |=  prefix=refname
    ^-  (list [refname hash])
    %+  turn
      ~(tap of (~(dip of refs.repo) prefix))
    |=  [=refname =ref]
    ?@  ref
      [(weld prefix refname) ref]
    [(weld prefix refname) (got refname)]
  --
--
