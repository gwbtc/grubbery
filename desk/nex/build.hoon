::  build nexus: compile hoon sources, cache by content hash
::
::  Layout:
::    /bin/<name>.temp     success: compiled vase
::    /bin/<name>.tang     failure: compile errors
::    /keys.keys       cache key map for reconstruction
::    /src/**              hoon source files
::    /builder.sig         live builder process
::
::  On load: ensure structure, sync build, create builder process.
::  Builder watches /src/ and rebuilds on change.
::  %temp files vanish on kelvin change → full rebuild.
::
/+  nexus, tarball, build, io=fiberio
!:
=>  |%
    ::  Reconstruct build-cache from /bin/ vases + keys
    ::
    ++  ball-to-cache
      |=  [bin=ball:tarball keys=(map rail:tarball @uv)]
      ^-  build-cache:build
      %+  roll  ~(tap by keys)
      |=  [[=rail:tarball ckey=@uv] acc=build-cache:build]
      ?:  (~(has by acc) ckey)  acc
      =/  stem=@ta  (strip-hoon:build name.rail)
      =/  bin-name=@ta  (crip "{(trip stem)}.temp")
      =/  entry=(unit content:tarball)
        (~(get ba:tarball bin) [path.rail bin-name])
      ?~  entry  acc
      (~(put by acc) ckey q.cage.u.entry)
    ::  Ensure a directory exists, creating if needed
    ::
    ++  ensure-dir
      |=  dir=path
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      ;<  exists=?  bind:m  (peek-exists:io /chk [%| 0 %| dir])
      ?:  exists  (pure:m ~)
      (make:io /mkd [%| 0 %| dir] &+[*sand:nexus *gain:nexus [`[~ ~ ~] ~]])
    ::  Write a file, cull-and-recreate if it already exists
    ::
    ++  write-file
      |=  [dir=path =road:tarball =cage]
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      ;<  exists=?  bind:m  (peek-exists:io /chk road)
      ?:  exists
        ;<  ~  bind:m  (cull:io /build road)
        (make:io /build road |+[%.n cage ~])
      ;<  ~  bind:m  (ensure-dir dir)
      (make:io /build road |+[%.n cage ~])
    ::  Write a single build result to /bin/
    ::  Success: <name>.temp (compiled vase)
    ::  Failure: <name>.tang (error)
    ::
    ++  write-result
      |=  [=rail:tarball =build-result:build]
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      =/  stem=@ta  (strip-hoon:build name.rail)
      =/  bin-path=path  (weld /bin path.rail)
      ?:  ?=(%& -.build-result)
        =/  bin-name=@ta  (crip "{(trip stem)}.temp")
        (write-file bin-path [%| 0 %& bin-path bin-name] temp+p.build-result)
      =/  bin-name=@ta  (crip "{(trip stem)}.tang")
      (write-file bin-path [%| 0 %& bin-path bin-name] tang+!>(p.build-result))
    ::  Write all build results
    ::
    ++  write-results
      |=  results=(map rail:tarball build-result:build)
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      =/  entries=(list [=rail:tarball =build-result:build])
        ~(tap by results)
      |-
      ?~  entries  (pure:m ~)
      ;<  ~  bind:m  (write-result i.entries)
      $(entries t.entries)
    ::  Clean stale /bin/ entries not in current results
    ::  Also culls the opposite type when success/failure flips
    ::
    ++  clean-bin
      |=  [bin-ball=ball:tarball results=(map rail:tarball build-result:build)]
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      =/  expected=(set rail:tarball)
        %-  ~(gas in *(set rail:tarball))
        %+  turn  ~(tap by results)
        |=  [=rail:tarball =build-result:build]
        =/  stem=@ta  (strip-hoon:build name.rail)
        =/  ext=tape  ?:(?=(%& -.build-result) ".temp" ".tang")
        [path.rail (crip "{(trip stem)}{ext}")]
      =/  files=(list [=rail:tarball =content:tarball])
        ~(tap ba:tarball bin-ball)
      |-
      ?~  files  (pure:m ~)
      ?:  (~(has in expected) rail.i.files)
        $(files t.files)
      ;<  ~  bind:m
        (cull:io /cln [%| 0 %& (weld /bin path.rail.i.files) name.rail.i.files])
      $(files t.files)
    ::  Purge files in /src/ that aren't %hoon mark with .hoon extension
    ::
    ++  purge-src
      |=  =ball:tarball
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      =/  files=(list [=rail:tarball =content:tarball])
        ~(tap ba:tarball ball)
      |-
      ?~  files  (pure:m ~)
      =/  bad=?
        ?|  !=(p.cage.content.i.files %hoon)
            !(has-hoon-ext:build name.rail.i.files)
        ==
      ?.  bad  $(files t.files)
      ~&  >  [%purge-src rail.i.files]
      ;<  ~  bind:m
        (cull:io /purge [%| 0 %& (weld /src path.rail.i.files) name.rail.i.files])
      $(files t.files)
    ::  Run a full build cycle: load cache, build, write results, clean stale
    ::
    ++  do-build
      |=  src-view=view:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      ?.  ?=([%ball *] src-view)  (pure:m ~)
      =/  src-ball=ball:tarball  ball.src-view
      ::  Purge non-hoon files from /src/
      ;<  ~  bind:m  (purge-src src-ball)
      ::  Load existing state from /bin/ and keys
      ;<  bin-seen=seen:nexus  bind:m  (peek:io /bin [%| 0 %| /bin] ~)
      =/  bin-ball=ball:tarball
        ?.  ?=([%& %ball *] bin-seen)  *ball:tarball
        ball.p.bin-seen
      ;<  km-seen=seen:nexus  bind:m
        (peek:io /km [%| 0 %& / %'keys.keys'] ~)
      =/  keys=(map rail:tarball @uv)
        ?.  ?=([%& %file *] km-seen)  ~
        !<((map rail:tarball @uv) q.cage.p.km-seen)
      =/  old-cache=build-cache:build  (ball-to-cache bin-ball keys)
      ::  Build
      =/  res=build-out:build
        (build-all:build !>(..zuse) src-ball old-cache)
      ~&  >  [%build-done results=~(wyt by results.res)]
      ::  Write all results to /bin/ (.temp or .tang)
      ;<  ~  bind:m  (write-results results.res)
      ::  Write keys
      ;<  ~  bind:m
        (write-file / [%| 0 %& / %'keys.keys'] keys+!>(keys.res))
      ::  Clean stale /bin/ entries
      (clean-bin [bin-ball results.res])
    --
^-  nexus:nexus
|%
++  on-load
  |=  [=sand:nexus =gain:nexus =ball:tarball]
  ^-  [sand:nexus gain:nexus ball:tarball]
  ::  Ensure directories exist
  =?  ball  =(~ (~(get of ball) /bin))
    (~(put of ball) /bin [~ ~ ~])
  =?  ball  =(~ (~(get of ball) /src))
    (~(put of ball) /src [~ ~ ~])
  ::  Seed sample sources if empty
  =?  ball  =(~ (~(get ba:tarball ball) [/src/lib %'add1.hoon']))
    (~(put ba:tarball ball) [/src/lib %'add1.hoon'] [~ %hoon !>('|=(a=@ +(a))')])
  =?  ball  =(~ (~(get ba:tarball ball) [/src %'main.hoon']))
    (~(put ba:tarball ball) [/src %'main.hoon'] [~ %hoon !>('/<  add1  /lib/add1.hoon\0a(add1 41)')])
  ::  Sync build on load
  =/  keys=(map rail:tarball @uv)
    =/  entry=(unit content:tarball)
      (~(get ba:tarball ball) [/ %'keys.keys'])
    ?~  entry  ~
    !<((map rail:tarball @uv) q.cage.u.entry)
  =/  bin-ball=ball:tarball
    (fall (~(dap ba:tarball ball) /bin) *ball:tarball)
  =/  old-cache=build-cache:build  (ball-to-cache bin-ball keys)
  =/  src-ball=ball:tarball
    (fall (~(dap ba:tarball ball) /src) *ball:tarball)
  =/  res=build-out:build
    (build-all:build !>(..zuse) src-ball old-cache)
  ::  Clear /bin/ for fresh write
  =.  ball  (~(put of ball) /bin [~ ~ ~])
  ::  Store results in /bin/: .temp for success, .tang for failure
  =.  ball
    %+  roll  ~(tap by results.res)
    |=  [[=rail:tarball =build-result:build] acc=_ball]
    =/  stem=@ta  (strip-hoon:build name.rail)
    =/  bin-path=path  (weld /bin path.rail)
    =?  acc  =(~ (~(get of acc) bin-path))
      (~(put of acc) bin-path [~ ~ ~])
    ?:  ?=(%& -.build-result)
      =/  bin-name=@ta  (crip "{(trip stem)}.temp")
      (~(put ba:tarball acc) [bin-path bin-name] [~ %temp p.build-result])
    =/  bin-name=@ta  (crip "{(trip stem)}.tang")
    (~(put ba:tarball acc) [bin-path bin-name] [~ %tang !>(p.build-result)])
  ::  Store keys
  =.  ball
    (~(put ba:tarball ball) [/ %'keys.keys'] [~ %keys !>(keys.res)])
  ::  Create builder process
  =?  ball  =(~ (~(get ba:tarball ball) [/ %'builder.sig']))
    (~(put ba:tarball ball) [/ %'builder.sig'] [~ %sig !>(~)])
  [sand gain ball]
::
++  on-file
  |=  [=rail:tarball =mark]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
      [~ %'builder.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%build /builder: failed")
    ~&  >  "%build /builder: starting"
    ::  Subscribe to /src/ for live changes
    ;<  src-view=view:nexus  bind:m
      (keep:io /src [%| 0 %| /src] ~)
    ::  Initial build (will be all cache hits if on-load already built)
    ;<  ~  bind:m  (do-build src-view)
    ~&  >  "%build /builder: watching for changes"
    |-
    ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /src)
    ?:  ?=(%wake -.nw)  $
    ~&  >  "%build /builder: source changed, rebuilding"
    ;<  ~  bind:m  (do-build view.nw)
    $
  ==
--
