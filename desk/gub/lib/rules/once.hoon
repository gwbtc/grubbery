::  once: a single tick at the anchor. args ignored.
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=* start=@da idx=@ud]
^-  (unit @da)
?.(=(0 idx) ~ `start)
