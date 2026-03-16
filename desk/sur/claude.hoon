|%
+$  message  [role=@t content=@t]
+$  messages  [%0 messages=((mop @ud message) lth)]
+$  action
  $%  [%say text=@t]          ::  from UI — stored as user role
      [%add role=@t text=@t]  ::  from registry — explicit role
  ==
::  Parsed response tag from Claude
::
+$  response-tag
  $%  [%thought text=@t]
      [%tool calls=(list tool-call) continue=?]
      [%api action=@t path=@t body=@t continue=?]
      [%notify text=@t continue=?]
      [%message text=@t]
      [%wait ~]
      [%done output=@t]
  ==
+$  tool-call  [name=@t args=@t]
::  Registry: singleton multiplexer for LLM <-> grubbery namespace
::
::  keeps: one per path, long-lived subscriptions
::  flights: in-flight async requests, keyed by counter
::
+$  registry  [%0 nex=@ud keeps=(map @t @ud) flights=(map @ud [action=@t path=@t])]
++  mon  ((on @ud message) lth)
--
