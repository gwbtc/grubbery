|%
+$  message  [role=@t content=@t]
+$  messages  [%0 messages=((mop @ud message) lth)]
+$  action
  $%  [%say text=@t]          ::  from UI — stored as user role
      [%add role=@t text=@t]  ::  from registry — explicit role
      [%live flag=?]           ::  toggle API calls on/off
      [%interrupt ~]           ::  cancel in-flight API call
  ==
::  Parsed response tag from Claude
::
+$  response-tag
  $%  [%thought text=@t]
      [%tool calls=(list tool-call) continue=?]
      [%api action=@t path=@t body=@t continue=?]
      [%notify text=@t continue=?]
      [%message text=@t continue=?]
      [%wait ~]
      [%done output=@t]
  ==
+$  tool-call  [name=@t args=@t]
::  Registry: async multiplexer for LLM <-> grubbery namespace
::
::  Every outgoing operation (peek, make, keep, etc.) gets a slot.
::  Responses match back by wire /slot/(scot %ud id).
::
+$  slot  [action=@t path=@t]
+$  registry  [%0 nex=@ud slots=(map @ud slot) live=?]
++  mon  ((on @ud message) lth)
--
