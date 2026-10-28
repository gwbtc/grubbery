::  scry-grow: publish a page in this ship's remote-scry farm
::
::  The page is typed as arvo's $page and validated the normal way.
::  (An earlier version jammed it out of the marc-builder-crash
::  folklore; PR #44's investigation confirmed the wildcard is fine.)
::
|_  req=[spur=path =page]
++  grab
  |%
  ++  noun  ,[path page]
  --
++  grow
  |%
  ++  noun  req
  --
--
