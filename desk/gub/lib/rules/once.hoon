::  once: a single tick at the anchor. args ignored.
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=(map @t json) start=@da idx=@ud]
^-  (unit @da)
?.(=(0 idx) ~ `start)
