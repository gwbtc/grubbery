/<  test  /lib/test.hoon
/<  git-obj  /lib/git/object.hoon
%-  run-tests:test
!>
|%
::  +test-blob-roundtrip: blob -> raw -> octs -> raw -> blob
::
++  test-blob-roundtrip
  |.  ^-  tang
  =/  data=octs  (as-octt:mimes:html "hello world\0a")
  =/  blob=object:git-obj  [%blob p.data data]
  =/  raw=raw-object:git-obj  (obj-to-raw:git-obj %sha-1 blob)
  =/  octs=octs  (raw-to-octs:git-obj raw)
  =/  raw2=raw-object:git-obj  (raw-from-octs:git-obj octs)
  =/  blob2=object:git-obj  (parse-raw:git-obj %sha-1 raw2)
  (expect-eq:test !>(blob) !>(blob2))
::
::  +test-empty-blob-roundtrip: empty blob
::
++  test-empty-blob-roundtrip
  |.  ^-  tang
  =/  blob=object:git-obj  [%blob 0 [0 0]]
  =/  raw=raw-object:git-obj  (obj-to-raw:git-obj %sha-1 blob)
  =/  octs=octs  (raw-to-octs:git-obj raw)
  =/  raw2=raw-object:git-obj  (raw-from-octs:git-obj octs)
  =/  blob2=object:git-obj  (parse-raw:git-obj %sha-1 raw2)
  (expect-eq:test !>(blob) !>(blob2))
::
::  +test-tree-roundtrip: tree with entries
::
++  test-tree-roundtrip
  |.  ^-  tang
  =/  h1  `hash:git-obj`0x1111.1111.1111.1111.1111.1111.1111.1111.1111.1111
  =/  h2  `hash:git-obj`0x2222.2222.2222.2222.2222.2222.2222.2222.2222.2222
  =/  entries=(list tree-entry:git-obj)
    :~  ['file.txt' 0x81a4 h1]
        ['src' 0x4000 h2]
    ==
  =/  tree=object:git-obj  [%tree 0 entries]
  =/  raw=raw-object:git-obj  (obj-to-raw:git-obj %sha-1 tree)
  =.  size.tree  size.raw
  ::  roundtrip: serialize -> deserialize -> check fields
  ::  parse-tree reverses entry order so compare as sets
  =/  octs=octs  (raw-to-octs:git-obj raw)
  =/  raw2=raw-object:git-obj  (raw-from-octs:git-obj octs)
  =/  tree2=object:git-obj  (parse-raw:git-obj %sha-1 raw2)
  ?>  ?=(%tree -.tree2)
  =/  orig=(set tree-entry:git-obj)  (silt entries)
  =/  parsed=(set tree-entry:git-obj)  (silt tree-dir.tree2)
  (expect-eq:test !>(orig) !>(parsed))
::
::  +test-commit-roundtrip: commit object
::
++  test-commit-roundtrip
  |.  ^-  tang
  =/  tree-hash  `hash:git-obj`0xaaaa.aaaa.aaaa.aaaa.aaaa.aaaa.aaaa.aaaa.aaaa.aaaa
  =/  parent-hash  `hash:git-obj`0xbbbb.bbbb.bbbb.bbbb.bbbb.bbbb.bbbb.bbbb.bbbb.bbbb
  =/  com=commit:git-obj
    :_  "test commit message"
    :*  tree-hash
        ~[parent-hash]
        ["Test Author" "test@example.com"]
        [~2025.1.1 [%.y ~h0]]
        ["Test Author" "test@example.com"]
        [~2025.1.1 [%.y ~h0]]
        ~
    ==
  =/  obj=object:git-obj  [%commit 0 com]
  =/  raw=raw-object:git-obj  (obj-to-raw:git-obj %sha-1 obj)
  =.  size.obj  size.raw
  =/  octs=octs  (raw-to-octs:git-obj raw)
  =/  raw2=raw-object:git-obj  (raw-from-octs:git-obj octs)
  =/  obj2=object:git-obj  (parse-raw:git-obj %sha-1 raw2)
  (expect-eq:test !>(obj) !>(obj2))
::
::  +test-empty-tree-roundtrip: tree with no entries
::
++  test-empty-tree-roundtrip
  |.  ^-  tang
  =/  tree=object:git-obj  [%tree 0 ~]
  =/  raw=raw-object:git-obj  (obj-to-raw:git-obj %sha-1 tree)
  =.  size.tree  size.raw
  =/  octs=octs  (raw-to-octs:git-obj raw)
  =/  raw2=raw-object:git-obj  (raw-from-octs:git-obj octs)
  =/  tree2=object:git-obj  (parse-raw:git-obj %sha-1 raw2)
  (expect-eq:test !>(tree) !>(tree2))
--
