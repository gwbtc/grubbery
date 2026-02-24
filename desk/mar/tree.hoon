::  tree: file tree structure mark
::  Represents ball structure with just marks, no content
::
/+  tarball
!: :: turn on stack trace
|_  =tree:tarball
++  grad  %noun
++  grow
  |%
  ++  noun  tree
  ++  json  (tree-to-json tree)
  --
++  grab
  |%
  ++  noun  tree:tarball
  --
++  tree-to-json
  |=  tre=tree:tarball
  ^-  json
  =/  subdirs=json
    [%o (~(run by dir.tre) tree-to-json)]
  ?~  fil.tre
    (pairs:enjs:format ~[['dirs' subdirs]])
  =/  files=json
    [%o (~(run by files.u.fil.tre) |=(m=@tas s+m))]
  =/  neck=json
    ?~(neck.u.fil.tre ~ s+u.neck.u.fil.tre)
  %-  pairs:enjs:format
  :~  ['neck' neck]
      ['files' files]
      ['dirs' subdirs]
  ==
--
