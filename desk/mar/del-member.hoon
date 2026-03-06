::  del-member: a single ship identity for removing from a group
::
|_  ship=@p
++  grab
  |%
  ++  noun  @p
  ++  mime
    |=  [=mite len=@ud tex=@t]
    ^-  @p
    (slav %p (crip (trip tex)))
  --
++  grow
  |%
  ++  noun  ship
  ++  mime
    ^-  ^mime
    [/text/plain (as-octs:mimes:html (scot %p ship))]
  --
++  grad  %noun
--
