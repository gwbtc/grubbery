::  desk nexus: sync code from a remote source with snapshot safety
::
::  source.json holds source as JSON string — a path pointing DIRECTLY
::  at a code directory to mirror, anywhere in the namespace:
::    "~nec/apps/counter/desk/code"                (remote ship)
::    "/apps/foo.git_repo/data/tree/code"          (a checked-out repo)
::  The desk mirrors whatever dir you point it at into its /desk/code;
::  it assumes NOTHING about the source's internal shape.
::
::  Updates are version-gated: the source's code dir holds a version
::  file (any file named version.* whose mark renders to text). The
::  desk re-syncs when its content changes; the text is opaque, used
::  only as an opaque tag. Code can change freely on the source —
::  the desk won't update until the publisher bumps the version.
::
::  Layout — host/guest split:
::    source.json     source config            (host, root-governed)
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
::
::  The host layer resolves marcs from the root code namespace; the
::  guest resolves against /desk/code. Guests distribute every marc
::  they use — content-addressing dedupes shared marcs for free.
::
::  Snapshots are world-level and live in the born history. Each is a
::  firm of BOTH /code and /data, tagged with a monotonic counter N
::  (snapshot.ud) — the fold pace lobe IS the merkle root of the subtree
::  at that instant. The initial snapshot is taken once; thereafter a
::  version change snapshots the current world before the new code lands.
::
::  Compose Live (do-compose) is the only thing besides source-sync that
::  mutates live: it snapshots first, then builds a new live world by
::  choosing code from {live | snapshot N | none} and data from
::  {live | snapshot M} — nullify code, load data, load code.
::
/&  man       ../man/desk/readme.md
/&  desk-html  desk/ui/index.html
/&  desk-js    desk/ui/app.js
/&  desk-css   desk/ui/style.css
=<  ^-  nexus:nexus
    |%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  =/  code-dir=bole:tarball  [`[`[/ %code] ~ %.n ~] ~]
  ::  inert-dir: a neck-less directory sealed with a [~ ~ ~] (permit-nothing)
  ::  weir — files sit peekable, governed by nothing, able to reach nothing.
  =/  inert-dir=bole:tarball  [`[~ `[~ ~ ~] %.n ~] ~]
  %+  spin:loader  ball
  :~  (manifest:loader 0)
      [%fall %& [/ %'source.json'] [[/ %json] (source-to-json *source-config)]]
      [%fall %& [/ %'version.json'] [[/ %json] (pairs:enjs:format ~[['version' (numb:enjs:format 0)]])]]
      [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
      ::  share.usergroups: the OPENING state — the set of usergroups this
      ::  desk grants peek on /desk/code. Poke it {add|remove: <group>};
      ::  it re-registers the grants. Born empty (open to nobody).
      [%fall %& [/ %'share.usergroups'] [[/ %usergroups] *(set path)]]
      ::  checkout.desk_snap: which world snapshot (snapshot N) is
      ::  materialized into /checkout, or ~ for live only. Poke it {n: N}
      ::  to check that snapshot out (both axes); poke null to clear.
      ::  Reset to live on every load: /checkout's contents are re-boled
      ::  (and thus cleared) below, so the pointer must not outlive them.
      [%over %& [/ %'checkout.desk_snap'] [[/desk %snap] *(unit @ud)]]
      ::  snapshot.ud: monotonic snapshot counter. Only ever increments
      ::  (never reused, even after clears), so it is the stable identity
      ::  of a world snapshot — both axes are tagged `snapshot N`.
      [%fall %& [/ %'snapshot.ud'] [[/ %ud] 0]]
      [%fall %| /requests empty-dir:loader]
      [%fall %| /desk empty-dir:loader]
      [%fall %| /desk/code code-dir]
      [%fall %| /desk/data empty-dir:loader]
      ::  /checkout is an inert inspection worktree for one snapshot. It is
      ::  rebuilt wholesale by the checkout handler (cull + file-level
      ::  write), so %over here forces the right dir governance on every
      ::  load — and, since the subdirs are empty except during an active
      ::  checkout, that wipe is a no-op in the normal case.
      ::
      ::  /checkout/code IS a real /code nexus: its marks must compile so
      ::  /checkout/data files can render under the snapshot's OWN marks.
      ::  Compiling hoon is inert (it produces bins, runs no app logic), so
      ::  this stays safe to inspect.
      ::
      ::  /checkout/data is neck-STRIPPED: ball-to-files lifts only
      ::  [path name sang], discarding every sub-nexus's governance, so the
      ::  checked-out apps land as plain inert files — no neck, nothing to
      ::  activate. The [~ ~ ~] weir adds nothing at runtime (there is no
      ::  process to gate); it is a static seal against a FUTURE code path
      ::  that might wrongly write a neck here.
      [%fall %| /checkout empty-dir:loader]
      [%over %| /checkout/code code-dir]
      [%over %| /checkout/data inert-dir]
      [%over %& [/ %'README.md'] [[/ %mime] man]]
      ::  the UI shell — external static files under /ui, served by
      ::  handle-get (URLs stay flat; only the namespace groups them).
      [%fall %| /ui empty-dir:loader]
      [%over %& [/ui %'index.html'] [[/ %mime] desk-html]]
      [%over %& [/ui %'app.js'] [[/ %mime] desk-js]]
      [%over %& [/ui %'style.css'] [[/ %mime] desk-css]]
    ==
::
++  on-file
  |=  [=rail:tarball =blot:tarball]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
      ::  source.json: watch remote source, sync code on updates
      ::
      [~ %'source.json']
    ;<  ~  bind:m  (rise-wait:io prod "%desk config: failed")
    ;<  here=rail:tarball  bind:m  get-here-abs:io
    ;<  ~  bind:m  (reg-register-at:io here)
    |-
    ;<  src-json=json  bind:m  (get-state-as:io ,json)
    =/  config=source-config  (json-to-source src-json)
    ?~  config
      ::  standalone — no source.json, wait for a poke to start following
      ~&  >  %desk-no-source
      ;<  =sage:tarball  bind:m  take-poke:io
      =/  new-json=json  !<(json q.sage)
      ;<  ~  bind:m  (replace:io new-json)
      $
    ::  the version file's road is KNOWN, so watch its EXACT road — even
    ::  before it exists (a fresh sub on an absent road is legal and
    ::  fires when it appears). No discovery-by-peek, so a source that
    ::  hasn't checked out yet can't deadlock us.
    =/  ver-road=road:tarball    (parse-source-file version.u.config)
    =/  code-road=road:tarball   (parse-source code.u.config)
    =/  ver-name=@ta             (rear (parse-path version.u.config))
    ~&  >  [%desk-subscribing version.u.config code.u.config]
    ;<  init=wave:nexus  bind:m  (keep:io /ver ver-road ~)
    ~&  >  [%desk-subscribed version.u.config]
    ::  the runtime restarts EVERY fiber on a nexus reload, so this handler
    ::  re-enters from the top constantly. Only pull on start when we're
    ::  actually BEHIND (the source's version differs from our mirror) —
    ::  otherwise a reload would peek + re-mirror the whole source tree
    ::  every time for nothing. A version change in the loop below always
    ::  pulls. First install: own version is ~, so this is true.
    ;<  behind=?  bind:m  (source-behind ver-road rail)
    ;<  ~  bind:m
      ?.  behind  (pure:m ~)
      (sync-release ver-road code-road ver-name rail)
    |-
    ;<  res=news-or-poke  bind:m  (take-news-or-poke /ver)
    ?-  -.res
        %news
      ~&  >  %desk-update-received
      ::  snapshot the world, then pull the new release
      ;<  ~  bind:m  (do-snapshot rail)
      ;<  ~  bind:m  (sync-release ver-road code-road ver-name rail)
      $
        %poke
      ::  config change: replace state, drop sub, restart
      =/  new-json=json  !<(json q.sage.res)
      ~&  >  [%source-config-change new-json]
      ;<  ~  bind:m  (replace:io new-json)
      ;<  ~  bind:m  (drop:io /ver ver-road)
      ^$
    ==
      ::  share.usergroups: the OPENING state. Poke {add|remove: <group>}
      ::  to open/close this desk to a usergroup — it re-registers the
      ::  grants (peek on /desk/code + version.json for each open group).
      ::
      [~ %'share.usergroups']
    ;<  ~  bind:m  (rise-wait:io prod "%desk share: failed")
    ;<  here=rail:tarball  bind:m  get-here-abs:io
    ;<  ~  bind:m  (reg-register-at:io here)
    |-
    ;<  cur=(set path)  bind:m  (get-state-as:io ,(set path))
    ;<  =sage:tarball  bind:m  take-poke:io
    =/  jon=json  !<(json q.sage)
    =/  new=(set path)
      ?.  ?=([%o *] jon)  cur
      =/  add=(unit json)  (~(get by p.jon) 'add')
      =/  rem=(unit json)  (~(get by p.jon) 'remove')
      ?:  ?=([~ %s *] add)
        =/  g=(unit path)  (rush p.u.add stap)
        ?~(g cur (~(put in cur) u.g))
      ?:  ?=([~ %s *] rem)
        =/  g=(unit path)  (rush p.u.rem stap)
        ?~(g cur (~(del in cur) u.g))
      cur
    ;<  ~  bind:m  (replace:io new)
    ;<  ~  bind:m  (apply-share path.here ~(tap in cur) ~(tap in new))
    $
      ::  checkout.desk_snap: materialize a whole WORLD snapshot
      ::  (snapshot N) into /checkout/code + /checkout/data — both
      ::  inert — for inspection. Poke {n: N} to check it out; poke null
      ::  to clear back to live. State is the checked-out N.
      ::
      [~ %'checkout.desk_snap']
    ;<  ~  bind:m  (rise-wait:io prod "%desk checkout: failed")
    |-
    ;<  =sage:tarball  bind:m  take-poke:io
    =/  jon=json  !<(json q.sage)
    =/  want=(unit @ud)
      ?.  ?=([%o *] jon)  ~
      (json-num (~(get by p.jon) 'n'))
    ::  clear /checkout, then lay the requested snapshot (if any) into it
    ;<  ~  bind:m  (cull-dir rail /checkout/code)
    ;<  ~  bind:m  (cull-dir rail /checkout/data)
    ?~  want
      ~&  >  %desk-checkout-clear
      ;<  ~  bind:m  (replace:io `(unit @ud)`~)
      $
    ~&  >  [%desk-checkout n=u.want]
    ::  peek the whole /desk subtree as of snapshot N (files come rooted
    ::  at /desk, e.g. /code/foo, /data/bar) and lay it into /checkout —
    ::  reconstructing /checkout/code and /checkout/data wholesale.
    ;<  files=(unit (list bfile))  bind:m  (snap-files rail u.want)
    ?~  files
      ;<  ~  bind:m  (replace:io `(unit @ud)`~)
      $
    ;<  ~  bind:m  (write-files rail /checkout u.files)
    ;<  ~  bind:m  (replace:io `(unit @ud)`want)
    $
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
    ::  drop empty segments so a trailing slash (/test/) reads as the
    ::  page route (~), not a file named ''.
    =/  suffix=path
      %+  skip  (slag (lent prefix) site)
      |=(seg=@ta =('' seg))
    ::  canonical page URL ends in '/' so the shell's relative asset
    ::  links (style.css, app.js) resolve under the slug dir. Redirect
    ::  the bare form once; the slashed form serves index.html.
    =/  raw=tape  (trip url.request.req)
    =/  cut=tape  (scag (fall (find "?" raw) (lent raw)) raw)
    =/  slashed=?  &(?=(^ cut) =('/' `@`(rear cut)))
    ?:  ?&(=('GET' method.request.req) ?=(~ suffix) !slashed)
      =/  main-road  (nex-road:io rail [%& ~ %'main.sig'])
      =/  loc=@t  (crip (weld (spud prefix) "/"))
      ;<  ~  bind:m  (~(send-header http-res:io main-road) eyre-id [301 ~[['location' loc]]])
      ;<  ~  bind:m  (~(send-data http-res:io main-road) eyre-id ~)
      (pure:m ~)
    ?:  =('POST' method.request.req)
      (handle-post eyre-id suffix req rail)
    (handle-get eyre-id suffix args rail)
      ::  version.*: on every version change, bootstrap the data nexuses
      ::  the new bill declares (idempotent), and take the baseline
      ::  snapshot if the counter is still 0 (a no-op otherwise). We own
      ::  the version file, not snapshot.ud, so do-snapshot's `over` of the
      ::  counter is an ordinary external write — no self-news loop.
      ::
      [~ @]
    =/  nam=@ta  name.rail
    ?.  =('version.' (end [3 8] nam))  stay:m
    ;<  ~  bind:m  (rise-wait:io prod "%desk version: failed")
    ;<  ~  bind:m  (apply-bill rail)
    ;<  ~  bind:m  (initial-snapshot rail)
    ;<  init=wave:nexus  bind:m
      (keep:io /self (nex-road:io rail [%& / nam]) ~)
    |-
    ;<  res=news-or-poke  bind:m  (take-news-or-poke /self)
    ?-  -.res
        %poke  $
        %news
      ;<  ~  bind:m  (apply-bill rail)
      $
    ==
  ==
--
::
|%
::  source.json: optional. ~ = a standalone desk (follows nothing). If
::  present, BOTH paths are required: `version` is the road to the
::  source's version file (watched — the release signal) and `code` is
::  the road to the source's code directory (pulled into /desk/code).
::
+$  source-config  (unit [version=@t code=@t])
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
+$  binfo  (list binfo-entry)
+$  binfo-entry  [=cass:clay tags=(set @t) tomb=?]
::
::  the OPENING state (which usergroups may peek the code) lives in the
::  share.usergroups grub, not here.
::
++  source-to-json
  |=  config=source-config
  ^-  json
  ?~  config  ~
  %-  pairs:enjs:format
  :~  ['version' s+version.u.config]
      ['code' s+code.u.config]
  ==
::
++  json-to-source
  |=  =json
  ^-  source-config
  ::  match the whole json as an object — `-.json` on a ~ (null, the
  ::  unconfigured seed) would fault.
  ?.  ?=([%o *] json)  ~
  =/  verp  (~(get by p.json) 'version')
  =/  codp  (~(get by p.json) 'code')
  ?.  &(?=([~ %s *] verp) ?=([~ %s *] codp))  ~
  ?:  |(=('' p.u.verp) =('' p.u.codp))  ~
  `[p.u.verp p.u.codp]
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
  ::  what a follower needs to pull: peek the code tree and the version
  ::  file (stable name — version.json). Stable roads, granted once — no
  ::  re-apply when the code or version content changes.
  =/  grant=weir:nexus
    :+  ~  ~
    %-  sy
    :~  [%& %| (weld nex-dir /desk/code)]
        [%& %& nex-dir %'version.json']
    ==
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
  ?~  jobs  (pure:m ~)
  ;<  ~  bind:m  (reg-how:io [grp.i.jobs w.i.jobs])
  $(jobs t.jobs)
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
::  parse-path: resolve a source string to an absolute namespace path,
::  routing a ~ship/... prefix through /sys/ames for cross-ship peeks.
::
++  parse-path
  |=  src=@t
  ^-  path
  ?.  =('~' (end 3 src))  (stab src)
  =/  txt=tape  (trip src)
  =/  ship-end=@  (need (find "/" txt))
  =/  target=@p  (slav %p (crip (scag ship-end txt)))
  =/  source-path=path  (stab (crip (slag ship-end txt)))
  (weld /sys/ames/ships/[(scot %p target)]/root source-path)
::  parse-source: a source string as a directory road
::
++  parse-source
  |=  src=@t
  ^-  road:tarball
  [%& %| (parse-path src)]
::  parse-source-file: a source string (pointing at a file) as a file road
::
++  parse-source-file
  |=  src=@t
  ^-  road:tarball
  =/  p=path  (parse-path src)
  [%& %& (snip p) (rear p)]
::
::  sync-release: mirror the source's CURRENT tree when its version
::  number changes. The version file is only a change signal — we never
::  read the source at a historical revision (a source need not firm its
::  folds, and a git-tree source rewrites its history on every checkout,
::  so any pinned revision can vanish). Reproducibility/restore is a
::  LOCAL concern: this desk snapshots its OWN world after each sync
::  (do-snapshot), and do-restore reads THIS desk's own history. Also
::  mirrors the source's version file, raw, under its own name.
::
::  source-behind: is the source's version different from our mirror?
::  A cheap single-file peek — the gate that keeps a reload from
::  re-mirroring the whole source tree when we are already current.
::
++  source-behind
  |=  [ver-road=road:tarball =rail:tarball]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  sv=view:nexus  bind:m  (peek:io ver-road ~)
  ?.  ?=([%file *] sv)  (pure:m %.n)
  =/  src-ver=(unit @t)  (version-text sang.sv)
  ;<  own=(unit @t)  bind:m  (own-version rail)
  (pure:m !=(src-ver own))
::
++  sync-release
  |=  [ver-road=road:tarball code-road=road:tarball ver-name=@ta =rail:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  read the source's version file (the release token) at its known road
  ;<  ver-view=view:nexus  bind:m  (peek:io ver-road ~)
  ?.  ?=([%file *] ver-view)
    ~&  >>  %desk-no-version-at-source
    (pure:m ~)
  ~&  >  [%desk-sync-release ver=(version-text sang.ver-view)]
  ::  pull the source's code tree wholesale into our /desk/code
  ;<  ~  bind:m  (sync-dir code-road rail /desk/code ~)
  ::  mirror the source's version file locally, under its own name, so
  ::  followers of THIS desk watch our republished version
  =/  content=bask:tarball
    [p.sang.ver-view (sang-noun:tarball sang.ver-view)]
  ;<  exists=?  bind:m
    (peek-exists:io (nex-road:io rail [%& / ver-name]))
  ?.  exists
    (make:io (nex-road:io rail [%& / ver-name]) |+[content ~])
  (over:io (nex-road:io rail [%& / ver-name]) content)
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
  ?.  ?=([%o *] u.bill)
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
::  do-snapshot: capture a WORLD snapshot — firm both /data and /code
::  together and tag both with `snapshot N`, where N is the monotonic
::  snapshot counter (the snapshot's stable identity). An optional
::  freeform note rides alongside. Content-addressed, so an axis that
::  didn't change dedupes to a no-op firm. The counter is the only label
::  — no version-derived tagging. Every live-mutating action snapshots
::  first, so this is the universal "save the world" primitive.
::
::  wipe-history: tombstone every firmed revision of the /desk fold
::  except the live top — a clean slate before the baseline snapshot.
::
++  wipe-history
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  hist=(each binfo tang)  bind:m  (born:io (nex-road:io rail [%| /desk]))
  ?:  ?=(%| -.hist)  (pure:m ~)
  =/  uds=(list @ud)  (turn p.hist |=([=cass:clay *] ud.cass))
  =/  top=@ud  (roll uds max)
  =/  targets=(list @ud)  (skip uds |=(u=@ud =(u top)))
  |-  ^-  form:m
  ?~  targets  (pure:m ~)
  ;<  ~  bind:m  (lose:io (nex-road:io rail [%| /desk]) [%numb `i.targets `i.targets])
  $(targets t.targets)
::  initial-snapshot: take the baseline snapshot iff none exist yet (the
::  counter is still 0). Wipes any prior /desk history first — resetting
::  the counter throws the history away, so snapshot 0 is a clean slate.
::  Idempotent across restarts.
::
++  initial-snapshot
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  n=(unit @ud)  bind:m
    (peek-as:io (nex-road:io rail [%& / %'snapshot.ud']) ,@ud)
  ?.  =(0 (fall n 0))  (pure:m ~)
  ;<  ~  bind:m  (wipe-history rail)
  (do-snapshot rail)
::
++  do-snapshot
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  n=(unit @ud)  bind:m
    (peek-as:io (nex-road:io rail [%& / %'snapshot.ud']) ,@ud)
  =/  num=@ud  (fall n 0)
  ::  one firm of /desk captures the whole world — snapshotting a path
  ::  recursively firms everything beneath it, so /desk/code and
  ::  /desk/data ride along. One revision, one number.
  ;<  ~  bind:m  (checkpoint:io (nex-road:io rail [%| /desk]))
  ::  a firm of UNCHANGED content dedupes to the existing top revision —
  ::  which, if the world hasn't moved since the last snapshot, is already
  ::  a snapshot (carries a numeric tag). Capturing the same world twice is
  ::  the SAME snapshot: no relabel, no counter bump. Only a genuinely new
  ::  top (fresh, untagged) earns a new number.
  ;<  hist=(each binfo tang)  bind:m  (born:io (nex-road:io rail [%| /desk]))
  ?:  (top-is-snap hist)
    ~&  >  %desk-snapshot-unchanged
    (pure:m ~)
  ~&  >  [%desk-snapshot num=num]
  ::  stamp the world's current version as a `version: <contents>` label —
  ::  a convention, not identity. The `version: ` prefix keeps it non-numeric
  ::  so it never shadows the numeric identity tag (+num-tag / +snap-cass).
  ;<  ver=(unit @t)  bind:m  (own-version rail)
  =/  tags=(set @t)
    =/  base=(set @t)  (sy ~[(scot %ud num)])
    ?~  ver  base
    ?:  =('' u.ver)  base
    (~(put in base) (cat 3 'version: ' u.ver))
  ;<  ~  bind:m  (tag:io (nex-road:io rail [%| /desk]) ~ tags)
  ::  tag with the current counter, then bump — snapshots are 0-based
  (over:io (nex-road:io rail [%& / %'snapshot.ud']) [[/ %ud] +(num)])
::  top-is-snap: does the newest /desk revision already carry a numeric
::  (identity) tag — i.e. is the current world already a snapshot?
::
++  top-is-snap
  |=  hist=(each binfo tang)
  ^-  ?
  ?:  ?=(%| -.hist)  %.n
  =/  top=(unit binfo-entry)
    %+  roll  `binfo`p.hist
    |=  [e=binfo-entry a=(unit binfo-entry)]
    ?~  a  `e
    ?:((gth ud.cass.e ud.cass.u.a) `e a)
  ?~  top  %.n
  ?&  !tomb.u.top
      ?=(^ (skim ~(tap in tags.u.top) num-tag))
  ==
::
::  +version-text: render a version file's content as text, by mark.
::  ~ for marks with no text rendering.
::
::  +file-text: render any file's stored form as text for the viewer.
::  Tries the common text shapes in turn; ~ for genuinely binary files
::  (their noun is a cell, so none of the atom/list molds match).
::
++  file-text
  |=  =sang:tarball
  ^-  (unit @t)
  ::  sang-noun returns the raw stored noun even for a boom, so we can
  ::  re-interpret it with the CURRENT marks (molds in this context)
  ::  rather than the revision's — a file that failed to build against
  ::  its old bins still renders here.
  =/  nun  (sang-noun:tarball sang)
  =/  c  ((soft @t) nun)
  ?^  c  `u.c
  =/  t  ((soft tape) nun)
  ?^  t  `(crip u.t)
  =/  w  ((soft wain) nun)
  ?^  w  `(of-wain:format u.w)
  =/  j  ((soft json) nun)
  ?^  j  `(en:json:html u.j)
  ~
::
++  quay-get
  |=  [args=quay:eyre k=@t]
  ^-  (unit @t)
  =/  l  (skim args |=([p=@t q=@t] =(p k)))
  ?~(l ~ `q.i.l)
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
    ::  version.json is arbitrary json, but we expect a 'version'
    ::  property whose value is text-convertible (a string or number).
    ::  A bare string/number version file is accepted too.
    =/  j  ((soft json) nun)
    ?~  j  ~
    =/  v=(unit json)
      ?:(?=([%o *] u.j) (~(get by p.u.j) 'version') `u.j)
    ?~  v  ~
    ?+  -.u.v  ~
      %s  `p.u.v
      %n  `p.u.v
    ==
  ==
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
::  +checkout-cass: the revision currently checked out (~ = live only)
::
++  checkout-snap
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(unit @ud))
  ^-  form:m
  ;<  co=(unit (unit @ud))  bind:m
    (peek-as:io (nex-road:io rail [%& / %'checkout.desk_snap']) ,(unit @ud))
  (pure:m ?~(co ~ u.co))
::  +axis-dir: which directory to READ for an axis — its live dir, or
::  /checkout/<axis> when a world snapshot is checked out.
::
++  axis-dir
  |=  [=rail:tarball axis=?(%code %data) live=?]
  ^-  path
  ?:  live  ?:(?=(%code axis) /desk/code /desk/data)
  ?:(?=(%code axis) /checkout/code /checkout/data)
::  +locate-file: find one bfile by full path within an axis dir
::
++  locate-file
  |=  [=rail:tarball dir=path cas=(unit case:nexus) full=path]
  =/  m  (fiber:fiber:nexus ,(unit bfile))
  ^-  form:m
  ;<  files=(unit (list bfile))  bind:m  (fetch-dir rail dir cas)
  ?~  files  (pure:m ~)
  |-  ^-  form:m
  ?~  u.files  (pure:m ~)
  ?:  =(full (snoc pax.i.u.files name.i.u.files))  (pure:m `i.u.files)
  $(u.files t.u.files)
::  +mime-of: a file's mark-converted mime form (~ if no mime tube)
::
++  mime-of
  |=  [=rail:tarball dir=path cas=(unit case:nexus) f=bfile]
  =/  m  (fiber:fiber:nexus ,(unit mime))
  ^-  form:m
  =/  froad=road:tarball  (nex-road:io rail [%& (weld dir pax.f) name.f])
  ;<  mv=view:nexus  bind:m
    ?~  cas  (peek:io froad `[/ %mime])
    (peek-at:io froad `[/ %mime] u.cas)
  =/  via-tube=(unit mime)
    ?.  ?=([%file *] mv)  ~
    =/  res  (mule |.(!<(mime (need-vase:tarball sang.mv))))
    ?:(?=(%| -.res) ~ `p.res)
  ?^  via-tube  (pure:m via-tube)
  ::  the mark's ++mime tube failed (e.g. absent from the revision's
  ::  bins). But if the file's stored noun already IS a mime, use it
  ::  directly — the present interpretation, no old mark needed.
  (pure:m ((soft mime) (sang-noun:tarball sang.f)))
::
::  snap-cass: the /desk fold revision tagged `snapshot N`
::
++  snap-cass
  |=  [hist=(each binfo tang) n=@ud]
  ^-  (unit cass:clay)
  ?:  ?=(%| -.hist)  ~
  =/  tag=@t  (scot %ud n)
  |-  ^-  (unit cass:clay)
  ?~  p.hist  ~
  ?:  (~(has in tags.i.p.hist) tag)  `cass.i.p.hist
  $(p.hist t.p.hist)
::  snap-tags: the full tag set on the /desk revision for snapshot N (~ if
::  absent). Includes the numeric identity tag; +user-tags strips that.
::
++  snap-tags
  |=  [hist=(each binfo tang) n=@ud]
  ^-  (unit (set @t))
  ?:  ?=(%| -.hist)  ~
  =/  tag=@t  (scot %ud n)
  |-  ^-  (unit (set @t))
  ?~  p.hist  ~
  ?:  (~(has in tags.i.p.hist) tag)  `tags.i.p.hist
  $(p.hist t.p.hist)
::  num-tag: a purely-numeric tag is a snapshot's structural identity, not
::  a user label — those are reserved so they can't shadow +snap-cass.
::
++  num-tag
  |=  t=@t
  ^-  ?
  ?=(^ (rush t dem))
::  user-tags: the freeform labels on a snapshot (all non-numeric tags),
::  sorted for stable display.
::
++  user-tags
  |=  tags=(set @t)
  ^-  (list @t)
  (sort (skip ~(tap in tags) num-tag) aor)
::
::  snap-cass-of: the /desk fold revision for world snapshot N
::
++  snap-cass-of
  |=  [=rail:tarball n=@ud]
  =/  m  (fiber:fiber:nexus ,(unit cass:clay))
  ^-  form:m
  ;<  hist=(each binfo tang)  bind:m  (born:io (nex-road:io rail [%| /desk]))
  (pure:m (snap-cass hist n))
::  snap-files: the whole /desk subtree as of snapshot N — files with
::  paths rooted at /desk (e.g. /code/lib/foo.hoon, /data/bar). Peek
::  /desk (not the subdir) at the case: resolve-case is per-hist, so
::  only /desk's own hist carries N.
::
++  snap-files
  |=  [=rail:tarball n=@ud]
  =/  m  (fiber:fiber:nexus ,(unit (list bfile)))
  ^-  form:m
  ;<  cs=(unit cass:clay)  bind:m  (snap-cass-of rail n)
  ?~  cs  (pure:m ~)
  (fetch-dir rail /desk `[%ud ud.u.cs])
::  snap-nums: every world snapshot number present in the /desk history
::
++  snap-nums
  |=  hist=(each binfo tang)
  ^-  (list @ud)
  ?:  ?=(%| -.hist)  ~
  %+  murn  p.hist
  |=  [=cass:clay tags=(set @t) tomb=?]
  ^-  (unit @ud)
  ?:  tomb  ~
  =/  ns=(list @ud)  (murn ~(tap in tags) |=(t=@t (rush t dem)))
  ?~(ns ~ `i.ns)
::  clear-snap: tombstone world snapshot N (one /desk fold revision)
::
++  clear-snap
  |=  [=rail:tarball n=@ud]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cs=(unit cass:clay)  bind:m  (snap-cass-of rail n)
  ?~  cs  (pure:m ~)
  (lose:io (nex-road:io rail [%| /desk]) [%numb `ud.u.cs `ud.u.cs])
::  set-snap-tag: add (put=%.y) or remove (put=%.n) one freeform label on
::  snapshot N. Reads the revision's current tag set and rewrites it whole
::  — %tag is replace-semantics — so the numeric identity tag rides along
::  untouched.
::
++  set-snap-tag
  |=  [=rail:tarball n=@ud label=@t put=?]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  hist=(each binfo tang)  bind:m  (born:io (nex-road:io rail [%| /desk]))
  =/  cs=(unit cass:clay)  (snap-cass hist n)
  ?~  cs  (pure:m ~)
  =/  cur=(set @t)  (fall (snap-tags hist n) ~)
  =/  new=(set @t)  ?:(put (~(put in cur) label) (~(del in cur) label))
  (tag:io (nex-road:io rail [%| /desk]) `[%ud ud.u.cs] new)
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
::  live-sub-bole: the current /desk/<axis> subtree as a BOLE — neck-
::  PRESERVING (ball-to-bole keeps every neck/weir), unlike ball-to-files.
::
++  live-sub-bole
  |=  [=rail:tarball axis=@ta]
  =/  m  (fiber:fiber:nexus ,bole:tarball)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io (nex-road:io rail [%| /desk/[axis]]) ~)
  ?.  ?=([%ball *] view)  (pure:m *bole:tarball)
  (pure:m (ball-to-bole:tarball ball.view))
::  snap-sub-bole: the /desk/<axis> subtree at world snapshot N as a BOLE,
::  neck-PRESERVING. Peek /desk deep (resolve-case is per-hist, so N only
::  resolves on /desk's own hist), then descend to /<axis>. Empty bole if
::  the snapshot or its subtree is absent.
::
++  snap-sub-bole
  |=  [=rail:tarball axis=@ta n=@ud]
  =/  m  (fiber:fiber:nexus ,bole:tarball)
  ^-  form:m
  ;<  cs=(unit cass:clay)  bind:m  (snap-cass-of rail n)
  ?~  cs  (pure:m *bole:tarball)
  ;<  =view:nexus  bind:m
    (peek-at:io (nex-road:io rail [%| /desk]) ~ [%ud ud.u.cs])
  ?.  ?=([%ball *] view)  (pure:m *bole:tarball)
  (pure:m (ball-to-bole:tarball (~(dip ba:tarball ball.view) [axis ~])))
::  do-compose: build a new LIVE world by choosing where code and data
::  come from, independently. code from {live | snapshot N | none};
::  data from {live | snapshot M}. Snapshots the current world first (so
::  nothing is lost), then rebuilds /desk WHOLE — a single cull + make of
::  the assembled [code data] bole, so both axes reload together and there
::  is no code-before-data ordering to get wrong. Every subtree rides as a
::  neck-PRESERVING bole, so data sub-nexuses land GOVERNED, not as dead
::  files, and /desk/code keeps its [/ %code] neck.
::
++  do-compose
  |=  [eyre-id=@ta body=@t =rail:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  jon=(unit json)  (de:json:html body)
  ?.  &(?=(^ jon) ?=([%o *] u.jon))
    ;<  ~  bind:m  (respond eyre-id rail 400 'bad body')
    (pure:m ~)
  =/  code-src=?(%live %none [%snap @ud])
    =/  c  (~(get by p.u.jon) 'code')
    ?:  ?=([~ %s %none] c)  %none
    ?:  ?=([~ %n *] c)  [%snap (rash p.u.c dem)]
    %live
  =/  data-src=?(%live [%snap @ud])
    =/  d  (~(get by p.u.jon) 'data')
    ?:  ?=([~ %n *] d)  [%snap (rash p.u.d dem)]
    %live
  ~&  >  [%desk-compose code=code-src data=data-src]
  ::  snapshot the current world first — this recomposition is recoverable
  ;<  ~  bind:m  (do-snapshot rail)
  ::  resolve each axis as a neck-preserving bole. %none code = a fresh,
  ::  empty /code nexus (keeps its neck so it's inert but well-formed).
  ;<  code-bole=bole:tarball  bind:m
    ?-  code-src
      %live      (live-sub-bole rail %code)
      %none      (pure:(fiber:fiber:nexus ,bole:tarball) [`[`[/ %code] ~ %.n ~] ~])
      [%snap *]  (snap-sub-bole rail %code +.code-src)
    ==
  ;<  data-bole=bole:tarball  bind:m
    ?-  data-src
      %live      (live-sub-bole rail %data)
      [%snap *]  (snap-sub-bole rail %data +.data-src)
    ==
  ::  assemble the whole /desk: a plain container holding the two subtrees
  =/  desk-bole=bole:tarball
    :-  `[~ ~ %.n ~]
    %-  malt
    ^-  (list [@ta bole:tarball])
    ~[[%code code-bole] [%data data-bole]]
  ::  rebuild /desk in one shot — cull (snapshots live on the fold hist, so
  ::  they survive) then make the assembled bole, reloading both axes at once
  ;<  ~  bind:m  (cull:io (nex-road:io rail [%| /desk]))
  ;<  ~  bind:m  (make:io (nex-road:io rail [%| /desk]) &+desk-bole)
  ~&  >  %desk-compose-done
  (respond eyre-id rail 200 'composed')
::
++  json-num
  |=  j=(unit json)
  ^-  (unit @ud)
  ?.  ?=([~ %n *] j)  ~
  `(rash p.u.j dem)
::
++  json-str
  |=  j=(unit json)
  ^-  (unit @t)
  ?.  ?=([~ %s *] j)  ~
  `p.u.j
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
  |=  [eyre-id=@ta suffix=path args=quay:eyre =rail:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?:  ?=([%cat ?(%code %data) *] suffix)
    ::  one file's content (?path=/lib/foo.hoon), read from the axis'
    ::  live dir or /checkout when a revision is checked out. Converts
    ::  via the file's mark to a mime: text types come back as text;
    ::  others expose their content-type so the UI can <img> them.
    =/  dir=path  (axis-dir rail i.t.suffix =('live' (fall (quay-get args 'mode') 'live')))
    =/  want=(unit @t)  (quay-get args 'path')
    ?~  want
      ;<  ~  bind:m  (respond eyre-id rail 400 'path required')
      (pure:m ~)
    =/  full=path  (stab u.want)
    ;<  hit=(unit bfile)  bind:m  (locate-file rail dir ~ full)
    ?~  hit
      ;<  ~  bind:m  (respond eyre-id rail 404 'no such file')
      (pure:m ~)
    ;<  got=(unit mime)  bind:m  (mime-of rail dir ~ u.hit)
    ::  spud a mite -> "/text/x-hoon"; drop the leading slash
    =/  ctype=@t  ?~(got '' (crip (slag 1 (spud p.u.got))))
    =/  head=@ta  ?~(got %$ ?~(p.u.got %$ i.p.u.got))
    =/  texty=?
      &(?|(=(%text head) =(%application head)) !=('application/octet-stream' ctype))
    =/  blotp=tape  (spud (snoc path.p.sang.u.hit name.p.sang.u.hit))
    =/  text=(unit @t)
      ?~  got  (file-text sang.u.hit)
      ?:(texty `q.q.u.got ~)
    ::  when nothing renders, say exactly why (shown verbatim in the UI)
    =/  reason=@t
      ?:  ?=(%| -.q.sang.u.hit)
        ::  boom: the stored noun failed to build under its blot. The
        ::  failure carries the compiler's error trace — surface it.
        =/  bm=boom:tarball  p.q.sang.u.hit
        =/  trace=@t
          %-  of-wain:format
          %+  turn  (flop tang.bm)
          |=(=tank (crip ~(ram re tank)))
        %-  crip
        ;:  weld
          "blot "  blotp
          " failed to build (boom) — the stored noun did not validate against its blot:\0a"
          (trip trace)
        ==
      ?~  got
        =/  nun  (sang-noun:tarball sang.u.hit)
        %-  crip
        ;:  weld
          "blot "  blotp
          " has no ++mime grow tube, and its stored noun "
          ?:  ?=(@ nun)
            (weld "is a bare " (weld (scow %ud (met 3 nun)) "-byte atom"))
          "is a cell"
          " — not decodable as cord, tape, wain, or json"
        ==
      %-  crip
      ;:  weld
        "content-type "  (trip ctype)  ", "  (scow %ud p.q.u.got)
        " bytes — a non-text, non-image type with no inline renderer"
      ==
    =/  =json
      %-  pairs:enjs:format
      :~  ['path' s+(spat full)]
          ['blot' s+(spat (snoc path.p.sang.u.hit name.p.sang.u.hit))]
          ['type' ?~(got ~ s+ctype)]
          ['text' ?~(text ~ s+u.text)]
          ['reason' ?~(text s+reason ~)]
      ==
    =/  bod=octs  (as-octs:mimes:html (en:json:html json))
    ;<  ~  bind:m  (~(send-simple http-res:io (nex-road:io rail [%& ~ %'main.sig'])) eyre-id (mime-response:http-utils [/application/json bod]))
    (pure:m ~)
  ?:  ?=([%raw ?(%code %data) *] suffix)
    ::  raw bytes of one file, in its mark's mime form — for <img> etc.
    =/  dir=path  (axis-dir rail i.t.suffix =('live' (fall (quay-get args 'mode') 'live')))
    =/  want=(unit @t)  (quay-get args 'path')
    ?~  want
      ;<  ~  bind:m  (respond eyre-id rail 400 'path required')
      (pure:m ~)
    =/  full=path  (stab u.want)
    ;<  hit=(unit bfile)  bind:m  (locate-file rail dir ~ full)
    ?~  hit
      ;<  ~  bind:m  (respond eyre-id rail 404 'no such file')
      (pure:m ~)
    ;<  got=(unit mime)  bind:m  (mime-of rail dir ~ u.hit)
    ?~  got
      ;<  ~  bind:m  (respond eyre-id rail 404 'no mime form')
      (pure:m ~)
    ;<  ~  bind:m  (~(send-simple http-res:io (nex-road:io rail [%& ~ %'main.sig'])) eyre-id (mime-response:http-utils u.got))
    (pure:m ~)
  ?:  ?=([%tree ?(%code %data) *] suffix)
    ::  file tree of an axis — its live dir, or /checkout when checked out
    =/  dir=path  (axis-dir rail i.t.suffix =('live' (fall (quay-get args 'mode') 'live')))
    ;<  files=(unit (list bfile))  bind:m  (fetch-dir rail dir ~)
    ?~  files
      ;<  ~  bind:m  (respond eyre-id rail 404 'no tree')
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
    ::  data endpoint: source, version, the world snapshot list, sharing,
    ::  and which snapshot (if any) is checked out
    ;<  src-json=(unit json)  bind:m
      (peek-as:io (nex-road:io rail [%& / %'source.json']) ,json)
    ;<  ver=(unit @t)  bind:m  (own-version rail)
    ::  the world snapshot list is the /desk fold's tagged history
    ;<  desk-born=(each binfo tang)  bind:m
      (born:io (nex-road:io rail [%| /desk]))
    ;<  share=(unit (set path))  bind:m
      (peek-as:io (nex-road:io rail [%& / %'share.usergroups']) ,(set path))
    ;<  co=(unit @ud)  bind:m  (checkout-snap rail)
    =/  =json
      %-  pairs:enjs:format
      :~  ['source' (fall src-json ~)]
          ['version' ?~(ver ~ s+u.ver)]
          ['snapshots' (snaps-to-json desk-born)]
          ['share' a+(turn ~(tap in (fall share ~)) |=(g=path s+(spat g)))]
          ['checkout' ?~(co ~ (numb:enjs:format u.co))]
          ::  live differs from the top snapshot — a fresh Snapshot Now would
          ::  actually capture something (else it dedupes to a no-op)
          ['dirty' b+!(top-is-snap desk-born)]
      ==
    =/  bod=octs  (as-octs:mimes:html (en:json:html json))
    ;<  ~  bind:m  (~(send-simple http-res:io (nex-road:io rail [%& ~ %'main.sig'])) eyre-id (mime-response:http-utils [/application/json bod]))
    (pure:m ~)
  ::  everything else is a static asset from /ui — the shell (index.html)
  ::  for the page route, or style.css / app.js by name.
  =/  filename=@ta  ?~(suffix 'index.html' i.suffix)
  ;<  fv=view:nexus  bind:m
    (peek:io (nex-road:io rail [%& /ui filename]) `[/ %mime])
  ?.  ?=([%file *] fv)
    (respond eyre-id rail 404 'Not found')
  =/  =mime  !<(mime (need-vase:tarball sang.fv))
  ;<  ~  bind:m
    (~(send-simple http-res:io (nex-road:io rail [%& ~ %'main.sig'])) eyre-id (mime-response:http-utils mime))
  (pure:m ~)
::
::  snaps-to-json: the world snapshot list from an axis's born — each
::  `snapshot N` tag becomes {n, da}, newest first.
::
++  snaps-to-json
  |=  res=(each binfo tang)
  ^-  json
  :-  %a
  ?:  ?=(%| -.res)  ~
  =/  snaps=(list [n=@ud da=@da tags=(list @t)])
    %+  murn  p.res
    |=  [=cass:clay tags=(set @t) tomb=?]
    ^-  (unit [n=@ud da=@da tags=(list @t)])
    ?:  tomb  ~
    =/  ns=(list @ud)  (murn ~(tap in tags) |=(t=@t (rush t dem)))
    ?~(ns ~ `[i.ns da.cass (user-tags tags)])
  %+  turn  (sort snaps |=([a=[n=@ud *] b=[n=@ud *]] (gth n.a n.b)))
  |=  [n=@ud da=@da tags=(list @t)]
  %-  pairs:enjs:format
  :~  ['n' (numb:enjs:format n)]
      ['da' (time:enjs:format da)]
      ['tags' a+(turn tags |=(t=@t s+t))]
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
    ::  set (or clear) the desk's source. Body is {version, code} to
    ::  follow, or {}/null to go standalone. Normalized through the
    ::  source-config contract (both paths required) before it lands.
    =/  jon=json  (fall (de:json:html body) ~)
    =/  clean=json  (source-to-json (json-to-source jon))
    ~&  >  [%desk-set-source clean]
    ;<  ~  bind:m
      (poke:io (nex-road:io rail [%& / %'source.json']) [[/ %json] clean])
    (respond eyre-id rail 200 'ok')
  ::
      [%compose ~]
    (do-compose eyre-id body rail)
  ::
      [%share ~]
    ::  open/close a usergroup. Body is the command json
    ::  {add|remove: <group-path>} — forwarded straight to the
    ::  share.usergroups grub, which stamps its state and re-grants.
    =/  cmd=(unit json)  (de:json:html body)
    ?~  cmd
      ;<  ~  bind:m  (respond eyre-id rail 400 'bad share command')
      (pure:m ~)
    ~&  >  [%desk-share u.cmd]
    ;<  ~  bind:m
      (poke:io (nex-road:io rail [%& / %'share.usergroups']) [[/ %json] u.cmd])
    (respond eyre-id rail 200 'ok')
  ::
      [%checkout ~]
    ::  drive the checkout grub. Body {n: N} checks that world snapshot
    ::  out into /checkout; {} (or null) clears back to live.
    =/  cmd=(unit json)  (de:json:html body)
    ?~  cmd
      ;<  ~  bind:m  (respond eyre-id rail 400 'bad checkout command')
      (pure:m ~)
    ~&  >  [%desk-checkout-poke u.cmd]
    ;<  ~  bind:m
      (poke:io (nex-road:io rail [%& / %'checkout.desk_snap']) [[/ %json] u.cmd])
    (respond eyre-id rail 200 'ok')
  ::
      [%fetch-latest ~]
    ::  pull the source's current code and version now. Idempotent:
    ::  content-addressed writes no-op when nothing changed, so this
    ::  only creates history when the source actually differs.
    ;<  src-json=(unit json)  bind:m
      (peek-as:io (nex-road:io rail [%& / %'source.json']) ,json)
    =/  config=source-config
      ?~(src-json ~ (json-to-source u.src-json))
    ?~  config
      ;<  ~  bind:m  (respond eyre-id rail 400 'no source configured')
      (pure:m ~)
    =/  ver-road=road:tarball    (parse-source-file version.u.config)
    =/  code-road=road:tarball   (parse-source code.u.config)
    =/  ver-name=@ta             (rear (parse-path version.u.config))
    ~&  >  [%desk-fetch-latest version.u.config code.u.config]
    ::  snapshot the current world, then pull the latest release
    ;<  ~  bind:m  (do-snapshot rail)
    ;<  ~  bind:m  (sync-release ver-road code-road ver-name rail)
    (respond eyre-id rail 200 'fetched')
  ::
      [%snapshot ~]
    ::  take a world snapshot now (both axes together)
    ;<  ~  bind:m  (do-snapshot rail)
    (respond eyre-id rail 200 'snapshotted')
  ::
      [%clear ~]
    ::  drop world snapshot N — tombstone the fold entry tagged
    ::  `snapshot N` on BOTH axes. The runtime refuses the live top.
    =/  jon=(unit json)  (de:json:html body)
    =/  n=(unit @ud)
      ?.  &(?=(^ jon) ?=([%o *] u.jon))  ~
      (json-num (~(get by p.u.jon) 'n'))
    ?~  n
      ;<  ~  bind:m  (respond eyre-id rail 400 'need n')
      (pure:m ~)
    ~&  >  [%desk-clear n=u.n]
    ;<  ~  bind:m  (clear-snap rail u.n)
    (respond eyre-id rail 200 'cleared')
  ::
      [%clear-until ~]
    ::  bulk drop: every snapshot, or every one at/below N (inclusive).
    ::  The latest snapshot is always spared — it is the live top.
    =/  jon=(unit json)  (de:json:html body)
    =/  before=(unit @ud)
      ?.  &(?=(^ jon) ?=([%o *] u.jon))  ~
      (json-num (~(get by p.u.jon) 'before'))
    ;<  hist=(each binfo tang)  bind:m  (born:io (nex-road:io rail [%| /desk]))
    =/  nums=(list @ud)  (snap-nums hist)
    =/  top=@ud  (roll nums max)
    =/  targets=(list @ud)
      %+  skim  nums
      |=(n=@ud &(!=(n top) ?|(?=(~ before) (lte n u.before))))
    ~&  >  [%desk-clear-until before=before count=(lent targets)]
    |-  ^-  form:m
    ?~  targets  (respond eyre-id rail 200 'cleared')
    ;<  ~  bind:m  (clear-snap rail i.targets)
    $(targets t.targets)
  ::
      [%tag-add ~]
    ::  add a freeform label to snapshot N. Numeric labels are reserved
    ::  (they are snapshot identity), so those are refused.
    =/  jon=(unit json)  (de:json:html body)
    ?.  &(?=(^ jon) ?=([%o *] u.jon))
      (respond eyre-id rail 400 'bad body')
    =/  n=(unit @ud)     (json-num (~(get by p.u.jon) 'n'))
    =/  label=(unit @t)  (json-str (~(get by p.u.jon) 'tag'))
    ?~  n      (respond eyre-id rail 400 'need n')
    ?~  label  (respond eyre-id rail 400 'need tag')
    ?:  =('' u.label)  (respond eyre-id rail 400 'empty tag')
    ?:  (num-tag u.label)
      (respond eyre-id rail 400 'numeric tags are reserved')
    ;<  ~  bind:m  (set-snap-tag rail u.n u.label %.y)
    (respond eyre-id rail 200 'tagged')
  ::
      [%tag-del ~]
    ::  remove a freeform label from snapshot N.
    =/  jon=(unit json)  (de:json:html body)
    ?.  &(?=(^ jon) ?=([%o *] u.jon))
      (respond eyre-id rail 400 'bad body')
    =/  n=(unit @ud)     (json-num (~(get by p.u.jon) 'n'))
    =/  label=(unit @t)  (json-str (~(get by p.u.jon) 'tag'))
    ?~  n      (respond eyre-id rail 400 'need n')
    ?~  label  (respond eyre-id rail 400 'need tag')
    ;<  ~  bind:m  (set-snap-tag rail u.n u.label %.n)
    (respond eyre-id rail 200 'untagged')
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
--
