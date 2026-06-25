::  mark for all-drafts: flat map of acct-ref to transaction draft
::
/<  drft  /lib/tx/draft.hoon
|_  dat=(map @t transaction:drft)
++  grab
  |%
  ++  noun  (map @t transaction:drft)
  --
++  grow
  |%
  ++  noun  dat
  --
--
