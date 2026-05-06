/<  test  /lib/test.hoon
/<  git-transport  /lib/git/transport.hoon
%-  run-tests:test
!>
|%
::  fake hashes for testing
++  h1  `hash:git-transport`0x1111.1111.1111.1111.1111.1111.1111.1111.1111.1111
++  h2  `hash:git-transport`0x2222.2222.2222.2222.2222.2222.2222.2222.2222.2222
++  h3  `hash:git-transport`0x3333.3333.3333.3333.3333.3333.3333.3333.3333.3333
++  h4  `hash:git-transport`0x4444.4444.4444.4444.4444.4444.4444.4444.4444.4444
++  h5  `hash:git-transport`0x5555.5555.5555.5555.5555.5555.5555.5555.5555.5555
++  h6  `hash:git-transport`0x6666.6666.6666.6666.6666.6666.6666.6666.6666.6666
::  tree hashes (for directories)
++  th1  `hash:git-transport`0xaaaa.aaaa.aaaa.aaaa.aaaa.aaaa.aaaa.aaaa.aaaa.aaaa
++  th2  `hash:git-transport`0xbbbb.bbbb.bbbb.bbbb.bbbb.bbbb.bbbb.bbbb.bbbb.bbbb
::
::  blob mode and dir mode
++  blob-mode  0x81a4  ::  100644
++  dir-mode   0x4000  ::  040000
::
::  mock get-tree that returns from a map
++  mock-trees
  |=  trees=(map hash:git-transport tree-dir:git-transport)
  ^-  $-(hash:git-transport (unit tree-dir:git-transport))
  |=(h=hash:git-transport (~(get by trees) h))
::
::  +test-identical-trees: same hash returns no changes
::
++  test-identical-trees
  |.  ^-  tang
  =/  gt  (mock-trees ~)
  =/  changes  (diff-trees:git-transport gt h1 h1)
  (expect-eq:test !>(~) !>(changes))
::
::  +test-add-file: file in new but not old
::
++  test-add-file
  |.  ^-  tang
  =/  old=tree-dir:git-transport  ~
  =/  new=tree-dir:git-transport  ~[['readme.md' blob-mode h1]]
  =/  gt  (mock-trees (malt ~[[th1 old] [th2 new]]))
  =/  changes  (diff-trees:git-transport gt th1 th2)
  =/  expected=(list tree-change:git-transport)
    ~[[%add /'readme.md' h1]]
  (expect-eq:test !>(expected) !>(changes))
::
::  +test-del-file: file in old but not new
::
++  test-del-file
  |.  ^-  tang
  =/  old=tree-dir:git-transport  ~[['readme.md' blob-mode h1]]
  =/  new=tree-dir:git-transport  ~
  =/  gt  (mock-trees (malt ~[[th1 old] [th2 new]]))
  =/  changes  (diff-trees:git-transport gt th1 th2)
  =/  expected=(list tree-change:git-transport)
    ~[[%del /'readme.md' h1]]
  (expect-eq:test !>(expected) !>(changes))
::
::  +test-mod-file: same name different hash
::
++  test-mod-file
  |.  ^-  tang
  =/  old=tree-dir:git-transport  ~[['readme.md' blob-mode h1]]
  =/  new=tree-dir:git-transport  ~[['readme.md' blob-mode h2]]
  =/  gt  (mock-trees (malt ~[[th1 old] [th2 new]]))
  =/  changes  (diff-trees:git-transport gt th1 th2)
  =/  expected=(list tree-change:git-transport)
    ~[[%mod /'readme.md' h1 h2]]
  (expect-eq:test !>(expected) !>(changes))
::
::  +test-unchanged-file: same name same hash, no changes
::
++  test-unchanged-file
  |.  ^-  tang
  =/  old=tree-dir:git-transport  ~[['readme.md' blob-mode h1]]
  =/  new=tree-dir:git-transport  ~[['readme.md' blob-mode h1]]
  =/  gt  (mock-trees (malt ~[[th1 old] [th2 new]]))
  =/  changes  (diff-trees:git-transport gt th1 th2)
  (expect-eq:test !>(~) !>(changes))
::
::  +test-mixed-changes: add + del + mod + unchanged
::
++  test-mixed-changes
  |.  ^-  tang
  =/  old=tree-dir:git-transport
    :~  ['a.txt' blob-mode h1]
        ['b.txt' blob-mode h2]
        ['c.txt' blob-mode h3]
    ==
  =/  new=tree-dir:git-transport
    :~  ['a.txt' blob-mode h1]    ::  unchanged
        ['b.txt' blob-mode h4]    ::  modified
        ['d.txt' blob-mode h5]    ::  added
    ==
  =/  gt  (mock-trees (malt ~[[th1 old] [th2 new]]))
  =/  changes  (diff-trees:git-transport gt th1 th2)
  ::  should have mod b, del c, add d
  =/  has-mod=?
    (lien changes |=(c=tree-change:git-transport &(?=(%mod -.c) =(path.c /'b.txt'))))
  =/  has-del=?
    (lien changes |=(c=tree-change:git-transport &(?=(%del -.c) =(path.c /'c.txt'))))
  =/  has-add=?
    (lien changes |=(c=tree-change:git-transport &(?=(%add -.c) =(path.c /'d.txt'))))
  =/  no-unchanged=?
    !(lien changes |=(c=tree-change:git-transport =(path.c /'a.txt')))
  ;:  weld
    (expect:test !>(has-mod))
    (expect:test !>(has-del))
    (expect:test !>(has-add))
    (expect:test !>(no-unchanged))
    (expect-eq:test !>(3) !>((lent changes)))
  ==
::
::  +test-nested-dir-change: recurse into subdirectory
::
++  test-nested-dir-change
  |.  ^-  tang
  =/  old-sub=tree-dir:git-transport  ~[['foo.txt' blob-mode h1]]
  =/  new-sub=tree-dir:git-transport  ~[['foo.txt' blob-mode h2]]
  =/  old=tree-dir:git-transport  ~[['src' dir-mode h3]]
  =/  new=tree-dir:git-transport  ~[['src' dir-mode h4]]
  =/  gt
    %-  mock-trees
    (malt ~[[th1 old] [th2 new] [h3 old-sub] [h4 new-sub]])
  =/  changes  (diff-trees:git-transport gt th1 th2)
  =/  expected=(list tree-change:git-transport)
    ~[[%mod /src/'foo.txt' h1 h2]]
  (expect-eq:test !>(expected) !>(changes))
::
::  +test-unchanged-dir: same dir hash skips entirely
::
++  test-unchanged-dir
  |.  ^-  tang
  =/  sub=tree-dir:git-transport  ~[['foo.txt' blob-mode h1]]
  =/  old=tree-dir:git-transport  ~[['src' dir-mode h3] ['readme.md' blob-mode h2]]
  =/  new=tree-dir:git-transport  ~[['src' dir-mode h3] ['readme.md' blob-mode h4]]
  =/  gt
    %-  mock-trees
    (malt ~[[th1 old] [th2 new] [h3 sub]])
  =/  changes  (diff-trees:git-transport gt th1 th2)
  ::  only readme changed, src dir untouched
  =/  expected=(list tree-change:git-transport)
    ~[[%mod /'readme.md' h2 h4]]
  (expect-eq:test !>(expected) !>(changes))
::
::  +test-dir-to-file: directory replaced by a file
::
++  test-dir-to-file
  |.  ^-  tang
  =/  sub=tree-dir:git-transport  ~[['inner.txt' blob-mode h1]]
  =/  old=tree-dir:git-transport  ~[['thing' dir-mode h3]]
  =/  new=tree-dir:git-transport  ~[['thing' blob-mode h5]]
  =/  gt  (mock-trees (malt ~[[th1 old] [th2 new] [h3 sub]]))
  =/  changes  (diff-trees:git-transport gt th1 th2)
  =/  has-del=?
    (lien changes |=(c=tree-change:git-transport &(?=(%del -.c) =(path.c /thing/'inner.txt'))))
  =/  has-add=?
    (lien changes |=(c=tree-change:git-transport &(?=(%add -.c) =(path.c /thing))))
  ;:  weld
    (expect:test !>(has-del))
    (expect:test !>(has-add))
  ==
::
::  +test-file-to-dir: file replaced by a directory
::
++  test-file-to-dir
  |.  ^-  tang
  =/  sub=tree-dir:git-transport  ~[['inner.txt' blob-mode h2]]
  =/  old=tree-dir:git-transport  ~[['thing' blob-mode h1]]
  =/  new=tree-dir:git-transport  ~[['thing' dir-mode h4]]
  =/  gt  (mock-trees (malt ~[[th1 old] [th2 new] [h4 sub]]))
  =/  changes  (diff-trees:git-transport gt th1 th2)
  =/  has-del=?
    (lien changes |=(c=tree-change:git-transport &(?=(%del -.c) =(path.c /thing))))
  =/  has-add=?
    (lien changes |=(c=tree-change:git-transport &(?=(%add -.c) =(path.c /thing/'inner.txt'))))
  ;:  weld
    (expect:test !>(has-del))
    (expect:test !>(has-add))
  ==
--
