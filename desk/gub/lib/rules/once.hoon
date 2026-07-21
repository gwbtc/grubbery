::  once: a single occurrence at the rule's start. args ignored.
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=* start=@da idx=@ud]
^-  (unit [l=@da r=(unit @da)])
?.  =(0 idx)  ~
`[start ~]
