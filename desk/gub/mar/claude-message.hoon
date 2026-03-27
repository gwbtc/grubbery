::  claude-message mark: single message to append to the chat store
::  [role=@t text=@t]
::
/<  *  /lib/claude.hoon
|_  msg=message
++  grab
  |%
  ++  noun  message
  --
++  grow
  |%
  ++  noun  msg
  --
--
