|%
+$  message  [role=@t content=@t]
+$  messages  [%0 messages=((mop @ud message) lth)]
+$  action  [%say text=@t]
::  Parsed response tag from Claude
::
+$  response-tag
  $%  [%thought text=@t]
      [%tool calls=(list tool-call) continue=?]
      [%api method=@t path=@t body=@t continue=?]
      [%notify text=@t continue=?]
      [%message text=@t]
      [%wait ~]
      [%done output=@t]
  ==
+$  tool-call  [name=@t args=@t]
++  mon  ((on @ud message) lth)
--
