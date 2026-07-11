::  desk nexus: sync code from a remote source with checkpoint safety
::
::  config.json holds source as JSON string:
::    "~nec/apps/counter"    (remote ship)
::    "/some/local/path"     (local namespace)
::
::  Layout — host/guest split:
::    config.json     source config            (host, root-governed)
::    version.ud      release version          (host)
::    main.sig        HTTP UI                  (host)
::    /requests/      HTTP request grubs       (host)
::    /desk/code/     %code nexus synced from source — governs the
::                    guest world and nothing else
::    /desk/init/     publisher-recommended initial data (synced,
::                    published, checkpointed with releases; applied
::                    to /desk/data automatically on first install —
::                    i.e. only when /desk/data is empty)
::    /desk/data/     working data for the installed desk
::
::  The host layer resolves marcs from the root code namespace; the
::  guest resolves against /desk/code. Guests distribute every marc
::  they use — content-addressing dedupes shared marcs for free.
::
::  Checkpoints live entirely in the born history. Before each code
::  update the fold hists of /data and /code (plus version.ud) are
::  firmed and tagged with the outgoing version — the fold pace lobe
::  IS the merkle root of the subtree at that instant. One hash per
::  axis per version; no manifest files.
::
::  Restore materializes any historical /data x /code pair:
::  /code is nullified first (world stops — /data goes inert),
::  then /data loads, then /code loads and everything comes alive.
::
::  Future: this could extend to a repo nexus. The content store
::  gives you dedup (silo lobes) and history (hist). But real
::  commits need a merkle DAG — each commit hashes over parent +
::  tree, not just firm entries. Would need a commit object type
::  (parent hash, tree hash, message, author @p, signature)
::  layered on top of the born tree, not replacing it.
::
/&  man  ../man/desk/readme.md
=<  ^-  nexus:nexus
    |%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  =/  code-dir=bole:tarball  [`[`[/ %code] ~ %.n ~] ~]
  %+  spin:loader  ball
  :~  (manifest:loader 0)
      [%fall %& [/ %'config.json'] [[/ %json] (config-to-json *desk-config)]]
      [%fall %& [/ %'version.ud'] [[/ %ud] 0]]
      [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
      [%fall %| /requests empty-dir:loader]
      [%fall %| /desk empty-dir:loader]
      [%fall %| /desk/code code-dir]
      [%fall %| /desk/init empty-dir:loader]
      [%fall %| /desk/data empty-dir:loader]
      [%over %& [/ %'README.md'] [[/ %mime] man]]
  ==
::
++  on-file
  |=  [=rail:tarball =blot:tarball]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
      ::  config.json: watch remote source, sync code on updates
      ::
      [~ %'config.json']
    ;<  ~  bind:m  (rise-wait:io prod "%desk config: failed")
    ;<  ~  bind:m  reg-register:io
    ;<  here=rail:tarball  bind:m  get-here-abs:io
    =/  nex-dir=path  path.here
    |-
    ;<  config-json=json  bind:m  (get-state-as:io ,json)
    =/  config=desk-config  (json-to-config config-json)
    ;<  ~  bind:m
      %-  reg-how:io
      ?:  &(public.config ?=(~ source.config))
        :-  /public
        :+  ~  ~
        %-  sy
        :~  [%& %& nex-dir %'version.ud']
            [%& %| (weld nex-dir /desk/code)]
            [%& %| (weld nex-dir /desk/init)]
        ==
      [/public *weir:nexus]
    ?~  source.config
      ::  no source configured, wait for poke
      ~&  >  %desk-no-source
      ;<  =sage:tarball  bind:m  take-poke:io
      =/  new-json=json  !<(json q.sage)
      ;<  ~  bind:m  (replace:io new-json)
      $
    ::  subscribe to source's version.ud
    =/  source-road=road:tarball  (parse-source u.source.config)
    =/  ver-road=road:tarball  (version-road source-road)
    ~&  >  [%desk-subscribing u.source.config]
    ;<  init=wave:nexus  bind:m  (keep:io /ver ver-road `[/ %ud])
    ~&  >  [%desk-subscribed u.source.config]
    ::  install: sync the source's release (pinned, never live),
    ::  apply init on first install (empty /desk/data), and
    ::  checkpoint the installed world under its version — the
    ::  version watcher only fires on version CHANGES, and an
    ::  install of the source's current version isn't one.
    ;<  ~  bind:m  (sync-release source-road rail)
    ;<  ~  bind:m  (apply-init rail)
    ;<  ver=(unit @ud)  bind:m
      (peek-as:io (nex-road:io rail [%& / %'version.ud']) ,@ud)
    ;<  ~  bind:m
      (do-checkpoint rail (sy ~['checkpoint' (version-tag (fall ver 0))]))
    |-
    ;<  res=news-or-poke  bind:m  (take-news-or-poke /ver)
    ?-  -.res
        %news
      ~&  >  %desk-update-received
      ::  checkpoint outgoing state, then sync. Plain 'checkpoint'
      ::  tag — version tags are the version.ud watcher's job.
      ;<  ~  bind:m  (do-checkpoint rail (sy ~['checkpoint']))
      ;<  ~  bind:m  (sync-release source-road rail)
      $
        %poke
      ::  config change: replace state, drop sub, restart
      =/  new-json=json  !<(json q.sage.res)
      ~&  >  [%desk-config-change new-json]
      ;<  ~  bind:m  (replace:io new-json)
      ;<  ~  bind:m  (drop:io /ver ver-road)
      ^$
    ==
      ::  version.ud: every version change checkpoints the world.
      ::  Runs on publisher and subscriber alike — a release IS a
      ::  checkpoint, tagged with the version it inaugurates.
      ::
      [~ %'version.ud']
    ;<  ~  bind:m  (rise-wait:io prod "%desk version: failed")
    ::  checkpoint the current version at rise: gives every desk a
    ::  v0 checkpoint at birth (idempotent re-firm on later rises)
    ;<  ver0=(unit @ud)  bind:m
      (peek-as:io (nex-road:io rail [%& / %'version.ud']) ,@ud)
    ;<  ~  bind:m
      (do-checkpoint rail (sy ~['checkpoint' (version-tag (fall ver0 0))]))
    ;<  init=wave:nexus  bind:m
      (keep:io /self (nex-road:io rail [%& / %'version.ud']) `[/ %ud])
    |-
    ;<  res=news-or-poke  bind:m  (take-news-or-poke /self)
    ?-  -.res
        %poke  $
        %news
      ;<  ver=(unit @ud)  bind:m
        (peek-as:io (nex-road:io rail [%& / %'version.ud']) ,@ud)
      ;<  ~  bind:m
        (do-checkpoint rail (sy ~['checkpoint' (version-tag (fall ver 0))]))
      $
    ==
      ::  main.sig: HTTP endpoint for desk management UI
      ::
      [~ %'main.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%desk /main: failed")
    ;<  here=rail:tarball  bind:m  get-here-abs:io
    ::  Bind /grubbery/desk/<slug> — dot-free (eyre mangles dotted
    ::  segments) and short: the nexus dir name minus its suffix.
    ::  Public exposure is the config fiber's job.
    ;<  ~  bind:m  (bind-http:io [~ /grubbery/desk/[(desk-slug path.here)]])
    (http-dispatch:io %desk)
      ::  /requests/*: individual HTTP request handlers
      ::
      [[%requests ~] @]
    ;<  ~  bind:m  (rise-wait:io prod "%desk /requests: failed")
    =/  eyre-id=@ta  name.rail
    ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
    ;<  here=rail:tarball  bind:m  get-here-abs:io
    ;<  our=@p  bind:m  get-our:io
    ?.  =(src our)
      ;<  ~  bind:m  (respond eyre-id rail 403 'Forbidden')
      (pure:m ~)
    =/  nex-path=path  (snip path.here)  :: /foo/requests -> /foo
    =/  prefix=path  /grubbery/desk/[(desk-slug nex-path)]
    =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
    =/  suffix=path  (slag (lent prefix) site)
    ?:  =('POST' method.request.req)
      (handle-post eyre-id suffix req rail)
    (handle-get eyre-id suffix rail)
  ==
--
::
|%
+$  desk-config
  $:  source=(unit @t)
      public=?
  ==
::
+$  news-or-poke
  $%  [%news =wave:nexus]
      [%poke =sage:tarball]
  ==
::  a file lifted out of a ball, addressed relative to the peeked dir
::
+$  bfile  [pax=path name=@ta =sang:tarball]
::  born hist metadata, as returned by born:io
::
+$  binfo  (list [=cass:clay tags=(set @t) tomb=?])
::
++  config-to-json
  |=  config=desk-config
  ^-  json
  %-  pairs:enjs:format
  :~  ['source' ?~(source.config ~ s+u.source.config)]
      ['public' b+public.config]
  ==
::
++  json-to-config
  |=  =json
  ^-  desk-config
  ?.  ?=(%o -.json)  *desk-config
  =/  src  (~(get by p.json) 'source')
  =/  pub  (~(get by p.json) 'public')
  :*  ?~(src ~ ?:(?=([~ %s *] src) `p.u.src ~))
      ?~(pub %.n ?:(?=([~ %b *] pub) p.u.pub %.n))
  ==
::
::  desk-slug: URL name for a desk nexus — its dir name minus the
::  dot-suffix ('test.desk' -> 'test'). Dots are avoided in eyre
::  bindings: eyre parses them as file extensions during matching.
::
++  desk-slug
  |=  nex=path
  ^-  @ta
  ?~  nex  %$
  =/  nam=tape  (trip (rear nex))
  =/  dix=(unit @ud)  (find "." nam)
  ?~  dix  (crip nam)
  (crip (scag u.dix nam))
::
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
::  version-road: source's version.ud road from base source road
::
++  version-road
  |=  source-road=road:tarball
  ^-  road:tarball
  ?.  ?=([%& %| *] source-road)  ~|(%desk-unexpected-road-shape !!)
  [%& %& p.p.source-road %'version.ud']
::  source-dir-road: a directory under the source desk
::
++  source-dir-road
  |=  [source-road=road:tarball dir=path]
  ^-  road:tarball
  ?.  ?=([%& %| *] source-road)  ~|(%desk-unexpected-road-shape !!)
  [%& %| (weld p.p.source-road dir)]
::  sync-release: mirror the source's RELEASE, never its live tree.
::  The source's version.ud revision pins the release instant — its
::  cass carries the da when version N was written, and the source's
::  watcher checkpointed (firmed) the folds in that same event chain.
::  Syncing the folds at that da makes drafts unreachable and every
::  sync reproducible. Also writes the local version.ud to match.
::
++  sync-release
  |=  [source-road=road:tarball =rail:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ver-seen=seen:nexus  bind:m
    (peek:io (version-road source-road) `[/ %ud])
  ?.  ?=([%& %file *] ver-seen)
    ~&  >>  %desk-no-version-at-source
    (pure:m ~)
  =/  ver=@ud  !<(@ud (need-vase:tarball sang.p.ver-seen))
  =/  at=@da   da.cass.p.ver-seen
  ~&  >  [%desk-sync-release ver=ver]
  ;<  ~  bind:m
    (sync-dir (source-dir-road source-road /desk/code) rail /desk/code `[%da at])
  ;<  ~  bind:m
    (sync-dir (source-dir-road source-road /desk/init) rail /desk/init `[%da at])
  (over:io (nex-road:io rail [%& / %'version.ud']) [[/ %ud] ver])
::
::  apply-init: on first install only — if /desk/data is empty,
::  populate it from the publisher's synced /desk/init. Data with
::  any contents is never touched (restarts, re-subscribes, toggles).
::
++  apply-init
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(unit (list bfile))  bind:m  (fetch-dir rail /desk/data ~)
  ?.  =(~ (fall cur ~))  (pure:m ~)
  ;<  init-files=(unit (list bfile))  bind:m  (fetch-dir rail /desk/init ~)
  =/  files=(list bfile)  (fall init-files ~)
  ?:  =(~ files)  (pure:m ~)
  ~&  >  [%desk-init-data (lent files)]
  (write-files rail /desk/data files)
::
++  sync-dir
  |=  [source-dir=road:tarball =rail:tarball dir=path cas=(unit case:nexus)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =seen:nexus  bind:m
    ?~  cas  (peek:io source-dir ~)
    (peek-at:io source-dir ~ u.cas)
  ?.  ?=([%& %ball *] seen)
    ~&  >>  [%desk-nothing-at-source dir]
    (pure:m ~)
  =/  files=(list bfile)  (ball-to-files ball.p.seen)
  ~&  >  [%desk-sync-files dir (lent files)]
  (write-files rail dir files)
::
::  do-checkpoint: firm the fold hists of /data and /code plus
::  version.ud, tagged with the outgoing version. The fold pace
::  lobe is the merkle root of the whole subtree — three firms
::  checkpoint the entire world.
::
++  do-checkpoint
  |=  [=rail:tarball tags=(set @t)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ~&  >  [%desk-checkpoint tags=tags]
  ;<  ~  bind:m  (checkpoint:io (nex-road:io rail [%| /desk/data]))
  ;<  ~  bind:m  (tag:io (nex-road:io rail [%| /desk/data]) ~ tags)
  ;<  ~  bind:m  (checkpoint:io (nex-road:io rail [%| /desk/code]))
  ;<  ~  bind:m  (tag:io (nex-road:io rail [%| /desk/code]) ~ tags)
  ;<  ~  bind:m  (checkpoint:io (nex-road:io rail [%| /desk/init]))
  ;<  ~  bind:m  (tag:io (nex-road:io rail [%| /desk/init]) ~ tags)
  ;<  ~  bind:m  (checkpoint:io (nex-road:io rail [%& / %'version.ud']))
  (tag:io (nex-road:io rail [%& / %'version.ud']) ~ tags)
::
++  version-tag
  |=  ver=@ud
  ^-  @t
  (crip "v{(a-co:co ver)}")
::
::  ball-to-files: lift files out of a ball with relative paths
::
++  ball-to-files
  |=  =ball:tarball
  ^-  (list bfile)
  =|  base=path
  |-  ^-  (list bfile)
  =/  here=(list bfile)
    ?~  fil.ball  ~
    %+  turn  ~(tap by contents.u.fil.ball)
    |=  [name=@ta =sang:tarball gain=? bang=(unit tang)]
    [base name sang]
  %-  weld  :-  here
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.ball)
  |-  ^-  (list bfile)
  ?~  kids  ~
  %-  weld  :_  $(kids t.kids)
  ^$(ball +.i.kids, base (snoc base -.i.kids))
::
::  fetch-dir: read a dir's files — live, or at a historical case
::
++  fetch-dir
  |=  [=rail:tarball dir=path cas=(unit case:nexus)]
  =/  m  (fiber:fiber:nexus ,(unit (list bfile)))
  ^-  form:m
  ;<  =seen:nexus  bind:m
    ?~  cas  (peek:io (nex-road:io rail [%| dir]) ~)
    (peek-at:io (nex-road:io rail [%| dir]) ~ u.cas)
  ?.  ?=([%& %ball *] seen)  (pure:m ~)
  (pure:m `(ball-to-files ball.p.seen))
::
::  write-files: over a list of bfiles into a dir
::
++  write-files
  |=  [=rail:tarball dir=path files=(list bfile)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ?~  files  (pure:m ~)
  ?:  (is-boom:tarball sang.i.files)
    ~&  >>  [%desk-skip-boom pax.i.files name.i.files]
    $(files t.files)
  ;<  ~  bind:m
    %+  over:io
      (nex-road:io rail [%& (weld dir pax.i.files) name.i.files])
    [p.sang.i.files (sang-noun:tarball sang.i.files)]
  $(files t.files)
::
::  cull-dir: remove all current files under a dir (dir survives)
::
++  cull-dir
  |=  [=rail:tarball dir=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(unit (list bfile))  bind:m  (fetch-dir rail dir ~)
  =/  files=(list bfile)  (fall cur ~)
  |-
  ?~  files  (pure:m ~)
  ;<  err=(unit tang)  bind:m
    (cull-soft:io (nex-road:io rail [%& (weld dir pax.i.files) name.i.files]))
  $(files t.files)
::
::  do-restore: materialize a historical /data x /code pair.
::  Fetches everything into memory first — no mutation until both
::  targets are resolved. Then: nullify /code (world stops), load
::  /data, load /code (world starts).
::
++  do-restore
  |=  [eyre-id=@ta body=@t =rail:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  jon=(unit json)  (de:json:html body)
  =/  want-data=(unit @ud)
    ?.  &(?=(^ jon) ?=(%o -.u.jon))  ~
    (json-num (~(get by p.u.jon) 'data'))
  =/  want-code=(unit @ud)
    ?.  &(?=(^ jon) ?=(%o -.u.jon))  ~
    (json-num (~(get by p.u.jon) 'code'))
  ?:  &(?=(~ want-data) ?=(~ want-code))
    ;<  ~  bind:m  (respond eyre-id rail 400 'nothing to restore')
    (pure:m ~)
  ~&  >  [%desk-restore data=want-data code=want-code]
  ::  the numbers are fold REVISIONS (the ud of the hist entry)
  ;<  data-files=(unit (list bfile))  bind:m
    =/  m  (fiber:fiber:nexus ,(unit (list bfile)))
    ?~  want-data  (pure:m ~)
    (fetch-dir rail /desk/data `[%ud u.want-data])
  ;<  code-files=(unit (list bfile))  bind:m
    =/  m  (fiber:fiber:nexus ,(unit (list bfile)))
    ?~  want-code
      ::  keeping current code: snapshot live contents
      ;<  cur=(unit (list bfile))  bind:m  (fetch-dir rail /desk/code ~)
      (pure:m `(fall cur ~))
    (fetch-dir rail /desk/code `[%ud u.want-code])
  ?:  ?|  &(?=(^ want-data) ?=(~ data-files))
          ?=(~ code-files)
      ==
    ;<  ~  bind:m  (respond eyre-id rail 404 'unknown checkpoint revision')
    (pure:m ~)
  ::  1. nullify /desk/code — /desk/data goes inert
  ;<  ~  bind:m  (cull-dir rail /desk/code)
  ::  2. load /desk/data while the world is stopped
  ;<  ~  bind:m
    ?~  data-files  (pure:m ~)
    ;<  ~  bind:m  (cull-dir rail /desk/data)
    (write-files rail /desk/data u.data-files)
  ::  3. load /desk/code — everything comes alive against the new data
  ;<  ~  bind:m  (write-files rail /desk/code (need code-files))
  ~&  >  %desk-restore-done
  (redirect eyre-id rail)
::
++  json-num
  |=  j=(unit json)
  ^-  (unit @ud)
  ?.  ?=([~ %n *] j)  ~
  `(rash p.u.j dem)
::
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
::
::  HTTP handlers
::
++  respond
  |=  [eyre-id=@ta =rail:tarball code=@ud msg=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  %+  ~(send-simple http-res:io (nex-road:io rail [%& ~ %'main.sig']))
    eyre-id
  [[code ~] `(as-octs:mimes:html msg)]
::
++  handle-get
  |=  [eyre-id=@ta suffix=path =rail:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?:  ?=([%tree ?(%code %data) *] suffix)
    ::  file tree of an axis — current, or at a historical revision
    =/  dir=path  ?:(?=(%code i.t.suffix) /desk/code /desk/data)
    =/  cas=(unit case:nexus)
      ?~  t.t.suffix  ~
      =/  n=(unit @ud)  (rush i.t.t.suffix dem)
      ?~(n ~ `[%ud u.n])
    ;<  files=(unit (list bfile))  bind:m  (fetch-dir rail dir cas)
    ?~  files
      ;<  ~  bind:m  (respond eyre-id rail 404 'no tree at that revision')
      (pure:m ~)
    =/  =json
      %-  pairs:enjs:format
      :~  :-  'files'
          :-  %a
          %+  turn  u.files
          |=  f=bfile
          %-  pairs:enjs:format
          :~  ['path' s+(spat pax.f)]
              ['name' s+name.f]
              ['blot' s+(spat (snoc path.p.sang.f name.p.sang.f))]
          ==
      ==
    =/  bod=octs  (as-octs:mimes:html (en:json:html json))
    ;<  ~  bind:m  (~(send-simple http-res:io (nex-road:io rail [%& ~ %'main.sig'])) eyre-id (mime-response:http-utils [/application/json bod]))
    (pure:m ~)
  ?:  =(/state suffix)
    ::  data endpoint: config, version, and both checkpoint lists
    ;<  config-json=(unit json)  bind:m
      (peek-as:io (nex-road:io rail [%& / %'config.json']) ,json)
    ;<  ver=(unit @ud)  bind:m
      (peek-as:io (nex-road:io rail [%& / %'version.ud']) ,@ud)
    ;<  code-born=(each binfo tang)  bind:m
      (born:io (nex-road:io rail [%| /desk/code]))
    ;<  data-born=(each binfo tang)  bind:m
      (born:io (nex-road:io rail [%| /desk/data]))
    =/  =json
      %-  pairs:enjs:format
      :~  ['config' (fall config-json [%o ~])]
          ['version' (numb:enjs:format (fall ver 0))]
          ['code' (binfo-to-json code-born)]
          ['data' (binfo-to-json data-born)]
      ==
    =/  bod=octs  (as-octs:mimes:html (en:json:html json))
    ;<  ~  bind:m  (~(send-simple http-res:io (nex-road:io rail [%& ~ %'main.sig'])) eyre-id (mime-response:http-utils [/application/json bod]))
    (pure:m ~)
  ::  static shell — the page populates itself from /state
  =/  bod=octs  (as-octs:mimes:html (crip (en-xml:html render-page)))
  ;<  ~  bind:m  (~(send-simple http-res:io (nex-road:io rail [%& ~ %'main.sig'])) eyre-id (mime-response:http-utils [/text/html bod]))
  (pure:m ~)
::
::  binfo-to-json: one fold's checkpoint history — only firmed,
::  tagged, live revisions are checkpoints worth listing.
::
++  binfo-to-json
  |=  res=(each binfo tang)
  ^-  json
  :-  %a
  ?:  ?=(%| -.res)  ~
  %+  murn  p.res
  |=  [=cass:clay tags=(set @t) tomb=?]
  ^-  (unit json)
  ?:  tomb  ~
  ?:  =(~ tags)  ~
  :-  ~
  %-  pairs:enjs:format
  :~  ['ud' (numb:enjs:format ud.cass)]
      ['da' (time:enjs:format da.cass)]
      ['tags' a+(turn ~(tap in tags) |=(t=@t s+t))]
  ==
::
++  handle-post
  |=  [eyre-id=@ta suffix=path req=inbound-request:eyre =rail:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  body=@t
    ?~  body.request.req  ''
    q.u.body.request.req
  ?+    suffix
    ;<  ~  bind:m  (respond eyre-id rail 404 'Not found')
    (pure:m ~)
  ::
      [%set-source ~]
    ::  poke config.json — the config fiber picks this up
    ;<  cur-json=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& / %'config.json']) ,json)
    =/  cur=desk-config  ?~(cur-json *desk-config (json-to-config u.cur-json))
    =/  new-config=desk-config  cur(source ?:(=('' body) ~ `body))
    ;<  ~  bind:m
      (poke:io (nex-road:io rail [%& / %'config.json']) [[/ %json] (config-to-json new-config)])
    (redirect eyre-id rail)
  ::
      [%restore ~]
    (do-restore eyre-id body rail)
  ::
      [%publish ~]
    ::  toggle public exposure. Pokes config.json — the config fiber
    ::  replaces its state and re-applies the registry weir.
    ;<  cur-json=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& / %'config.json']) ,json)
    =/  cur=desk-config  ?~(cur-json *desk-config (json-to-config u.cur-json))
    ?:  &(!public.cur ?=(^ source.cur))
      ;<  ~  bind:m  (respond eyre-id rail 400 'cannot publish while subscribed to a source')
      (pure:m ~)
    =/  new-config=desk-config  cur(public !public.cur)
    ~&  >  [%desk-publish public=public.new-config]
    ;<  ~  bind:m
      (poke:io (nex-road:io rail [%& / %'config.json']) [[/ %json] (config-to-json new-config)])
    (respond eyre-id rail 200 ?:(public.new-config 'published' 'unpublished'))
  ::
      [%fetch-latest ~]
    ::  pull the source's current code and version now. Idempotent:
    ::  content-addressed writes no-op when nothing changed, so this
    ::  only creates history when the source actually differs. Also
    ::  the revive lever after clear-contents.
    ;<  config-json=(unit json)  bind:m
      (peek-as:io (nex-road:io rail [%& / %'config.json']) ,json)
    =/  config=desk-config
      ?~(config-json *desk-config (json-to-config u.config-json))
    ?~  source.config
      ;<  ~  bind:m  (respond eyre-id rail 400 'no source configured')
      (pure:m ~)
    =/  source-road=road:tarball  (parse-source u.source.config)
    ~&  >  [%desk-fetch-latest u.source.config]
    ::  protect current state, then pull
    ;<  ~  bind:m  (do-checkpoint rail (sy ~['checkpoint']))
    ;<  ~  bind:m  (sync-release source-road rail)
    ;<  ver=(unit @ud)  bind:m
      (peek-as:io (nex-road:io rail [%& / %'version.ud']) ,@ud)
    ;<  ~  bind:m
      (do-checkpoint rail (sy ~['checkpoint' (version-tag (fall ver 0))]))
    (respond eyre-id rail 200 'fetched')
  ::
      [%checkpoint ~]
    ::  manual checkpoint: firm the current fold state of one axis,
    ::  tagged 'checkpoint' plus an optional user label
    =/  jon=(unit json)  (de:json:html body)
    ?.  &(?=(^ jon) ?=(%o -.u.jon))
      ;<  ~  bind:m  (respond eyre-id rail 400 'bad body')
      (pure:m ~)
    =/  axis  (~(get by p.u.jon) 'axis')
    ?.  ?=([~ %s *] axis)
      ;<  ~  bind:m  (respond eyre-id rail 400 'need axis')
      (pure:m ~)
    =/  label=(unit @t)
      =/  l  (~(get by p.u.jon) 'label')
      ?:(?=([~ %s *] l) ?:(=('' p.u.l) ~ `p.u.l) ~)
    =/  dir=path  ?:(=('code' p.u.axis) /desk/code /desk/data)
    =/  tags=(set @t)
      (sy ?~(label ~['checkpoint'] ~['checkpoint' u.label]))
    ~&  >  [%desk-manual-checkpoint dir=dir label=label]
    ;<  ~  bind:m  (checkpoint:io (nex-road:io rail [%| dir]))
    ;<  ~  bind:m  (tag:io (nex-road:io rail [%| dir]) ~ tags)
    (respond eyre-id rail 200 'checkpointed')
  ::
      [%clear-contents ~]
    ::  cull every file under an axis. Clearing /desk/code is the
    ::  stop-the-world lever: the guest goes inert until code is
    ::  materialized back in.
    =/  jon=(unit json)  (de:json:html body)
    =/  axis
      ?.  &(?=(^ jon) ?=(%o -.u.jon))  ~
      (~(get by p.u.jon) 'axis')
    ?.  ?=([~ %s *] axis)
      ;<  ~  bind:m  (respond eyre-id rail 400 'need axis')
      (pure:m ~)
    =/  dir=path  ?:(=('code' p.u.axis) /desk/code /desk/data)
    ~&  >  [%desk-clear-contents dir=dir]
    ;<  ~  bind:m  (cull-dir rail dir)
    (respond eyre-id rail 200 'cleared')
  ::
      [%clear ~]
    ::  tombstone a checkpoint: drop the fold hist entry (tags and
    ::  silo refs go with it). The runtime refuses the live top.
    =/  jon=(unit json)  (de:json:html body)
    ?.  &(?=(^ jon) ?=(%o -.u.jon))
      ;<  ~  bind:m  (respond eyre-id rail 400 'bad body')
      (pure:m ~)
    =/  axis  (~(get by p.u.jon) 'axis')
    =/  ud=(unit @ud)  (json-num (~(get by p.u.jon) 'ud'))
    ?.  &(?=([~ %s *] axis) ?=(^ ud))
      ;<  ~  bind:m  (respond eyre-id rail 400 'need axis and ud')
      (pure:m ~)
    =/  dir=path  ?:(=('code' p.u.axis) /desk/code /desk/data)
    ~&  >  [%desk-clear dir=dir ud=u.ud]
    ;<  ~  bind:m  (lose:io (nex-road:io rail [%| dir]) [%numb `u.ud `u.ud])
    (respond eyre-id rail 200 'cleared')
  ==
::
++  redirect
  |=  [eyre-id=@ta =rail:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  hed=response-header:http  [303 ~[['location' './']]]
  =/  main-road  (nex-road:io rail [%& ~ %'main.sig'])
  ;<  ~  bind:m  (~(send-header http-res:io main-road) eyre-id hed)
  ;<  ~  bind:m  (~(send-data http-res:io main-road) eyre-id ~)
  (pure:m ~)
::
::
::  HTML rendering
::
++  render-page
  ^-  manx
  ;html
    ;head
      ;title: Desk
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  page-css
      ==
    ==
    ;body
      ;h1: Desk
      ;div(class "section")
        ;h2: Source
        ;div(class "config-form")
          ;input#source-input(type "text", placeholder "~ship/path or /local/path");
          ;button(class "btn btn-grn", onclick "setSource()"): Set Source
          ;button#fetch-btn(class "btn", onclick "fetchLatest()"): Fetch Latest
          ;button#publish-btn(class "btn", onclick "togglePublish()"): ...
        ==
        ;div(class "status")
          ;span(class "label"): Status:
          ;span#status: ...
        ==
        ;div(class "status")
          ;span(class "label"): Version:
          ;span#version: ...
        ==
      ==
      ;div(class "section")
        ;h2: Code Checkpoints
        ;div#code-ckpts
          ;div(class "muted"): loading...
        ==
        ;div(class "config-form")
          ;input#code-label(type "text", placeholder "label (optional)");
          ;button(class "btn btn-grn", onclick "checkpointNow('code')"): Checkpoint Now
          ;button(class "btn btn-red", onclick "clearContents('code')"): Clear Contents
        ==
        ;div#code-tree(class "tree");
      ==
      ;div(class "section")
        ;h2: Data Checkpoints
        ;div#data-ckpts
          ;div(class "muted"): loading...
        ==
        ;div(class "config-form")
          ;input#data-label(type "text", placeholder "label (optional)");
          ;button(class "btn btn-grn", onclick "checkpointNow('data')"): Checkpoint Now
        ==
        ;div#data-tree(class "tree");
      ==
      ;script
        ;+  ;/  page-js
      ==
    ==
  ==
::
++  page-css
  ^-  tape
  ;:  weld
    "* \{ margin:0; padding:0; box-sizing:border-box; }"
    "body \{ font-family:monospace; max-width:600px; margin:0 auto; padding:1.5rem; background:#fafafa; color:#111; font-size:14px; }"
    "h1 \{ font-size:1.3rem; margin-bottom:1rem; }"
    "h2 \{ font-size:1rem; margin-bottom:.5rem; }"
    ".section \{ background:#fff; border:1px solid #ddd; border-radius:6px; padding:.75rem; margin-bottom:.75rem; }"
    ".config-form \{ display:flex; gap:.5rem; margin-bottom:.5rem; }"
    ".config-form input \{ font-family:monospace; font-size:16px; padding:.3rem .5rem; border:1px solid #ccc; border-radius:4px; flex:1; min-width:0; }"
    ".status \{ font-size:.85rem; margin-bottom:.25rem; }"
    ".status .label \{ font-weight:bold; margin-right:.5rem; }"
    ".btn \{ font-family:monospace; font-size:.8rem; padding:.3rem .75rem; border:1px solid #ccc; border-radius:4px; background:#fff; cursor:pointer; }"
    ".btn:hover \{ background:#eee; }"
    ".btn-grn \{ color:#2a2; border-color:#2a2; }"
    ".btn-grn:hover \{ background:#dfd; }"
    ".btn-red \{ color:#c22; border-color:#c22; margin-left:.4rem; }"
    ".btn-red:hover \{ background:#fdd; }"
    ".btn-grn \{ margin-left:.4rem; }"
    ".tree \{ margin-top:.75rem; padding-top:.5rem; border-top:1px solid #ddd; }"
    ".tree-hdr \{ font-size:.75rem; font-weight:bold; color:#666; margin-bottom:.25rem; }"
    ".tree-hdr a \{ color:#26c; margin-left:.5rem; font-weight:normal; }"
    ".tree-row \{ display:flex; justify-content:space-between; font-size:.8rem; padding:.1rem 0; }"
    ".muted \{ color:#999; font-size:.85rem; }"
    ".row \{ display:flex; justify-content:space-between; align-items:center; gap:.5rem; font-size:.85rem; padding:.25rem 0; border-bottom:1px solid #eee; }"
    ".row:last-child \{ border-bottom:none; }"
    ".row-label \{ flex:1; min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }"
    ".btns \{ white-space:nowrap; flex-shrink:0; }"
    ".btns .btn \{ padding:.15rem .45rem; font-size:.7rem; margin-left:.3rem; }"
  ==
::
++  page-js
  ^-  tape
  ;:  weld
    "var BASE=window.location.pathname;"
    "if(!BASE.endsWith('/'))BASE+='/';"
    "function setSource()\{"
    "  var src=document.getElementById('source-input').value.trim();"
    "  fetch(BASE+'set-source',\{method:'POST',body:src}).then(function()\{load()});"
    "}"
    "function materialize(axis,ud)\{"
    "  if(!confirm('Materialize '+axis+' at revision '+ud+'?'))return;"
    "  var body=\{};body[axis]=ud;"
    "  fetch(BASE+'restore',\{method:'POST',body:JSON.stringify(body)})"
    "    .then(function()\{load()});"
    "}"
    "function clearCkpt(axis,ud)\{"
    "  if(!confirm('Clear '+axis+' checkpoint at revision '+ud+'? This frees its storage.'))return;"
    "  fetch(BASE+'clear',\{method:'POST',body:JSON.stringify(\{axis:axis,ud:ud})})"
    "    .then(function()\{load()});"
    "}"
    "function togglePublish()\{"
    "  fetch(BASE+'publish',\{method:'POST'}).then(function()\{load()});"
    "}"
    "function fetchLatest()\{"
    "  fetch(BASE+'fetch-latest',\{method:'POST'})"
    "    .then(function(r)\{if(!r.ok)r.text().then(alert);load()});"
    "}"
    "function clearContents(axis)\{"
    "  if(!confirm('Clear ALL current '+axis+' contents? '+(axis==='code'?'The desk goes inert until code is materialized back.':'Current data is removed.')+' Checkpointed history is untouched.'))return;"
    "  fetch(BASE+'clear-contents',\{method:'POST',body:JSON.stringify(\{axis:axis})})"
    "    .then(function()\{load()});"
    "}"
    "function checkpointNow(axis)\{"
    "  var label=document.getElementById(axis+'-label').value.trim();"
    "  fetch(BASE+'checkpoint',\{method:'POST',body:JSON.stringify(\{axis:axis,label:label})})"
    "    .then(function()\{document.getElementById(axis+'-label').value='';load()});"
    "}"
    "function ckptLabel(tags)\{"
    "  var out=tags.filter(function(t)\{return t!=='checkpoint'});"
    "  return out.length?out.join(' '):null;"
    "}"
    "function renderList(el,rows,axis)\{"
    "  el.innerHTML='';"
    "  if(!rows.length)\{el.innerHTML='<div class=muted>no checkpoints yet</div>';return;}"
    "  rows.slice().reverse().forEach(function(r)\{"
    "    var div=document.createElement('div');div.className='row';"
    "    var v=ckptLabel(r.tags);"
    "    var when=new Date(r.da).toLocaleString();"
    "    var label=(v?v+' \\u00b7 ':'')+'rev '+r.ud+' \\u00b7 '+when;"
    "    var span=document.createElement('span');span.textContent=label;"
    "    span.className='row-label';"
    "    var btns=document.createElement('span');btns.className='btns';"
    "    var mat=document.createElement('button');"
    "    mat.className='btn btn-grn';mat.textContent='Materialize';"
    "    mat.onclick=function()\{materialize(axis,r.ud)};"
    "    var pre=document.createElement('button');"
    "    pre.className='btn';pre.textContent='Preview';"
    "    pre.onclick=function()\{loadTree(axis,r.ud)};"
    "    var clr=document.createElement('button');"
    "    clr.className='btn btn-red';clr.textContent='Clear';"
    "    clr.onclick=function()\{clearCkpt(axis,r.ud)};"
    "    btns.appendChild(pre);btns.appendChild(mat);btns.appendChild(clr);"
    "    div.appendChild(span);div.appendChild(btns);el.appendChild(div);"
    "  });"
    "}"
    "function loadTree(axis,ud)\{"
    "  var url=BASE+'tree/'+axis+(ud==null?'':'/'+ud);"
    "  fetch(url).then(function(r)\{return r.json()}).then(function(t)\{"
    "    renderTree(document.getElementById(axis+'-tree'),axis,t.files,ud);"
    "  });"
    "}"
    "function renderTree(el,axis,files,ud)\{"
    "  el.innerHTML='';"
    "  var hdr=document.createElement('div');hdr.className='tree-hdr';"
    "  hdr.textContent=ud==null?'current files':'files at rev '+ud+' (preview) ';"
    "  if(ud!=null)\{"
    "    var back=document.createElement('a');back.href='#';back.textContent='back to current';"
    "    back.onclick=function(e)\{e.preventDefault();loadTree(axis,null)};"
    "    hdr.appendChild(back);"
    "  }"
    "  el.appendChild(hdr);"
    "  if(!files.length)\{"
    "    var mt=document.createElement('div');mt.className='muted';"
    "    mt.textContent='(empty)';el.appendChild(mt);return;"
    "  }"
    "  files.sort(function(a,b)\{return (a.path+a.name)<(b.path+b.name)?-1:1});"
    "  files.forEach(function(f)\{"
    "    var div=document.createElement('div');div.className='tree-row';"
    "    var full=(f.path==='/'?'':f.path)+'/'+f.name;"
    "    var nm=document.createElement('span');nm.textContent=full;"
    "    var bl=document.createElement('span');bl.className='muted';bl.textContent=f.blot;"
    "    div.appendChild(nm);div.appendChild(bl);el.appendChild(div);"
    "  });"
    "}"
    "function load()\{"
    "  fetch(BASE+'state').then(function(r)\{return r.json()}).then(function(s)\{"
    "    document.getElementById('source-input').value=s.config.source||'';"
    "    document.getElementById('status').textContent="
    "      (s.config.source?'subscribed':'not configured')+"
    "      (s.config.public?' \\u00b7 published':' \\u00b7 private');"
    "    document.getElementById('publish-btn').textContent="
    "      s.config.public?'Unpublish':'Publish';"
    "    document.getElementById('publish-btn').style.display="
    "      s.config.source?'none':'';"
    "    document.getElementById('fetch-btn').style.display="
    "      s.config.source?'':'none';"
    "    document.getElementById('version').textContent=s.version;"
    "    renderList(document.getElementById('code-ckpts'),s.code,'code');"
    "    renderList(document.getElementById('data-ckpts'),s.data,'data');"
    "    loadTree('code',null);loadTree('data',null);"
    "  });"
    "}"
    "load();"
  ==
--
