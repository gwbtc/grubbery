::  Bootstrap mark — compiled into the runtime before build-code runs.
::  This file exists for reference only; the runtime uses a hardcoded
::  version and build-code skips it.
::
|_  kal=waft:clay
++  grow
  |%
  ++  mime  `^mime`[/text/x-kelvin (as-octs:mimes:html hoon)]
  ++  noun  kal
  ++  hoon
    %+  rap  3
    %+  turn
      %+  sort
        ~(tap in (waft-to-wefts:clay kal))
      |=  [a=weft b=weft]
      ?:  =(lal.a lal.b)
        (gte num.a num.b)
      (gte lal.a lal.b)
    |=  =weft
    (rap 3 '[%' (scot %tas lal.weft) ' ' (scot %ud num.weft) ']\0a' ~)
  ::
  ++  txt   (to-wain:format hoon)
  --
++  grab
  |%
  ++  noun  waft:clay
  ++  mime
    |=  [=mite len=@ud tex=@]
    (cord-to-waft:clay tex)
  --
--
