::  scry-grow: publish a page in this ship's remote-scry farm
::
::  The page rides JAMMED. A page's [mark *] wildcard is unsafe in a
::  mark's grab mold (the marc-builder crash class), so the payload
::  stays fully concrete: [spur=path page-jam=@]. The service handler
::  cues and shape-checks it.
::
|_  req=[spur=path page-jam=@]
++  grab
  |%
  ++  noun  ,[path @]
  --
++  grow
  |%
  ++  noun  req
  --
--
