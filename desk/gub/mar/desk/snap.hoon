::  desk/snap: which world snapshot is checked out, or ~ for none. The
::  checkout.desk_snap grub holds the snapshot number N materialized
::  into /checkout/code + /checkout/data; ~ means you are on live.
::
|_  n=(unit @ud)
++  grab
  |%
  ++  noun  ,(unit @ud)
  --
++  grow
  |%
  ++  noun  n
  ++  json  ?~(n ~ (numb:enjs:format u.n))
  --
--
