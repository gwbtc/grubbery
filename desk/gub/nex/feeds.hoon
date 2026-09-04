::  feeds: RSS/Atom reader
::
::  Tree layout:
::    /main.sig         register with notifications, bind HTTP, dispatch
::    /refresh.sig      fetch loop: all feeds every 15m; any poke
::                      restarts it for an immediate refresh
::    /feeds.json       config: array of feed URL strings
::    /store/{hash}.feed  one %feed grub per feed: title + items
::    /rss-parser.wasm  the parser binary (executed via sut wasm engine)
::    /requests/{id}    HTTP request fibers
::
/<  rss  /lib/rss.hoon
/<  parser-wasm  feeds/rss-parser.wasm
/<  index-html   feeds/index.html
/<  feeds-js     feeds/feeds.js
/<  icon         feeds/icon.svg
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Feeds'
            info+s+'RSS reader'
            color+s+'#b8763e'
            image+s+'/grubbery/tiles/icon/feeds.feeds'
            href+s+'/grubbery/feeds'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'feeds'] ['description' s+'RSS and Atom feed reader']])]]
          [%over %& [/ %'weir.json'] [[/ %json] (pairs:enjs:format ~[['poke' a+~[(pairs:enjs:format ~[['road' s+'/sys/bowl.sig'] ['why' s+'time, identity, entropy — every fiber op']]) (pairs:enjs:format ~[['road' s+'/sys/behn/'] ['why' s+'the 15-minute refresh timer']]) (pairs:enjs:format ~[['road' s+'/sys/eyre/'] ['why' s+'serve the reader UI']]) (pairs:enjs:format ~[['road' s+'/sys/iris/'] ['why' s+'fetch RSS/Atom feeds over HTTP']]) (pairs:enjs:format ~[['road' s+'@notifications/main.sig'] ['why' s+'register and post a notification on new items']])]]])]]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'index.html'] [[/ %mime] index-html]]
          [%over %& [/ %'feeds.js'] [[/ %mime] feeds-js]]
          [%over %& [/ %'rss-parser.wasm'] [[/ %mime] parser-wasm]]
          [%fall %& [/ %'feeds.json'] [[/ %json] [%a ~]]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'refresh.sig'] [[/ %sig] ~]]
          [%fall %| /store empty-dir:loader]
          [%fall %| /requests empty-dir:loader]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%feeds /main: failed")
        ;<  ~  bind:m  (register-app:io 'Feeds')
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/feeds])
        (http-dispatch:io %feeds)
          ::
          [~ %'refresh.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%feeds /refresh: failed")
        |-
        ;<  ~  bind:m  (refresh-all rail)
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m  (send-wait:io (add now ~m15))
        ::  timer-wake or any direct poke both mean: refresh now
        ;<  ~  bind:m  take-any-poke
        $
          ::
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%feeds /requests: failed")
        =/  srv  ~(. http-res:io (nex-road:io rail [%& ~ %'main.sig']))
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  &(authenticated.req =(src our))
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  prefix=path  /grubbery/feeds
        =/  site=path  site:(parse-url:http-utils url.request.req)
        =/  suffix=path  (slag (lent prefix) site)
        ?+    suffix
          ::  static files
          =/  filename=@ta
            ?~  suffix  'index.html'
            i.suffix
          ;<  =view:nexus  bind:m  (peek:io (nex-road:io rail [%& / filename]) `[/ %mime])
          ?.  ?=([%file *] view)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
          =/  =mime  !<(mime (need-vase:tarball sang.view))
          ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
          (pure:m ~)
            ::
            [%api %items ~]
          ;<  urls=(list @t)  bind:m  (read-config rail)
          ;<  stores=(list feed-store:rss)  bind:m  (read-stores rail)
          =/  jon=json
            %-  pairs:enjs:format
            :~  ['config' a+(turn urls |=(u=@t s+u))]
                ['stores' a+(turn stores store-json:rss)]
            ==
          =/  bod=octs  (as-octs:mimes:html (en:json:html jon))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ['content-type' 'application/json'] ~] `bod])
          (pure:m ~)
            ::
            [%api %add ~]
          ?.  =(%'POST' method.request.req)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[405 ~] `(as-octs:mimes:html 'Method not allowed')])
            (pure:m ~)
          =/  url=(unit @t)  (body-url req)
          ?~  url
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing url')])
            (pure:m ~)
          ;<  urls=(list @t)  bind:m  (read-config rail)
          ?.  =(~ (find [u.url]~ urls))
            ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html '{"ok":true}')])
            (pure:m ~)
          ;<  ~  bind:m  (write-config rail (snoc urls u.url))
          ::  restart the refresh loop for an immediate fetch
          ;<  ~  bind:m  (poke:io (nex-road:io rail [%& ~ %'refresh.sig']) [[/ %sig] ~])
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html '{"ok":true}')])
          (pure:m ~)
            ::
            [%api %del ~]
          ?.  =(%'POST' method.request.req)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[405 ~] `(as-octs:mimes:html 'Method not allowed')])
            (pure:m ~)
          =/  url=(unit @t)  (body-url req)
          ?~  url
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing url')])
            (pure:m ~)
          ;<  urls=(list @t)  bind:m  (read-config rail)
          ;<  ~  bind:m  (write-config rail (skip urls |=(u=@t =(u u.url))))
          =/  store=road:tarball  (nex-road:io rail [%& /store (store-name u.url)])
          ;<  =view:nexus  bind:m  (peek:io store ~)
          ;<  ~  bind:m
            ?.  ?=([%file *] view)  (pure:(fiber:fiber:nexus ,~) ~)
            (cull:io store)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html '{"ok":true}')])
          (pure:m ~)
            ::
            [%api %refresh ~]
          ?.  =(%'POST' method.request.req)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[405 ~] `(as-octs:mimes:html 'Method not allowed')])
            (pure:m ~)
          ;<  ~  bind:m  (poke:io (nex-road:io rail [%& ~ %'refresh.sig']) [[/ %sig] ~])
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html '{"ok":true}')])
          (pure:m ~)
        ==
      ==
    --
|%
::  +take-any-poke: consume the next poke, whatever it is.
::  The refresh loop treats timer wakes and direct %sig pokes
::  identically, so consuming (and thereby acking) anything is right.
::
++  take-any-poke
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
    ~              [%wait ~]
    [~ %veto *]    [%fail (veto-error:io dart.u.in)]
    [~ %poke * *]  [%done ~]
  ==
::  +store-name: /store grub name for a feed url
::
++  store-name
  |=  url=@t
  ^-  @ta
  (rap 3 (scot %uv (sham url)) '.feed' ~)
::  +body-url: extract url string from a POST json body
::
++  body-url
  |=  req=inbound-request:eyre
  ^-  (unit @t)
  ?~  body.request.req  ~
  =/  jon=(unit json)  (de:json:html q.u.body.request.req)
  ?.  ?=([~ %o *] jon)  ~
  =/  v  (~(get by p.u.jon) 'url')
  ?.  ?=([~ %s *] v)  ~
  ?:  =('' p.u.v)  ~
  `p.u.v
::  +read-config: feed urls from feeds.json
::
++  read-config
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(list @t))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io (nex-road:io rail [%& ~ %'feeds.json']) `[/ %json])
  ?.  ?=([%file *] view)  (pure:m ~)
  =/  jon=json  !<(json (need-vase:tarball sang.view))
  ?.  ?=([%a *] jon)  (pure:m ~)
  (pure:m (murn p.jon |=(j=json ?.(?=([%s *] j) ~ `p.j))))
::
++  write-config
  |=  [=rail:tarball urls=(list @t)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  %+  over:io  (nex-road:io rail [%& ~ %'feeds.json'])
  [[/ %json] `json`[%a (turn urls |=(u=@t s+u))]]
::  +read-stores: all parsed feeds under /store
::
++  read-stores
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(list feed-store:rss))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io (nex-road:io rail [%| /store]) ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  %-  pure:m
  %+  murn  ~(tap ba:tarball ball.view)
  |=  [* =sang:tarball]
  ^-  (unit feed-store:rss)
  ?.  =([/ %feed] p.sang)  ~
  ?:  (is-boom:tarball sang)  ~
  `!<(feed-store:rss (need-vase:tarball sang))
::  +refresh-all: fetch every configured feed, notify on new items
::
++  refresh-all
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  urls=(list @t)  bind:m  (read-config rail)
  |-
  ?~  urls  (pure:m ~)
  ;<  res=[title=@t new=@ud]  bind:m  (refresh-feed rail i.urls)
  ;<  ~  bind:m
    ?:  =(0 new.res)  (pure:(fiber:fiber:nexus ,~) ~)
    %+  notify:io  %.y
    %-  pairs:enjs:format
    :~  ['title' s+title.res]
        ['body' s+(crip "{(scow %ud new.res)} new item{?:(=(1 new.res) "" "s")}")]
        ['url' s+'/grubbery/feeds']
    ==
  $(urls t.urls)
::  +refresh-feed: fetch one feed, parse, merge into its store grub
::
++  refresh-feed
  |=  [=rail:tarball url=@t]
  =/  m  (fiber:fiber:nexus ,[title=@t new=@ud])
  ^-  form:m
  ;<  bod=(unit @t)  bind:m  (fetch-follow url)
  ?~  bod  (pure:m ['' 0])
  =/  store=road:tarball  (nex-road:io rail [%& /store (store-name url)])
  ;<  old-view=view:nexus  bind:m  (peek:io store `[/ %feed])
  =/  old-items=(list item:rss)
    ?.  ?=([%file *] old-view)  ~
    ?:  (is-boom:tarball sang.old-view)  ~
    items:!<(feed-store:rss (need-vase:tarball sang.old-view))
  ;<  now=@da  bind:m  get-time:io
  =/  res=(unit result:rss)
    (parse:rss q.parser-wasm url u.bod (turn old-items |=(it=item:rss link.it)))
  ?~  res  (pure:m ['' 0])
  =/  fresh=(list item:rss)  (flatten:rss u.res now)
  =/  old-guids=(set @t)  (silt (turn old-items |=(it=item:rss guid.it)))
  =/  new-items=(list item:rss)
    (skip fresh |=(it=item:rss (~(has in old-guids) guid.it)))
  =/  title=@t
    =/  t=@t  (result-title:rss u.res)
    ?:(=('' t) url t)
  =/  fs=feed-store:rss  [url title now (scag 200 (weld new-items old-items))]
  ;<  ~  bind:m  (over:io store [[/ %feed] fs])
  (pure:m [title (lent new-items)])
::  +fetch-follow: GET a url, following up to 3 redirects
::
++  fetch-follow
  |=  url=@t
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  =/  hops=@ud  3
  |-
  ;<  ~  bind:m  (send-request:io [%'GET' url ~ ~])
  ;<  resp=client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.resp)  (pure:m ~)
  =/  code=@ud  status-code.response-header.resp
  ?:  &((gte code 300) (lth code 400))
    ?:  =(0 hops)  (pure:m ~)
    =/  loc=(unit @t)  (get-header:http 'location' headers.response-header.resp)
    ?~  loc  (pure:m ~)
    $(url u.loc, hops (dec hops))
  ?:  (gte code 400)  (pure:m ~)
  ?~  full-file.resp  (pure:m ~)
  (pure:m `q.data.u.full-file.resp)
--
