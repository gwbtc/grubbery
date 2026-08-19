::  keen-response: the answer to a scry-keen, poked back to the
::  requesting grub — the request wire plus the page bound at the
::  remote path (~ = nothing bound). The page is typed as arvo's own
::  $page and validated the normal grubbery way, like any poke.
::
|_  kres=[=wire pag=(unit page)]
++  grab
  |%
  ++  noun  ,[wire (unit page)]
  --
++  grow
  |%
  ++  noun  kres
  --
--
