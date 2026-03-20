/-  *claude
|_  act=action
++  grab
  |%
  ++  noun  action
  ++  mime
    |=  [=mite len=@ud dat=@]
    ^-  action
    (json (need (de:json:html (cut 3 [0 len] dat))))
  ++  json
    |=  j=^json
    ^-  action
    ?.  ?=([%o *] j)  [%say '']
    =/  interrupt=(unit ^json)  (~(get by p.j) 'interrupt')
    ?^  interrupt
      [%interrupt ~]
    =/  live=(unit ^json)  (~(get by p.j) 'live')
    ?^  live
      [%live ?=([%b %.y] u.live)]
    =/  text=(unit ^json)  (~(get by p.j) 'text')
    ?~  text  [%say '']
    ?.  ?=([%s *] u.text)  [%say '']
    [%say p.u.text]
  --
++  grow
  |%
  ++  noun  act
  ++  json
    ^-  ^json
    ?-  -.act
        %say
      %-  pairs:enjs:format
      ~[['type' s+'say'] ['text' s+text.act]]
        %add
      %-  pairs:enjs:format
      ~[['type' s+'add'] ['role' s+role.act] ['text' s+text.act]]
        %live
      %-  pairs:enjs:format
      ~[['type' s+'live'] ['live' b+flag.act]]
        %interrupt
      %-  pairs:enjs:format
      ~[['type' s+'interrupt']]
    ==
  --
++  grad  %noun
--
