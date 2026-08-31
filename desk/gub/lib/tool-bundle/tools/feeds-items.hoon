/<  tools  /lib/tools.hoon
/<  rss    /lib/rss.hoon
^-  tool:tools
|%
++  name  'feeds_items'
++  description
  'Recent items across all feeds, newest first. Optional limit (default 20).'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['limit' [%number 'Max items to return (default 20)']]
  ==
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  limit=@ud
    =/  v  (~(get by args.st) 'limit')
    ?.  ?=([~ %n *] v)  20
    (fall (rush p.u.v dem) 20)
  ;<  sto=view:nexus  bind:m
    (peek:io [%& %| /apps/'feeds.feeds'/store] ~)
  =/  stores=(list feed-store:rss)
    ?.  ?=([%ball *] sto)  ~
    %+  murn  ~(tap ba:tarball ball.sto)
    |=  [* =sang:tarball]
    ^-  (unit feed-store:rss)
    ?.  =([/ %feed] p.sang)  ~
    ?:  (is-boom:tarball sang)  ~
    `!<(feed-store:rss (need-vase:tarball sang))
  =/  all=(list [feed=@t =item:rss])
    %-  zing
    %+  turn  stores
    |=  fs=feed-store:rss
    (turn items.fs |=(it=item:rss [title.fs it]))
  =/  sorted
    %+  sort  all
    |=  [a=[feed=@t =item:rss] b=[feed=@t =item:rss]]
    (gth published.item.a published.item.b)
  =/  jon=json
    :-  %a
    %+  turn  (scag limit sorted)
    |=  [feed=@t =item:rss]
    %-  pairs:enjs:format
    :~  ['feed' s+feed]
        ['title' s+title.item]
        ['link' s+link.item]
        ['published' (time:enjs:format published.item)]
    ==
  (pure:m [%text (en:json:html jon)])
--
