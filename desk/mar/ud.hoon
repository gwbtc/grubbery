|_  val=@ud
++  grab
  |%
  ++  noun  @ud
  ++  mime
    |=  [=mite len=@ud tex=@t]
    ^-  @ud
    =/  txt=wain  (to-wain:format tex)
    ?~  txt  !!
    (rash i.txt dem)
  --
++  grow
  |%
  ++  noun  val
  ++  txt  ~[(crip (a-co:co val))]
  ++  mime
    ^-  ^mime
    [/text/plain (as-octs:mimes:html (of-wain:format txt))]
  --
++  grad  %noun
--
