::  desk nexus: sync code from a remote source with checkpoint safety
::
::  config.json holds source as JSON string — a path pointing DIRECTLY
::  at a code directory to mirror, anywhere in the namespace:
::    "~nec/apps/counter/desk/code"                (remote ship)
::    "/apps/foo.git_repo/data/tree/code"          (a checked-out repo)
::  The desk mirrors whatever dir you point it at into its /desk/code;
::  it assumes NOTHING about the source's internal shape.
::
::  Updates are version-gated: the source's code dir holds a version
::  file (any file named version.* whose mark renders to text). The
::  desk re-syncs when its content changes; the text is opaque, used
::  only as a checkpoint tag. Code can change freely on the source —
::  the desk won't update until the publisher bumps the version.
::
::  Layout — host/guest split:
::    config.json     source config            (host, root-governed)
::    version.*       release version          (host)
::    main.sig        HTTP UI                  (host)
::    /requests/      HTTP request grubs       (host)
::    /desk/code/     %code nexus synced from source — governs the
::                    guest world and nothing else. Carries the code
::                    plus bill.json, which declares which nexuses to
::                    create in /desk/data on first install (only when
::                    empty). bill.json is the ONLY desk-level file;
::                    everything a nexus says about itself (alias, weir,
::                    tile, icon) is per-nexus, declared in its own
::                    on-load and read by the shell's desk-data descent.
::    /desk/data/     working data for the installed desk
::    /staged/        local working tree: a plain dir, not a code
::                    nexus, so edits there trigger nothing. Poke
::                    stage.sig to mirror /staged into /desk/code
::                    atomically (files missing from /staged are
::                    removed) — the local dev loop.
::    stage.sig       poke target for applying /staged
::
::  The host layer resolves marcs from the root code namespace; the
::  guest resolves against /desk/code. Guests distribute every marc
::  they use — content-addressing dedupes shared marcs for free.
::
::  Checkpoints live entirely in the born history. Before each code
::  update the fold hists of /data and /code (plus the version file)
::  firmed and tagged with the outgoing version — the fold pace lobe
::  IS the merkle root of the subtree at that instant. One hash per
::  axis per version; no manifest files.
::
::  Restore materializes any historical /data x /code pair:
::  /code is nullified first (world stops — /data goes inert),
::  then /data loads, then /code loads and everything comes alive.
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
      [%fall %& [/ %'stage.sig'] [[/ %sig] ~]]
      [%fall %| /staged empty-dir:loader]
      [%fall %| /requests empty-dir:loader]
      [%fall %| /desk empty-dir:loader]
      [%fall %| /desk/code code-dir]
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
    ;<  here=rail:tarball  bind:m  get-here-abs:io
    ;<  ~  bind:m  (reg-register-at:io here)
    =/  nex-dir=path  path.here
    |-
    ;<  config-json=json  bind:m  (get-state-as:io ,json)
    =/  config=desk-config  (json-to-config config-json)
    ;<  ~  bind:m  (apply-share nex-dir ~ share.config)
    ?~  source.config
      ::  no source configured, wait for poke
      ~&  >  %desk-no-source
      ;<  =sage:tarball  bind:m  take-poke:io
      =/  new-json=json  !<(json q.sage)
      =/  new-config=desk-config  (json-to-config new-json)
      ;<  ~  bind:m  (apply-share nex-dir share.config share.new-config)
      ;<  ~  bind:m  (replace:io new-json)
      $
    ::  the version file's name is KNOWN from config, so watch its EXACT
    ::  road — even before it exists (a fresh sub on an absent road is
    ::  legal and fires when it appears). No discovery-by-peek, so a
    ::  source that hasn't checked out yet can't deadlock us.
    =/  source-road=road:tarball  (parse-source u.source.config)
    =/  ver-name=@ta  version.config
    =/  ver-road=road:tarball  (version-road source-road ver-name)
    ~&  >  [%desk-subscribing u.source.config ver-name]
    ;<  init=wave:nexus  bind:m  (keep:io /ver ver-road ~)
    ~&  >  [%desk-subscribed u.source.config]
    ::  install: sync the source's release. Instance creation (apply-bill)
    ::  is owned SOLELY by the version.* fiber — mirroring the version file
    ::  here spawns it, and it apply-bills on spawn. Doing it here too just
    ::  races that fiber and both try to make the same instance. A no-op
    ::  until the version file actually exists (source not yet populated).
    ;<  ~  bind:m  (sync-release source-road rail)
    ::  re-apply share so the freshly mirrored version file is granted
    ;<  ~  bind:m  (apply-share nex-dir ~ share.config)
    ;<  vt=(unit @t)  bind:m
      (read-version-text (nex-road:io rail [%& / ver-name]))
    ;<  ~  bind:m
      %^  do-checkpoint  rail  ver-name
      (sy ?~(vt ~['checkpoint'] ~['checkpoint' (version-knot u.vt)]))
    |-
    ;<  res=news-or-poke  bind:m  (take-news-or-poke /ver)
    ?-  -.res
        %news
      ~&  >  %desk-update-received
      ::  checkpoint outgoing state, then sync. Plain 'checkpoint'
      ::  tag — version tags are the version watcher's job.
      ;<  ~  bind:m  (do-checkpoint rail ver-name (sy ~['checkpoint']))
      ;<  ~  bind:m  (sync-release source-road rail)
      $
        %poke
      ::  config change: replace state, drop sub, restart
      =/  new-json=json  !<(json q.sage.res)
      ~&  >  [%desk-config-change new-json]
      =/  new-config=desk-config  (json-to-config new-json)
      ;<  ~  bind:m  (apply-share nex-dir share.config share.new-config)
      ;<  ~  bind:m  (replace:io new-json)
      ;<  ~  bind:m  (drop:io /ver ver-road)
      ^$
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
      ::  stage.sig: poke to apply /staged to /desk/code — the local
      ::  dev loop. Checkpoint first; /staged mirrors into code, then
      ::  bill and shell files apply as in a synced install.
      ::
      [~ %'stage.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%desk stage: failed")
    |-
    ;<  *  bind:m  take-poke:io
    ;<  staged=(unit (list bfile))  bind:m  (fetch-dir rail /staged ~)
    ?:  =(~ (fall staged ~))
      ~&  >>  %desk-nothing-staged
      $
    ~&  >  %desk-stage-apply
    ;<  vn=(unit @ta)  bind:m  (own-version-name rail)
    ;<  ~  bind:m
      (do-checkpoint rail (fall vn %'version.ud') (sy ~['checkpoint' 'pre-stage']))
    ;<  ~  bind:m  (cull-dir rail /desk/code)
    ;<  ~  bind:m  (write-files rail /desk/code (need staged))
    ;<  ~  bind:m  (apply-bill rail)
    ~&  >  %desk-stage-applied
    $
      ::  version.*: every version change checkpoints the world.
      ::  Runs on publisher and subscriber alike — a release IS a
      ::  checkpoint, tagged with the version it inaugurates.
      ::
      [~ @]
    =/  nam=@ta  name.rail
    ?.  =('version.' (end [3 8] nam))  stay:m
    ;<  ~  bind:m  (rise-wait:io prod "%desk version: failed")
    ::  a release must be a complete world, however the code arrived:
    ::  bootstrap the data nexuses from bill.json locally too. Idempotent.
    ;<  ~  bind:m  (apply-bill rail)
    ::  checkpoint the current version at every process start: gives
    ::  every desk a birth checkpoint (idempotent re-firm on restarts)
    ;<  vt0=(unit @t)  bind:m
      (read-version-text (nex-road:io rail [%& / nam]))
    ;<  ~  bind:m
      %^  do-checkpoint  rail  nam
      (sy ?~(vt0 ~['checkpoint'] ~['checkpoint' (version-knot u.vt0)]))
    ;<  init=wave:nexus  bind:m
      (keep:io /self (nex-road:io rail [%& / nam]) ~)
    =/  prev=(unit @t)  (bind vt0 version-knot)
    |-
    ;<  res=news-or-poke  bind:m  (take-news-or-poke /self)
    ?-  -.res
        %poke  $
        %news
      ;<  ~  bind:m  (apply-bill rail)
      ;<  vt=(unit @t)  bind:m
        (read-version-text (nex-road:io rail [%& / nam]))
      =/  new=(unit @t)  (bind vt version-knot)
      ::  tag the handoff: this state is the old version's final data
      ::  and the new version's first, under the new version's code.
      ::  With no prior version the tag reads ->new.
      =/  tags=(set @t)
        ?~  new  (sy ~['checkpoint'])
        %-  sy
        :~  'checkpoint'
            (crip "{?~(prev "" (trip u.prev))}->{(trip u.new)}")
        ==
      ;<  ~  bind:m  (do-checkpoint rail nam tags)
      $(prev new)
    ==
  ==
--
::
|%
+$  desk-config
  $:  source=(unit @t)
      share=(list path)
      ::  the source's version file, by FULL name (e.g. 'version.json').
      ::  Knowing it lets us watch its exact road before it exists —
      ::  discovery-by-peek can't, since peek needs the file present.
      version=@t
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
::  share holds the usergroup paths the desk is published to, as real
::  paths; strings exist only in the json. 'public' is emitted as a
::  derived field (membership of /public) for the UI, and accepted on
::  read as legacy sugar for share [/public].
::
++  config-to-json
  |=  config=desk-config
  ^-  json
  %-  pairs:enjs:format
  :~  ['source' ?~(source.config ~ s+u.source.config)]
      ['share' a+(turn share.config |=(g=path s+(spat g)))]
      ['public' b+?=(^ (find ~[/public] share.config))]
      ['version' s+version.config]
  ==
::
++  json-to-config
  |=  =json
  ^-  desk-config
  ?.  ?=(%o -.json)  *desk-config
  =/  src  (~(get by p.json) 'source')
  =/  shr  (~(get by p.json) 'share')
  =/  pub  (~(get by p.json) 'public')
  =/  ver  (~(get by p.json) 'version')
  :*  ?~(src ~ ?:(?=([~ %s *] src) `p.u.src ~))
      ::  share
      ?:  ?=([~ %a *] shr)
        %+  murn  p.u.shr
        |=  j=^json
        ?.  ?=([%s *] j)  ~
        (rush p.j stap)
      ?:  &(?=([~ %b *] pub) p.u.pub)  ~[/public]
      ~
      ::  version — default to the convention when unset or empty
      ?:  &(?=([~ %s *] ver) !=('' p.u.ver))  p.u.ver
      %'version.json'
  ==
::
::  +apply-share: register the follow weir with every group in the new
::  share list, and clear it from groups that were dropped
::
::    The weir grants exactly what a follower needs to pull: the
::    version file, the code tree, and the bill.
::
++  apply-share
  |=  [nex-dir=path old=(list path) new=(list path)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  grant every root version.* file plus the code tree
  ;<  =view:nexus  bind:m  (peek:io [%& %| nex-dir] ~)
  =/  ver-roads=(list road:tarball)
    ?.  ?=([%ball *] view)  ~
    ?~  fil.ball.view  ~
    %+  murn  ~(tap by contents.u.fil.ball.view)
    |=  [n=@ta *]
    ?.  =('version.' (end [3 8] n))  ~
    (some `road:tarball`[%& %& nex-dir n])
  =/  grant=weir:nexus
    :+  ~  ~
    %-  sy
    [[%& %| (weld nex-dir /desk/code)] ver-roads]
  ::  groups to clear: any dropped from the share list, plus /public
  ::  always — a fresh fiber cannot know what a prior life granted,
  ::  so the discovery group's state is asserted on every application
  ::  rather than diffed.
  =/  clear=(list path)
    =|  seen=(set path)
    =/  base=(list path)  (weld old `(list path)`~[/public])
    |-  ^-  (list path)
    ?~  base  ~
    ?:  ?|((~(has in seen) i.base) ?=(^ (find ~[i.base] new)))
      $(base t.base)
    [i.base $(base t.base, seen (~(put in seen) i.base))]
  =/  jobs=(list [grp=path w=weir:nexus])
    %+  weld
      (turn clear |=(g=path [g *weir:nexus]))
    (turn new |=(g=path [g grant]))
  |-  ^-  form:m
  ?~  jobs
    ::  nudge the shell to rescan its public desk directory — the
    ::  grants it derives that directory from just changed.
    ::  register-public accepts pack OR veto as done, so a missing shell
    ::  (a headless ship with no launcher) doesn't fail the config fiber.
    (register-public (pairs:enjs:format ~[['rescan' b+%.y]]))
  ;<  ~  bind:m  (reg-how:io [grp.i.jobs w.i.jobs])
  $(jobs t.jobs)
::  +register-public: poke the shell's public desk directory fiber,
::  and swallow the ack — or the veto, if no shell is installed.
::
++  register-public
  |=  cmd=json
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  dir-road=road:tarball  [%& %& /apps/'shell.shell' %'public.json']
  ;<  ~  bind:m
    (send-dart:io %node /pub-reg dir-road %poke [[/ %json] cmd])
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
    ~  [%wait ~]
      [~ %pack *]
    ?.  =(/pub-reg wire.u.in)  [%skip ~]
    [%done ~]
      [~ %veto *]
    [%done ~]
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
::  version-road: the source's version file road, by discovered name
::
++  version-road
  |=  [source-road=road:tarball name=@ta]
  ^-  road:tarball
  ?.  ?=([%& %| *] source-road)  ~|(%desk-unexpected-road-shape !!)
  [%& %& p.p.source-road name]
::  source-dir-road: a directory under the source desk
::
++  source-dir-road
  |=  [source-road=road:tarball dir=path]
  ^-  road:tarball
  ?.  ?=([%& %| *] source-road)  ~|(%desk-unexpected-road-shape !!)
  [%& %| (weld p.p.source-road dir)]
::  source-file-road: a file under the source desk
::
++  source-file-road
  |=  [source-road=road:tarball dir=path name=@ta]
  ^-  road:tarball
  ?.  ?=([%& %| *] source-road)  ~|(%desk-unexpected-road-shape !!)
  [%& %& (weld p.p.source-road dir) name]
::  sync-release: mirror the source's CURRENT tree when its version
::  number changes. The version file is only a change signal — we never
::  read the source at a historical revision (a source need not firm its
::  folds, and a git-tree source rewrites its history on every checkout,
::  so any pinned revision can vanish). Reproducibility/restore is a
::  LOCAL concern: this desk checkpoints its OWN world after each sync
::  (do-checkpoint), and do-restore reads THIS desk's own history. Also
::  mirrors the source's version file, raw, under its own name.
::
++  sync-release
  |=  [source-road=road:tarball =rail:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ver-name=(unit @ta)  bind:m  (find-version-name source-road)
  ?~  ver-name
    ~&  >>  %desk-no-version-at-source
    (pure:m ~)
  ;<  ver-view=view:nexus  bind:m
    (peek:io (version-road source-road u.ver-name) ~)
  ?.  ?=([%file *] ver-view)
    ~&  >>  %desk-no-version-at-source
    (pure:m ~)
  ~&  >  [%desk-sync-release ver=(version-text sang.ver-view)]
  ::  the source IS the code directory (point it anywhere) — mirror it
  ::  wholesale into our /desk/code, no assumed sub-structure.
  ;<  ~  bind:m  (sync-dir source-road rail /desk/code ~)
  =/  content=bask:tarball
    [p.sang.ver-view (sang-noun:tarball sang.ver-view)]
  ;<  exists=?  bind:m
    (peek-exists:io (nex-road:io rail [%& / u.ver-name]))
  ?.  exists
    (make:io (nex-road:io rail [%& / u.ver-name]) |+[content ~])
  (over:io (nex-road:io rail [%& / u.ver-name]) content)
::
::  apply-bill: ensure every nexus the bill declares exists in /desk/data.
::  Idempotent and runs on every install AND version bump — it MAKES the
::  entries that aren't there and SKIPS the ones that are, so a bumped
::  bill adds its new nexuses and re-runs never collide.
::
++  apply-bill
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  bill=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /desk/code %'bill.json']) ,json)
  ::  bill.json may live as a json grub OR a plain mime text file in the
  ::  desk's code tree — accept both: if the json read isn't an object,
  ::  re-read raw and parse the payload as json text.
  ;<  bill=(unit json)  bind:m
    ?:  &(?=(^ bill) ?=([%o *] u.bill))
      (pure:(fiber:fiber:nexus ,(unit json)) bill)
    ;<  mim=(unit mime)  bind:(fiber:fiber:nexus ,(unit json))
      (peek-as:io (nex-road:io rail [%& /desk/code %'bill.json']) ,mime)
    %-  pure:(fiber:fiber:nexus ,(unit json))
    ?~  mim  ~
    (de:json:html q.q.u.mim)
  ?~  bill
    ~&  >  %desk-no-bill
    (pure:m ~)
  ?.  ?=(%o -.u.bill)
    ~&  >>>  %desk-bill-not-object
    (pure:m ~)
  =/  entries=(list [@t @t])
    (turn ~(tap by p.u.bill) |=([k=@t v=json] [k (so:dejs:format v)]))
  ~&  >  [%desk-bill (lent entries)]
  =|  made-any=?
  |-
  ?~  entries
    ::  nudge the shell: new apps exist — sweep now so their followers
    ::  spawn and their asks notify immediately. Soft: a missing shell
    ::  must not fail the install.
    ?.  made-any  (pure:m ~)
    ;<  *  bind:m
      (poke-soft:io [%& %& /apps/'shell.shell' %'sweep.sig'] [[/ %sig] ~])
    (pure:m ~)
  =/  nam=@ta  -.i.entries
  =/  cod=path  (stab +.i.entries)
  =/  neck=rail:tarball  [(snip cod) (rear cod)]
  =/  data-road=road:tarball  (nex-road:io rail [%| /desk/data/[nam]])
  ::  truly idempotent (as the doc promises): apply-bill fires from BOTH
  ::  the sync fiber and the version watcher on install — whichever runs
  ::  second must skip an instance the first already made, not collide.
  ;<  has=?  bind:m  (peek-exists:io data-road)
  ?:  has  $(entries t.entries)
  ::  created sandboxed: an empty weir [~ ~ ~] (permit nothing) rather than
  ::  ~ (no filter / wide open). The nexus still materializes its own tree
  ::  (that rides the make, not a weir-gated dart), but stays runtime-inert
  ::  — it can reach nothing until its weir.json is approved in the shell.
  =/  =bole:tarball  [`[`neck `[~ ~ ~] %.n ~] ~]
  ~&  >  [%desk-bill-entry nam neck]
  ;<  ~  bind:m  (make:io data-road &+bole)
  =.  made-any  %.y
  $(entries t.entries)
::
++  sync-dir
  |=  [source-dir=road:tarball =rail:tarball dir=path cas=(unit case:nexus)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =view:nexus  bind:m
    ?~  cas  (peek:io source-dir ~)
    (peek-at:io source-dir ~ u.cas)
  ?.  ?=([%ball *] view)
    ~&  >>  [%desk-nothing-at-source dir]
    (pure:m ~)
  =/  files=(list bfile)  (ball-to-files ball.view)
  ~&  >  [%desk-sync-files dir (lent files)]
  (write-files rail dir files)
::
::  do-checkpoint: firm the fold hists of /data and /code plus
::  the version file, tagged with the outgoing version. The fold pace
::  lobe is the merkle root of the whole subtree — three firms
::  checkpoint the entire world.
::
++  do-checkpoint
  |=  [=rail:tarball ver-name=@ta tags=(set @t)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ~&  >  [%desk-checkpoint tags=tags]
  ;<  ~  bind:m  (checkpoint:io (nex-road:io rail [%| /desk/data]))
  ;<  ~  bind:m  (tag:io (nex-road:io rail [%| /desk/data]) ~ tags)
  ;<  ~  bind:m  (checkpoint:io (nex-road:io rail [%| /desk/code]))
  ;<  ~  bind:m  (tag:io (nex-road:io rail [%| /desk/code]) ~ tags)
  ;<  has=?  bind:m
    (peek-exists:io (nex-road:io rail [%& / ver-name]))
  ?.  has  (pure:m ~)
  ;<  ~  bind:m  (checkpoint:io (nex-road:io rail [%& / ver-name]))
  (tag:io (nex-road:io rail [%& / ver-name]) ~ tags)
::
::  +version-text: render a version file's content as text, by mark.
::  ~ for marks with no text rendering.
::
++  version-text
  |=  =sang:tarball
  ^-  (unit @t)
  ?:  (is-boom:tarball sang)  ~
  =/  nun  (sang-noun:tarball sang)
  ?+  p.sang  ~
      [~ %ud]
    =/  n  ((soft @ud) nun)
    ?~(n ~ `(crip (a-co:co u.n)))
      [~ %txt]
    =/  w  ((soft wain) nun)
    ?~(w ~ ?~(u.w ~ `i.u.w))
      [~ %t]
    ((soft @t) nun)
      [~ %json]
    =/  j  ((soft json) nun)
    ?~  j  ~
    ?+  -.u.j  ~
      %s  `p.u.j
      %n  `p.u.j
    ==
  ==
::  +version-knot: first line of a version text, capped at 64 chars,
::  sanitized to a safe tag: lowercased, unsafe characters become -
::
++  version-knot
  |=  txt=@t
  ^-  @t
  =/  t=tape  (trip txt)
  =/  nl=(unit @ud)  (find "\0a" t)
  =?  t  ?=(^ nl)  (scag u.nl t)
  =?  t  (gth (lent t) 64)  (scag 64 t)
  =/  s=tape
    %+  turn  t
    |=  c=@tD
    ?:  ?|  &((gte c 'a') (lte c 'z'))
            &((gte c '0') (lte c '9'))
            =(c '.')  =(c '-')  =(c '_')  =(c '~')
        ==
      c
    ?:  &((gte c 'A') (lte c 'Z'))  (add c 32)
    '-'
  ?~  s  'v'
  (crip s)
::  +pick-version-name: the version file among a dir's file names —
::  any name starting version. — alphabetical first if several
::
++  pick-version-name
  |=  names=(list @ta)
  ^-  (unit @ta)
  =/  vs=(list @ta)
    (skim names |=(n=@ta =('version.' (end [3 8] n))))
  ?~  vs  ~
  `(snag 0 (sort vs aor))
::  +find-version-name: discover the version file at a source dir.
::  List the directory and pick any version.* file. Remote roots are
::  not listable, so when the listing yields nothing, probe the
::  canonical names directly, in the same alphabetical order the
::  listing pick would use.
::
++  find-version-name
  |=  source-road=road:tarball
  =/  m  (fiber:fiber:nexus ,(unit @ta))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io source-road ~)
  =/  listed=(unit @ta)
    ?.  ?=([%ball *] view)  ~
    ?~  fil.ball.view  ~
    %-  pick-version-name
    (turn ~(tap by contents.u.fil.ball.view) |=([n=@ta *] n))
  ?^  listed  (pure:m listed)
  =/  names=(list @ta)  ~[%'version.json' %'version.txt' %'version.ud']
  |-
  ?~  names  (pure:m ~)
  ;<  fv=view:nexus  bind:m  (peek:io (version-road source-road i.names) ~)
  ?:  ?=([%file *] fv)  (pure:m `i.names)
  $(names t.names)
::  +read-version-text: peek a version file and render it as text
::
++  read-version-text
  |=  =road:tarball
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%file *] view)  (pure:m ~)
  (pure:m (version-text sang.view))
::  +own-version-name: discover this desk's own version file name
::
++  own-version-name
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(unit @ta))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io (nex-road:io rail [%| /]) ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  ?~  fil.ball.view  (pure:m ~)
  %-  pure:m
  %-  pick-version-name
  (turn ~(tap by contents.u.fil.ball.view) |=([n=@ta *] n))
::  +own-version: discover this desk's own version file and read it
::
++  own-version
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io (nex-road:io rail [%| /]) ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  ?~  fil.ball.view  (pure:m ~)
  =/  cs  contents.u.fil.ball.view
  =/  nam=(unit @ta)
    (pick-version-name (turn ~(tap by cs) |=([n=@ta *] n)))
  ?~  nam  (pure:m ~)
  =/  ct  (~(get by cs) u.nam)
  ?~  ct  (pure:m ~)
  (pure:m (version-text sang.u.ct))
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
  ;<  =view:nexus  bind:m
    ?~  cas  (peek:io (nex-road:io rail [%| dir]) ~)
    (peek-at:io (nex-road:io rail [%| dir]) ~ u.cas)
  ?.  ?=([%ball *] view)  (pure:m ~)
  (pure:m `(ball-to-files ball.view))
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
    %+  over:io  (nex-road:io rail [%& (weld dir pax.i.files) name.i.files])
    (code-bask name.i.files sang.i.files)
  $(files t.files)
::  code-bask: a .hoon file must land as a %hoon blot or the code
::  namespace won't compile it — a git-tree source delivers everything as
::  raw mime, and a mime .hoon is invisible to build-code. Everything else
::  passes through unchanged.
::
++  code-bask
  |=  [name=@ta =sang:tarball]
  ^-  bask:tarball
  =/  t=tape  (trip name)
  ?.  ?&  (gth (lent t) 5)
          =(".hoon" (slag (sub (lent t) 5) t))
          !=([/ %hoon] p.sang)
      ==
    [p.sang (sang-noun:tarball sang)]
  =/  mim=(unit mime)  (mole |.(!<(mime (need-vase:tarball sang))))
  ?~  mim  [p.sang (sang-noun:tarball sang)]
  [[/ %hoon] `@t`(crip (trip q.q.u.mim))]
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
    ;<  ver=(unit @t)  bind:m  (own-version rail)
    ;<  code-born=(each binfo tang)  bind:m
      (born:io (nex-road:io rail [%| /desk/code]))
    ;<  data-born=(each binfo tang)  bind:m
      (born:io (nex-road:io rail [%| /desk/data]))
    =/  =json
      %-  pairs:enjs:format
      :~  ['config' (fall config-json [%o ~])]
          ['version' ?~(ver ~ s+u.ver)]
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
    =/  had=?  ?=(^ (find ~[/public] share.cur))
    =/  new-config=desk-config
      %=  cur
        share  ?:  had
                 (skip share.cur |=(g=path =(/public g)))
               (snoc share.cur /public)
      ==
    ~&  >  [%desk-publish public=!had]
    ;<  ~  bind:m
      (poke:io (nex-road:io rail [%& / %'config.json']) [[/ %json] (config-to-json new-config)])
    (respond eyre-id rail 200 ?:(had 'unpublished' 'published'))
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
    ;<  ver-name=(unit @ta)  bind:m  (find-version-name source-road)
    ?~  ver-name
      ;<  ~  bind:m  (respond eyre-id rail 400 'no version file at source')
      (pure:m ~)
    ::  protect current state, then pull
    ;<  ~  bind:m  (do-checkpoint rail u.ver-name (sy ~['checkpoint']))
    ;<  ~  bind:m  (sync-release source-road rail)
    ;<  vt=(unit @t)  bind:m
      (read-version-text (nex-road:io rail [%& / u.ver-name]))
    ;<  ~  bind:m
      %^  do-checkpoint  rail  u.ver-name
      (sy ?~(vt ~['checkpoint'] ~['checkpoint' (version-knot u.vt)]))
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
