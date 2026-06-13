::  mirror nexus: sync a single remote or local source into /data/
::
::  config.json holds the source path as a JSON string:
::    "~nec/apps/counter.counter/counters"   (remote)
::    "/apps/notes"                           (local)
::
::  main.sig subscribes to source, mirrors into /data/.
::
=<  ^-  nexus:nexus
    |%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  =/  =ver:loader  (get-ver:loader ball)
  ?+  ver  !!
      ?(~ [~ %0])
    %+  spin:loader  ball
    :~  (ver-row:loader 0)
        [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
        [%fall %& [/ %'config.json'] [[/ %json] s+'']]
        [%fall %| /data empty-dir:loader]
    ==
  ==
++  on-manu
  |=  =mana:nexus
  ^-  @t
  'Mirror nexus: sync a single source into /data/.'
++  on-file
  |=  [=rail:tarball =blot:tarball]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+  rail  stay:m
      [~ %'main.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%mirror main: failed")
    =/  cfg-road=road:tarball  [%| 0 %& / %'config.json']
    ;<  =seen:nexus  bind:m  (peek:io cfg-road `[/ %json])
    ?.  ?=([%& %file *] seen)
      ~&  >>  %mirror-no-config
      stay:m
    =/  config=json  !<(json (need-vase:tarball sang.p.seen))
    ?.  ?=(%s -.config)
      ~&  >>  %mirror-config-not-string
      stay:m
    ?:  =('' p.config)
      ~&  >  %mirror-no-source-configured
      stay:m
    =/  source-road=road:tarball  (parse-source p.config)
    ~&  >  [%mirror-starting p.config]
    ;<  init=wave:nexus  bind:m  (keep:io /src source-road ~)
    ~&  >  [%mirror-subscribed p.config]
    ::  initial sync: diff against empty wave
    ;<  ~  bind:m  (sync-changes source-road *wave:nexus init)
    =/  prev=wave:nexus  init
    |-
    ;<  wav=wave:nexus  bind:m  (take-news:io /src)
    ~&  >  %mirror-update
    ;<  ~  bind:m  (sync-changes source-road prev wav)
    =.  prev  wav
    $
  ==
--
|%
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
  ~&  >  [%mirror-changes (lent lanes)]
  |-
  ?~  lanes  (pure:m ~)
  =/  =lane:tarball  lane.i.lanes
  ?:  ?=(%| -.lane)
    ::  skip directory-level fold changes
    $(lanes t.lanes)
  ::  file lane: peek source, over into /data/
  =/  base=path
    ?:  ?=([%& %| *] source-road)  p.p.source-road
    ?:  ?=([%| * %| *] source-road)  p.q.p.source-road
    ~|(%mirror-unexpected-road-shape !!)
  =/  src-road=road:tarball  [%& %& (weld base path.p.lane) name.p.lane]
  =/  dest-road=road:tarball  [%| 0 %& (weld /data path.p.lane) name.p.lane]
  ;<  =seen:nexus  bind:m  (peek:io src-road ~)
  ?.  ?=([%& %file *] seen)
    ~&  >>  [%mirror-file-not-found lane]
    ::  file was deleted — cull it from /data/
    ;<  *  bind:m  (cull-soft:io dest-road)
    $(lanes t.lanes)
  ~&  >  [%mirror-syncing-file name.p.lane]
  ;<  ~  bind:m  (over:io dest-road [p.sang.p.seen (sang-noun:tarball sang.p.seen)])
  $(lanes t.lanes)
--
