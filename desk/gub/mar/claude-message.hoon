::  claude-message mark: single message to append to the chat store
::  [role=@t text=@t]
::
/<  claude  /lib/claude.hoon
=,  claude
|_  msg=message
++  grab
  |%
  ++  noun  message
  --
++  grow
  |%
  ++  noun  msg
  --
++  grad  %noun
--
