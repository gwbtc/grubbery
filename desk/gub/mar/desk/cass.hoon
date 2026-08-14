::  desk/cass: a checked-out revision, or ~ for none. The
::  checkout.desk_cass grub holds which revision is materialized into
::  /checkout; ~ means nothing is checked out (you are on live).
::
|_  c=(unit cass:clay)
++  grab
  |%
  ++  noun  ,(unit cass:clay)
  --
++  grow
  |%
  ++  noun  c
  ++  json
    ?~  c  ~
    %-  pairs:enjs:format
    :~  ['ud' (numb:enjs:format ud.u.c)]
        ['da' (time:enjs:format da.u.c)]
    ==
  --
--
