::  HTTP request state for request files
::
!: :: turn on stack trace
|_  [src=@p req=inbound-request:eyre]
++  grab
  |%
  ++  noun  ,[src=@p inbound-request:eyre]
  --
++  grow
  |%
  ++  noun  [src req]
  ++  json
    ^-  ^json
    =/  bod=(unit @t)
      ?~  body.request.req  ~
      =/  raw=@t  (@t q.u.body.request.req)
      ::  Truncate large bodies
      ?:  (gth (met 3 raw) 4.096)
        `(cat 3 (end [3 4.096] raw) '...(truncated)')
      `raw
    %-  pairs:enjs:format
    :~  ['src' s+(scot %p src)]
        ['authenticated' b+authenticated.req]
        ['secure' b+secure.req]
        ['method' s+method.request.req]
        ['url' s+url.request.req]
        :-  'headers'
        :-  %a
        %+  turn  header-list.request.req
        |=  [key=@t value=@t]
        %-  pairs:enjs:format
        :~  ['key' s+key]
            ['value' s+value]
        ==
      ::
        ['body' ?~(bod ~ s+u.bod)]
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
++  grad  %noun
--
