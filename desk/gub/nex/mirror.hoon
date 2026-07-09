::  mirror nexus: sync a single remote or local source into /data/
::
::  main.json holds the source config as a JSON string:
::    "~nec/apps/counter.counter/counters"   (remote)
::    "/apps/notes"                           (local)
::
::  Poke main.json to change source. The fiber drops the current
::  subscription and re-subscribes to the new one.
::
/&  man  ../man/mirror/readme.md
=<  ^-  nexus:nexus
    |%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  %+  spin:loader  ball
  :~  (manifest:loader 0)
      [%fall %& [/ %'main.json'] [[/ %json] s+'']]
      [%fall %| /data empty-dir:loader]
      [%over %& [/man %'readme.md'] [[/ %mime] man]]
  ==
++  on-file
  |=  [=rail:tarball =blot:tarball]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+  rail  stay:m
      [~ %'main.json']
    ;<  ~  bind:m  (rise-wait:io prod "%mirror main: failed")
    |-
    ;<  config=json  bind:m  (get-state-as:io ,json)
    ?.  ?=(%s -.config)
      ~&  >  %mirror-no-source-configured
      ;<  =sage:tarball  bind:m  take-poke:io
      =/  new-config=json  !<(json q.sage)
      ~&  >  [%mirror-poke-received new-config]
      ;<  ~  bind:m  (replace:io new-config)
      $
    =/  source-road=road:tarball  (parse-source p.config)
    ~&  >  [%mirror-subscribing p.config]
    ;<  init=wave:nexus  bind:m  (keep:io /src source-road ~)
    ~&  >  [%mirror-subscribed p.config]
    ::  Initial sync: diff against empty wave
    ;<  ~  bind:m  (sync-changes source-road *wave:nexus init)
    =/  prev=wave:nexus  init
    |-
    ;<  res=news-or-poke  bind:m  (take-news-or-poke /src)
    ?-  -.res
        %news
      ~&  >  %mirror-update
      ;<  ~  bind:m  (sync-changes source-road prev wave.res)
      $(prev wave.res)
        %poke
      ::  Config change: replace state, drop old sub, restart
      =/  new-config=json  !<(json q.sage.res)
      ~&  >  [%mirror-config-change new-config]
      ;<  ~  bind:m  (replace:io new-config)
      ;<  ~  bind:m  (drop:io /src source-road)
      ~&  >  [%mirror-dropped p.config]
      ^$
    ==
  ==
--
|%
+$  news-or-poke
  $%  [%news =wave:nexus]
      [%poke =sage:tarball]
  ==
++  take-news-or-poke
  |=  news-wire=wire
  =/  m  (fiber:fiber:nexus ,news-or-poke)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in)]
      [~ %news * *]
    ?.  =(news-wire wire.u.in)
      [%skip ~]
    [%done %news wave.u.in]
      [~ %poke * *]
    [%done %poke sage.u.in]
  ==
++  parse-source
  |=  src=@t
  ^-  road:tarball
  ?:  =('~' (end 3 src))
    =/  txt=tape  (trip src)
    =/  ship-end=@  (need (find "/" txt))
    =/  target=@p  (slav %p (crip (scag ship-end txt)))
    =/  source-path=path  (stab (crip (slag ship-end txt)))
    [%& %| (weld /sys/ames/ships/[(scot %p target)]/root source-path)]
  [%& %| (stab src)]
::
++  sync-changes
  |=  [source-road=road:tarball prev=wave:nexus cur=wave:nexus]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  changes=(map lane:tarball cass:clay)  (diff-wave:nexus prev cur)
  =/  lanes=(list [=lane:tarball =cass:clay])  ~(tap by changes)
  ~&  >  [%mirror-changes (lent lanes) lanes=lanes]
  |-
  ?~  lanes  (pure:m ~)
  =/  =lane:tarball  lane.i.lanes
  ?:  ?=(%| -.lane)
    $(lanes t.lanes)
  =/  base=path
    ?:  ?=([%& %| *] source-road)  p.p.source-road
    ?:  ?=([%| * %| *] source-road)  p.q.p.source-road
    ~|(%mirror-unexpected-road-shape !!)
  =/  src-road=road:tarball  [%& %& (weld base path.p.lane) name.p.lane]
  =/  dest-road=road:tarball  [%| 0 %& (weld /data path.p.lane) name.p.lane]
  ;<  =seen:nexus  bind:m  (peek:io src-road ~)
  ?.  ?=([%& %file *] seen)
    ~&  >>  [%mirror-file-not-found lane]
    ;<  *  bind:m  (cull-soft:io dest-road)
    $(lanes t.lanes)
  ~&  >  [%mirror-syncing-file name.p.lane blot=p.sang.p.seen src-road dest-road]
  ;<  ~  bind:m  (over:io dest-road [p.sang.p.seen (sang-noun:tarball sang.p.seen)])
  $(lanes t.lanes)
--
