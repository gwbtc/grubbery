/-  *claude
|_  msg=messages
++  grab
  |%
  ++  noun  messages
  ++  mime
    |=  [=mite len=@ud dat=@]
    ^-  messages
    (json (need (de:json:html (cut 3 [0 len] dat))))
  ++  json
    |=  j=^json
    ^-  messages
    :-  %0
    ?.  ?=([%a *] j)  ~
    =/  idx=@ud  0
    |-
    ?~  p.j  ~
    =/  m=^json  i.p.j
    ?.  ?=([%o *] m)
      $(p.j t.p.j, idx +(idx))
    =/  role=(unit ^json)  (~(get by p.m) 'role')
    =/  content=(unit ^json)  (~(get by p.m) 'content')
    ?~  role    $(p.j t.p.j, idx +(idx))
    ?~  content  $(p.j t.p.j, idx +(idx))
    ?.  ?=([%s *] u.role)   $(p.j t.p.j, idx +(idx))
    ?.  ?=([%s *] u.content)  $(p.j t.p.j, idx +(idx))
    (put:mon $(p.j t.p.j, idx +(idx)) idx [p.u.role p.u.content])
  --
++  grow
  |%
  ++  noun  msg
  ++  json
    ^-  ^json
    :-  %a
    %+  turn  (tap:mon messages.msg)
    |=  [idx=@ud =message]
    %-  pairs:enjs:format
    ~[['role' s+role.message] ['content' s+content.message]]
  ++  mime
    ^-  ^mime
    [/application/json (as-octs:mimes:html (en:json:html json))]
  --
++  grad  %noun
--
