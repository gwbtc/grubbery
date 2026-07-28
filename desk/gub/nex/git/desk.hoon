::  git/desk nexus: install a desk from a public git repository
::
::  Clone a GitHub repo, check out its /code/ into a desk with
::  checkpoint safety. bill.json bootstraps nexus entries in
::  /desk/data on first install.
::
::  Updates are version-gated: the repo's version.json contains a
::  version number, and the desk only re-syncs when that number is
::  higher than the current version.ud. Code can change freely on
::  the remote — the desk won't update until the author bumps the
::  version. Manual sync via poke always runs regardless of version.
::
::  Optional polling (config.poll, in minutes) fetches the repo on
::  an interval and applies the version check automatically.
::
::  Config: /config.json with fields:
::    repo:   owner/repo (e.g. "niblyx-malnus/lick-test-nexus")
::    ref:    branch or tag (e.g. "main")
::    poll:   polling interval in minutes (0 = off)
::    public: whether the desk's code namespace is publicly readable
::
/<  git-pack  /lib/git/pack.hoon
/<  git-repo  /lib/git/repository.hoon
/<  git-transport  /lib/git/transport.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  code-dir=bole:tarball  [`[`[/ %code] ~ %.n ~] ~]
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'config.json'] [[/ %json] (config-to-json *git-desk-config)]]
          [%fall %& [/ %'sync.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'push.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'poll.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%fall %| /desk empty-dir:loader]
          [%fall %| /desk/code code-dir]
          [%fall %| /desk/data empty-dir:loader]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          [~ %'config.json']
        ~&  >>  %git-desk-config-fiber-start
        ;<  ~  bind:m  (rise-wait:io prod "%git/desk config: failed")
        ;<  ~  bind:m  reg-register:io
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  nex-dir=path  path.here
        ~&  >>  [%git-desk-config-at nex-dir]
        ;<  config-json=json  bind:m  (get-state-as:io ,json)
        =/  config=git-desk-config  (json-to-config config-json)
        ;<  ~  bind:m
          ?.  !=('' repo.config)  (pure:m ~)
          ::  first install only: sync if the desk has never been
          ::  synced (no version.ud). after that, pulls are manual
          ::  (sync.sig) or via the opt-in poll — a config edit (e.g.
          ::  setting the push token) must never clobber live desk
          ::  edits with a surprise checkout.
          ;<  ver=(unit @ud)  bind:m
            (peek-as:io (nex-road:io rail [%& / %'version.ud']) ,@ud)
          ?^  ver  (pure:m ~)
          ~&  >>  %git-desk-boot-sync
          (poke:io (nex-road:io rail [%& / %'sync.sig']) [[/ %sig] ~])
        |-
        ;<  config-json=json  bind:m  (get-state-as:io ,json)
        ~&  >>  [%git-desk-config-read config-json]
        =/  config=git-desk-config  (json-to-config config-json)
        ;<  ~  bind:m
          %-  reg-how:io
          ?:  public.config
            :-  /public
            :+  ~  ~
            %-  sy
            :~  [%& %& nex-dir %'version.ud']
                [%& %| (weld nex-dir /desk/code)]
            ==
          [/public *weir:nexus]
        ~&  >>  %git-desk-config-waiting-for-poke
        ;<  =sage:tarball  bind:m  take-poke:io
        ~&  >>  [%git-desk-config-poke-received p.sage]
        =/  new-json=json  !<(json q.sage)
        ;<  ~  bind:m  (replace:io new-json)
        $
          ::  poll.sig: watch config, poke sync.sig on interval
          ::
          ::  push.sig: commit the live /desk/code tree to a GitHub
          ::  branch via the REST API — the remote is the object
          ::  store, so no local git data is needed. poke json:
          ::  {branch, message?}. the branch is created off the
          ::  config ref if it doesn't exist. text files only (the
          ::  trees api takes inline content).
          ::
          [~ %'push.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/desk push: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        =/  branch=@t  (jstr jon 'branch')
        =/  msg=@t
          =/  t=@t  (jstr jon 'message')
          ?:(=('' t) 'update from ship' t)
        ?:  =('' branch)
          ~&  >>>  "%git/desk push: branch required"
          $
        ;<  config-json=(unit json)  bind:m
          (peek-as:io (nex-road:io rail [%& / %'config.json']) ,json)
        =/  config=git-desk-config
          ?~(config-json *git-desk-config (json-to-config u.config-json))
        ?:  |(=('' repo.config) =('' token.config))
          ~&  >>>  "%git/desk push: repo and token required in config"
          $
        =/  base-branch=@t  ?:(=('' ref.config) 'main' ref.config)
        ;<  files=(unit (list bfile))  bind:m  (fetch-dir rail /desk/code ~)
        =/  entries=(list [pax=tape txt=@t])
          %+  murn  (fall files ~)
          |=  b=bfile
          ^-  (unit [tape @t])
          =/  txt=(unit @t)  (bfile-text b)
          ?~  txt  ~
          `[(repo-path pax.b name.b) u.txt]
        ?:  =(~ entries)
          ~&  >>>  "%git/desk push: nothing to push"
          $
        ~&  >  [%git-desk-push (lent entries) %files %to branch]
        =/  api=@t  'https://api.github.com'
        =/  hdr  (gh-headers-d token.config)
        ;<  [st=@ud base-jon=json]  bind:m
          (gh-call %'GET' (repo-url api repo.config (cat 3 '/git/ref/heads/' base-branch)) hdr ~)
        ?.  =(200 st)
          ~&  >>>  [%git-desk-push %no-base-ref st]
          $
        =/  base-sha=@t  (ref-sha base-jon)
        ;<  [st2=@ud com-jon=json]  bind:m
          (gh-call %'GET' (repo-url api repo.config (cat 3 '/git/commits/' base-sha)) hdr ~)
        ?.  =(200 st2)
          ~&  >>>  [%git-desk-push %no-base-commit st2]
          $
        =/  base-tree=@t  (commit-tree-sha com-jon)
        =/  tree-body=json
          :-  %o
          %-  ~(gas by *(map @t json))
          :~  ['base_tree' s+base-tree]
              :-  'tree'
              :-  %a
              %+  turn  entries
              |=  [pax=tape txt=@t]
              %-  pairs:enjs:format
              :~  ['path' s+(crip pax)]
                  ['mode' s+'100644']
                  ['type' s+'blob']
                  ['content' s+txt]
              ==
          ==
        ;<  [st3=@ud tree-jon=json]  bind:m
          (gh-call %'POST' (repo-url api repo.config '/git/trees') hdr `tree-body)
        ?.  =(201 st3)
          ~&  >>>  [%git-desk-push %tree-failed st3]
          $
        =/  tree-sha=@t  (obj-sha tree-jon)
        =/  commit-body=json
          %-  pairs:enjs:format
          :~  ['message' s+msg]
              ['tree' s+tree-sha]
              ['parents' a+~[s+base-sha]]
          ==
        ;<  [st4=@ud com2=json]  bind:m
          (gh-call %'POST' (repo-url api repo.config '/git/commits') hdr `commit-body)
        ?.  =(201 st4)
          ~&  >>>  [%git-desk-push %commit-failed st4]
          $
        =/  new-sha=@t  (obj-sha com2)
        ;<  [st5=@ud *]  bind:m
          (gh-call %'GET' (repo-url api repo.config (cat 3 '/git/ref/heads/' branch)) hdr ~)
        ;<  [st6=@ud *]  bind:m
          ?:  =(200 st5)
            %-  gh-call
            :^    %'PATCH'
                (repo-url api repo.config (cat 3 '/git/refs/heads/' branch))
              hdr
            `(pairs:enjs:format ~[['sha' s+new-sha] ['force' b+%.n]])
          %-  gh-call
          :^    %'POST'
              (repo-url api repo.config '/git/refs')
            hdr
          `(pairs:enjs:format ~[['ref' s+(cat 3 'refs/heads/' branch)] ['sha' s+new-sha]])
        ?.  |(=(200 st6) =(201 st6))
          ~&  >>>  [%git-desk-push %ref-failed st6]
          $
        ~&  >  [%git-desk-push %done branch (crip (scag 7 (trip new-sha)))]
        $
          ::
          [~ %'poll.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/desk poll: failed")
        ;<  *  bind:m
          (keep:io /cfg (nex-road:io rail [%& / %'config.json']) `[/ %json])
        |-
        ;<  config-json=(unit json)  bind:m
          (peek-as:io (nex-road:io rail [%& / %'config.json']) ,json)
        =/  config=git-desk-config
          ?~(config-json *git-desk-config (json-to-config u.config-json))
        ?.  &((gth poll.config 0) !=('' repo.config))
          ;<  =wave:nexus  bind:m  (take-news:io /cfg)
          $
        ~&  >  [%git-desk-poll-sleeping poll.config %minutes]
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m  (set-timer:io /poll (add now (mul ~m1 poll.config)))
        ;<  *  bind:m  (take-news-or-wake:io /cfg)
        ;<  ~  bind:m
          (poke:io (nex-road:io rail [%& / %'sync.sig']) [[/ %sig] ~])
        $
          ::  sync.sig: poke to fetch+install, then wait for next poke
          ::
          [~ %'sync.sig']
        ;<  ~  bind:m
          ?.  ?=(^ prod)  (pure:m ~)
          =/  err=@t
            %-  of-wain:format
            (turn u.prod |=(=tank (crip ~(ram re tank))))
          %+  over:io  (nex-road:io rail [%& /desk %'error.txt'])
          [[/ %mime] [/text/plain (as-octs:mimes:html err)]]
        ;<  ~  bind:m  (rise-wait:io prod "%git/desk sync: failed")
        |-
        ;<  *  bind:m  take-poke:io
        ;<  *  bind:m
          (cull-soft:io (nex-road:io rail [%& /desk %'error.txt']))
        ;<  config-json=(unit json)  bind:m
          (peek-as:io (nex-road:io rail [%& / %'config.json']) ,json)
        =/  config=git-desk-config
          ?~(config-json *git-desk-config (json-to-config u.config-json))
        ~&  >>  [%git-desk-sync-config repo.config ref.config]
        ?:  =('' repo.config)
          ~&  >>>  %git-desk-sync-no-repo
          $
        ;<  files=(list [pax=path data=octs])  bind:m
          (do-fetch config)
        =/  remote-ver=@ud  (fall (extract-version files) 0)
        ;<  cur-ver=(unit @ud)  bind:m
          (peek-as:io (nex-road:io rail [%& / %'version.ud']) ,@ud)
        ?:  &(?=(^ cur-ver) (lte remote-ver u.cur-ver))
          ~&  >  [%git-desk-sync-no-update local=u.cur-ver remote=remote-ver]
          $
        ~&  >  [%git-desk-updating local=(fall cur-ver 0) remote=remote-ver]
        ;<  ~  bind:m  (do-checkpoint rail (sy ~['checkpoint']))
        ;<  ~  bind:m  (do-install rail files)
        ;<  ver=(unit @ud)  bind:m
          (peek-as:io (nex-road:io rail [%& / %'version.ud']) ,@ud)
        ;<  ~  bind:m
          (do-checkpoint rail (sy ~['checkpoint' (version-tag (fall ver 0))]))
        ~&  >  [%git-desk-sync-done ver=(fall ver 0)]
        $
          ::
          [~ %'version.ud']
        ;<  ~  bind:m  (rise-wait:io prod "%git/desk version: failed")
        ;<  ver0=(unit @ud)  bind:m
          (peek-as:io (nex-road:io rail [%& / %'version.ud']) ,@ud)
        ;<  ~  bind:m
          (do-checkpoint rail (sy ~['checkpoint' (version-tag (fall ver0 0))]))
        ;<  *  bind:m
          (keep:io /self (nex-road:io rail [%& / %'version.ud']) `[/ %ud])
        |-
        ;<  =wave:nexus  bind:m  (take-news:io /self)
        ;<  ver=(unit @ud)  bind:m
          (peek-as:io (nex-road:io rail [%& / %'version.ud']) ,@ud)
        ;<  ~  bind:m
          (do-checkpoint rail (sy ~['checkpoint' (version-tag (fall ver 0))]))
        $
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/desk /main: failed")
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/git-desk/[(desk-slug path.here)]])
        (http-dispatch:io %git-desk)
          ::
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%git/desk /requests: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        ;<  our=@p  bind:m  get-our:io
        ~&  >>  [%git-desk-request method.request.req url.request.req]
        ?.  =(src our)
          ;<  ~  bind:m  (respond eyre-id rail 403 'Forbidden')
          (pure:m ~)
        =/  nex-path=path  (snip path.here)
        =/  prefix=path  /grubbery/git-desk/[(desk-slug nex-path)]
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  suffix=path  (slag (lent prefix) site)
        ~&  >>  [%git-desk-dispatch method.request.req suffix]
        ?:  =('POST' method.request.req)
          (handle-post eyre-id suffix req rail)
        (handle-get eyre-id suffix rail)
      ==
    --
::
|%
+$  git-desk-config
  $:  repo=@t
      ref=@t
      public=?
      poll=@ud
      token=@t
  ==
::
++  config-to-json
  |=  config=git-desk-config
  ^-  json
  %-  pairs:enjs:format
  :~  ['repo' s+repo.config]
      ['ref' s+ref.config]
      ['public' b+public.config]
      ['poll' (numb:enjs:format poll.config)]
      ['token' s+token.config]
  ==
::
++  json-to-config
  |=  =json
  ^-  git-desk-config
  ?.  ?=(%o -.json)  *git-desk-config
  =/  get
    |=  [key=@t default=@t]
    ^-  @t
    =/  v  (~(get by p.json) key)
    ?.  ?=([~ %s *] v)  default
    p.u.v
  :*  (get 'repo' '')
      (get 'ref' '')
      =+  pub=(~(get by p.json) 'public')
      ?:(?=([~ %b *] pub) p.u.pub %.n)
      =+  pol=(~(get by p.json) 'poll')
      ?:(?=([~ %n *] pol) (fall (rush p.u.pol dem) 0) 0)
      (get 'token' '')
  ==
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
++  version-tag
  |=  ver=@ud
  ^-  @t
  (crip "v{(a-co:co ver)}")
::
::  +do-fetch: clone repo + checkout, return files list
::
++  do-fetch
  |=  config=git-desk-config
  =/  m  (fiber:fiber:nexus ,(list [pax=path data=octs]))
  ^-  form:m
  ~&  >  [%git-desk-fetching repo.config]
  ;<  disc=discovery:git-transport  bind:m
    (fetch-discovery repo.config)
  =/  ref=@t
    ?:  =('' ref.config)
      (fall (default-branch:git-transport caps.disc) 'main')
    ref.config
  ~&  >  [%git-desk-found (lent refs.disc) %refs ref=ref]
  =/  want-hashes=(list @ux)
    (turn refs.disc |=(r=git-ref:git-transport hash.r))
  ;<  pack-body=octs  bind:m
    (fetch-pack repo.config want-hashes)
  ~&  >  [%git-desk-pack p.pack-body %bytes]
  =/  pack-data=octs
    (extract-pack:git-transport pack-body %.y)
  =/  =pack:git-pack
    (read:git-pack (from-octs:bytestream pack-data))
  ~&  >  [%git-desk-unpacked count.pack %objects]
  =/  repo=repository:git-repo
    (~(clone-from-pack git-repo *repository:git-repo) pack refs.disc)
  =/  sto  store:~(. git-repo repo)
  =/  ref-hash=(unit @ux)
    =+  got=(get:refs:~(. git-repo repo) ~[ref])
    ?^  got  got
    (get:refs:~(. git-repo repo) ~['refs' 'heads' ref])
  =/  commit-hash=@ux  (fall ref-hash 0x0)
  =/  com=(unit commit:git-repo)  (get-commit:sto commit-hash)
  ?~  com
    ~&  >>>  [%git-desk-commit-not-found (crip (scag 7 (print-hash-sha-1:git-transport commit-hash)))]
    (pure:m ~)
  =/  get-tree=$-(@ux (unit tree-dir:git-repo))
    |=(h=@ux (get-tree:sto h))
  =/  get-blob=$-(@ux (unit octs))
    |=(h=@ux (get-blob:sto h))
  =/  files=(list [pax=path data=octs])
    (checkout:git-transport get-tree get-blob tree.u.com)
  ~&  >  [%git-desk-checkout (lent files) %files]
  (pure:m files)
::
::  +do-install: write fetched files into the desk
::
++  do-install
  |=  [=rail:tarball files=(list [pax=path data=octs])]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  code-files=(list bfile)  (filter-prefix files /code)
  =/  ver=(unit @ud)  (extract-version files)
  ~&  >  [%git-desk-install code=(lent code-files) ver=ver]
  =/  code-bole=bole:tarball  (files-to-bole code-files `[/ %code])
  ;<  ~  bind:m  (cull:io (nex-road:io rail [%| /desk/code]))
  ;<  ~  bind:m  (make:io (nex-road:io rail [%| /desk/code]) &+code-bole)
  ;<  ~  bind:m
    ?~  ver  (pure:m ~)
    ;<  exists=?  bind:m
      (peek-exists:io (nex-road:io rail [%& / %'version.ud']))
    ?.  exists
      (make:io (nex-road:io rail [%& / %'version.ud']) |+[[[/ %ud] u.ver] ~])
    (over:io (nex-road:io rail [%& / %'version.ud']) [[/ %ud] u.ver])
  =/  bill-octs=(unit octs)  (extract-file files ~['bill.json'])
  ;<  ~  bind:m
    ?~  bill-octs  (pure:m ~)
    =/  bill-json=json  (need (de:json:html q.u.bill-octs))
    (put:io (nex-road:io rail [%& /desk %'bill.json']) [[/ %json] bill-json])
  =/  tile-octs=(unit octs)  (extract-file files ~['tile.json'])
  ;<  ~  bind:m
    ?~  tile-octs  (pure:m ~)
    =/  tile-json=json  (need (de:json:html q.u.tile-octs))
    (put:io (nex-road:io rail [%& / %'tile.json']) [[/ %json] tile-json])
  =/  icon-octs=(unit octs)  (extract-file files ~['icon.svg'])
  ;<  ~  bind:m
    ?~  icon-octs  (pure:m ~)
    =/  =mime  [[%image %'svg+xml' ~] u.icon-octs]
    (put:io (nex-road:io rail [%& / %'icon.svg']) [[/ %mime] mime])
  (apply-bill rail files)
::
::  +filter-prefix: extract files under a path prefix as bfiles
::
++  filter-prefix
  |=  [files=(list [pax=path data=octs]) prefix=path]
  ^-  (list bfile)
  =/  plen=@ud  (lent prefix)
  %+  murn  files
  |=  [pax=path data=octs]
  ^-  (unit bfile)
  ?.  =(prefix (scag plen pax))  ~
  =/  rel=path  (slag plen pax)
  ?~  rel  ~
  =/  name=@ta  (rear rel)
  =/  dir=path  (snip `(list @ta)`rel)
  =/  is-hoon=?
    =/  t=tape  (trip name)
    =/  len=@ud  (lent t)
    ?&  (gth len 5)
        =(".hoon" (slag (sub len 5) t))
    ==
  ?:  is-hoon
    `[dir name [/ %hoon] %& !>(`@t`q.data)]
  =/  content-type=path  (guess-mime name)
  =/  =mime  [content-type data]
  `[dir name [/ %mime] %& !>(mime)]
::
::  +extract-file: find a file by path in checkout
::
++  extract-file
  |=  [files=(list [pax=path data=octs]) target=path]
  ^-  (unit octs)
  ?~  files  ~
  ?:  =(pax.i.files target)  `data.i.files
  $(files t.files)
::
++  extract-version
  |=  files=(list [pax=path data=octs])
  ^-  (unit @ud)
  =/  vf=(unit octs)  (extract-file files ~['version.json'])
  ?~  vf  ~
  =/  jon=(unit json)  (de:json:html q.u.vf)
  ?~  jon  ~
  ?.  ?=(%o -.u.jon)  ~
  =/  v  (~(get by p.u.jon) 'version')
  ?.  ?=([~ %n *] v)  ~
  (rush p.u.v dem)
::
+$  bfile  [pax=path name=@ta =sang:tarball]
::
::  +apply-bill: on first install, create nexus entries from bill.json
::
++  apply-bill
  |=  [=rail:tarball files=(list [pax=path data=octs])]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(unit (list bfile))  bind:m  (fetch-dir rail /desk/data ~)
  ?.  =(~ (fall cur ~))  (pure:m ~)
  =/  bill-octs=(unit octs)  (extract-file files ~['bill.json'])
  ?~  bill-octs
    ~&  >  %git-desk-no-bill
    (pure:m ~)
  =/  bill-json=(unit json)  (de:json:html q.u.bill-octs)
  ?~  bill-json
    ~&  >>>  %git-desk-bad-bill-json
    (pure:m ~)
  ?.  ?=(%o -.u.bill-json)
    ~&  >>>  %git-desk-bill-not-object
    (pure:m ~)
  =/  entries=(list [@t @t])  (turn ~(tap by p.u.bill-json) |=([k=@t v=json] [k (so:dejs:format v)]))
  =/  tile-octs=(unit octs)  (extract-file files ~['tile.json'])
  =/  icon-octs=(unit octs)  (extract-file files ~['icon.svg'])
  ~&  >  [%git-desk-bill (lent entries)]
  |-
  ?~  entries  (pure:m ~)
  =/  nam=@ta  -.i.entries
  =/  cod=path  (stab +.i.entries)
  =/  neck=rail:tarball  [(snip cod) (rear cod)]
  =/  data-road=road:tarball  (nex-road:io rail [%| /desk/data/[nam]])
  =/  =bole:tarball  [`[`neck ~ %.n ~] ~]
  ~&  >  [%git-desk-bill-entry nam neck]
  ;<  ~  bind:m  (make:io data-road &+bole)
  ;<  ~  bind:m
    ?~  tile-octs  (pure:m ~)
    =/  tile-json=json  (need (de:json:html q.u.tile-octs))
    (put:io (nex-road:io rail [%& /desk/data/[nam] %'tile.json']) [[/ %json] tile-json])
  ;<  ~  bind:m
    ?~  icon-octs  (pure:m ~)
    =/  =mime  [[%image %'svg+xml' ~] u.icon-octs]
    (put:io (nex-road:io rail [%& /desk/data/[nam] %'icon.svg']) [[/ %mime] mime])
  $(entries t.entries)
::
++  do-checkpoint
  |=  [=rail:tarball tags=(set @t)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ~&  >  [%git-desk-checkpoint tags=tags]
  ;<  ~  bind:m  (checkpoint:io (nex-road:io rail [%| /desk/data]))
  ;<  ~  bind:m  (tag:io (nex-road:io rail [%| /desk/data]) ~ tags)
  ;<  ~  bind:m  (checkpoint:io (nex-road:io rail [%| /desk/code]))
  ;<  ~  bind:m  (tag:io (nex-road:io rail [%| /desk/code]) ~ tags)
  ;<  ~  bind:m  (checkpoint:io (nex-road:io rail [%& / %'version.ud']))
  (tag:io (nex-road:io rail [%& / %'version.ud']) ~ tags)
::
::  +ball-to-files: lift files out of a ball with relative paths
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
++  files-to-bole
  |=  [files=(list bfile) neck=(unit rail:tarball)]
  ^-  bole:tarball
  =/  b=bole:tarball  [`[neck ~ %.n ~] ~]
  |-
  ?~  files  b
  ?:  (is-boom:tarball sang.i.files)
    $(files t.files)
  =/  =bask:tarball  [p.sang.i.files (sang-noun:tarball sang.i.files)]
  $(files t.files, b (put-bfile b pax.i.files name.i.files bask))
::
++  put-bfile
  |=  [b=bole:tarball pax=path name=@ta =bask:tarball]
  ^-  bole:tarball
  ?~  pax
    =/  =pulp:tarball  (fall fil.b [~ ~ %.n ~])
    b(fil `pulp(contents (~(put by contents.pulp) name [bask %.n])))
  =/  kid=bole:tarball  (~(gut by dir.b) i.pax *bole:tarball)
  b(dir (~(put by dir.b) i.pax $(b kid, pax t.pax)))
::
::  github REST push helpers
::
++  repo-url
  |=  [api=@t repo=@t tail=@t]
  ^-  @t
  (cat 3 api (cat 3 '/repos/' (cat 3 repo tail)))
::
++  gh-headers-d
  |=  token=@t
  ^-  (list [key=@t value=@t])
  :~  ['User-Agent' 'grubbery']
      ['Authorization' (cat 3 'token ' token)]
      ['Accept' 'application/vnd.github.v3+json']
      ['Content-Type' 'application/json']
  ==
::
++  gh-call
  |=  [method=?(%'GET' %'POST' %'PATCH') url=@t hdr=(list [key=@t value=@t]) body=(unit json)]
  =/  m  (fiber:fiber:nexus ,[@ud json])
  ^-  form:m
  =/  buf=(unit octs)
    ?~  body  ~
    `(as-octs:mimes:html (en:json:html u.body))
  ;<  ~  bind:m  (send-request:io [method url hdr buf])
  ;<  =client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.client-response)
    (pure:m [999 *json])
  =/  st=@ud  status-code.response-header.client-response
  =/  jon=json
    ?~  full-file.client-response  *json
    (fall (de:json:html q.data.u.full-file.client-response) *json)
  (pure:m [st jon])
::
++  jstr
  |=  [jon=json k=@t]
  ^-  @t
  ?.  ?=(%o -.jon)  ''
  =/  v  (~(get by p.jon) k)
  ?.(?=([~ %s *] v) '' p.u.v)
::
++  obj-sha  |=(jon=json (jstr jon 'sha'))
::
++  ref-sha
  |=  jon=json
  ^-  @t
  ?.  ?=(%o -.jon)  ''
  =/  obj  (~(get by p.jon) 'object')
  ?~  obj  ''
  (jstr u.obj 'sha')
::
++  commit-tree-sha
  |=  jon=json
  ^-  @t
  ?.  ?=(%o -.jon)  ''
  =/  tr  (~(get by p.jon) 'tree')
  ?~  tr  ''
  (jstr u.tr 'sha')
::
++  repo-path
  |=  [pax=path name=@ta]
  ^-  tape
  %-  zing
  (join "/" `(list tape)`["code" (snoc (turn `(list @ta)`pax trip) (trip name))])
::
++  bfile-text
  |=  b=bfile
  ^-  (unit @t)
  ?:  (is-boom:tarball sang.b)  ~
  ?:  =([/ %hoon] p.sang.b)
    `!<(@t (need-vase:tarball sang.b))
  ?.  =([/ %mime] p.sang.b)  ~
  ::  inline tree content is text-only; binaries would need the
  ::  base64 blobs api — desk code trees are text in practice
  =/  =mime  !<(mime (need-vase:tarball sang.b))
  `q.q.mime
::
::  HTTP transport
::
++  fetch-with-redirect
  |=  [=request:http]
  =/  m  (fiber:fiber:nexus ,octs)
  ^-  form:m
  ~&  >>  [%git-desk-http method.request url.request]
  ;<  ~  bind:m  (send-request:io request)
  ~&  >>  %git-desk-http-waiting
  ;<  =client-response:iris  bind:m  take-client-response:io
  ~&  >>  [%git-desk-http-response -.client-response]
  ?.  ?=(%finished -.client-response)
    ~|  "%git/desk: request failed"  !!
  =/  status  status-code.response-header.client-response
  ~&  >>  [%git-desk-http-status status]
  ?:  ?|  =(status 301)
          =(status 302)
          =(status 307)
      ==
    =/  location=(unit @t)
      (~(get by (malt headers.response-header.client-response)) 'location')
    ?~  location  ~|(%git-desk-redirect-no-location !!)
    ~&  >>  [%git-desk-redirect u.location]
    ;<  ~  bind:m  (send-request:io [%'GET' u.location ~[['User-Agent' 'grubbery']] ~])
    ;<  =client-response:iris  bind:m  take-client-response:io
    ~&  >>  [%git-desk-redirect-response -.client-response ?:(?=(%finished -.client-response) status-code.response-header.client-response 0)]
    ?.  ?=(%finished -.client-response)
      ~|  "%git/desk: redirect failed"  !!
    ?~  full-file.client-response
      ~|  "%git/desk: empty after redirect"  !!
    ~&  >>  [%git-desk-redirect-ok p.data.u.full-file.client-response %bytes]
    (pure:m data.u.full-file.client-response)
  ?.  =(200 status)
    ~&  >>>  [%git-desk-http-error status]
    ~|  "%git/desk: HTTP {<status>}"  !!
  ?~  full-file.client-response
    ~|  "%git/desk: empty response"  !!
  (pure:m data.u.full-file.client-response)
::
++  fetch-discovery
  |=  repo=@t
  =/  m  (fiber:fiber:nexus ,discovery:git-transport)
  ^-  form:m
  =/  url=@t
    (rap 3 ~['https://github.com/' repo '.git/info/refs?service=git-upload-pack'])
  =/  hdrs=(list [@t @t])
    ~[['User-Agent' 'grubbery']]
  ;<  body=octs  bind:m  (fetch-with-redirect [%'GET' url hdrs ~])
  (pure:m (parse-discovery:git-transport body))
::
++  fetch-pack
  |=  [repo=@t want-hashes=(list @ux)]
  =/  m  (fiber:fiber:nexus ,octs)
  ^-  form:m
  =/  url=@t
    (rap 3 ~['https://github.com/' repo '.git/git-upload-pack'])
  =/  want-body=octs
    (build-want:git-transport want-hashes ~['side-band-64k' 'ofs-delta'] ~ ~)
  =/  hdrs=(list [@t @t])
    :~  ['Content-Type' 'application/x-git-upload-pack-request']
        ['User-Agent' 'grubbery']
    ==
  (fetch-with-redirect [%'POST' url hdrs `want-body])
::
++  guess-mime
  |=  filename=@t
  ^-  path
  =/  ext=@t
    =/  =tape  (trip filename)
    =/  idx=(unit @ud)  (find "." (flop tape))
    ?~  idx  ''
    (crip (slag (sub (lent tape) u.idx) tape))
  ?+  ext  /application/octet-stream
    %hoon  /text/plain
    %txt   /text/plain
    %md    /text/plain
    %json  /application/json
    %html  /text/html
    %css   /text/css
    %js    /application/javascript
    %svg   /image/'svg+xml'
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
  ?:  =(/state suffix)
    ;<  config-json=(unit json)  bind:m
      (peek-as:io (nex-road:io rail [%& / %'config.json']) ,json)
    ;<  ver=(unit @ud)  bind:m
      (peek-as:io (nex-road:io rail [%& / %'version.ud']) ,@ud)
    ;<  err=(unit mime)  bind:m
      (peek-as:io (nex-road:io rail [%& /desk %'error.txt']) ,mime)
    =/  cfg=git-desk-config  ?~(config-json *git-desk-config (json-to-config u.config-json))
    =/  =json
      %-  pairs:enjs:format
      :~  ['repo' s+repo.cfg]
          ['ref' s+ref.cfg]
          ['version' (numb:enjs:format (fall ver 0))]
          ['public' b+public.cfg]
          ['poll' (numb:enjs:format poll.cfg)]
          ['error' ?~(err ~ s+`@t`q.q.u.err)]
      ==
    =/  bod=octs  (as-octs:mimes:html (en:json:html json))
    ;<  ~  bind:m
      %+  ~(send-simple http-res:io (nex-road:io rail [%& ~ %'main.sig']))
        eyre-id
      (mime-response:http-utils [/application/json bod])
    (pure:m ~)
  ::  default: static page
  =/  bod=octs  (as-octs:mimes:html (crip (en-xml:html render-page)))
  ;<  ~  bind:m
    %+  ~(send-simple http-res:io (nex-road:io rail [%& ~ %'main.sig']))
      eyre-id
    (mime-response:http-utils [/text/html bod])
  (pure:m ~)
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
      [%set-repo ~]
    ~&  >>  [%git-desk-post-set-repo body]
    =/  jon=(unit json)  (de:json:html body)
    ?~  jon
      ~&  >>>  %git-desk-bad-json
      ;<  ~  bind:m  (respond eyre-id rail 400 'bad json')
      (pure:m ~)
    ~&  >>  [%git-desk-saving-config u.jon]
    ;<  ~  bind:m
      (poke:io (nex-road:io rail [%& / %'config.json']) [[/ %json] u.jon])
    ~&  >>  %git-desk-config-saved
    (respond eyre-id rail 200 'ok')
  ::
      [%sync ~]
    ~&  >>  %git-desk-post-sync
    ;<  ~  bind:m
      (poke:io (nex-road:io rail [%& / %'sync.sig']) [[/ %sig] ~])
    ~&  >>  %git-desk-sync-poked
    (respond eyre-id rail 200 'syncing')
  ==
::
++  render-page
  ^-  manx
  ;html
    ;head
      ;title: Git Desk
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  page-css
      ==
    ==
    ;body
      ;h1: Git Desk
      ;div(class "section")
        ;h2: Repository
        ;div(class "form")
          ;input#repo-input(type "text", placeholder "owner/repo");
          ;input#ref-input(type "text", placeholder "branch", value "main");
        ==
        ;div(class "form")
          ;label(for "poll-input", style "font-size:.85rem;align-self:center"): Poll (min):
          ;input#poll-input(type "number", min "0", value "0", style "width:4rem;flex:none");
        ==
        ;div(class "form")
          ;button(class "btn btn-grn", onclick "saveConfig()"): Save
          ;button(class "btn", onclick "doSync()"): Sync Now
        ==
        ;div(class "status")
          ;span(class "label"): Status:
          ;span#status: loading...
        ==
        ;div(class "status")
          ;span(class "label"): Version:
          ;span#version: ...
        ==
        ;pre#error-box(style "display:none");
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
    ".form \{ display:flex; gap:.5rem; margin-bottom:.5rem; }"
    ".form input \{ font-family:monospace; font-size:16px; padding:.3rem .5rem; border:1px solid #ccc; border-radius:4px; flex:1; min-width:0; }"
    ".status \{ font-size:.85rem; margin-bottom:.25rem; }"
    ".status .label \{ font-weight:bold; margin-right:.5rem; }"
    ".btn \{ font-family:monospace; font-size:.8rem; padding:.3rem .75rem; border:1px solid #ccc; border-radius:4px; background:#fff; cursor:pointer; }"
    ".btn:hover \{ background:#eee; }"
    ".btn-grn \{ color:#2a2; border-color:#2a2; }"
    ".btn-grn:hover \{ background:#dfd; }"
    "#error-box \{ background:#fee; border:1px solid #c66; color:#900; padding:.5rem; margin-top:.5rem; font-size:.75rem; white-space:pre-wrap; overflow-x:auto; border-radius:4px; }"
  ==
::
++  page-js
  ^-  tape
  ;:  weld
    "var BASE=window.location.pathname;"
    "if(!BASE.endsWith('/'))BASE+='/';"
    "function saveConfig()\{"
    "  var body=JSON.stringify(\{"
    "    repo:document.getElementById('repo-input').value.trim(),"
    "    ref:document.getElementById('ref-input').value.trim()||'main',"
    "    public:false,"
    "    poll:parseInt(document.getElementById('poll-input').value)||0"
    "  });"
    "  fetch(BASE+'set-repo',\{method:'POST',body:body}).then(function()\{load()});"
    "}"
    "function doSync()\{"
    "  document.getElementById('status').textContent='syncing...';"
    "  fetch(BASE+'sync',\{method:'POST'}).then(function()\{load()});"
    "}"
    "function load()\{"
    "  fetch(BASE+'state').then(function(r)\{return r.json()}).then(function(s)\{"
    "    document.getElementById('repo-input').value=s.repo||'';"
    "    document.getElementById('ref-input').value=s.ref||'main';"
    "    document.getElementById('poll-input').value=s.poll||0;"
    "    document.getElementById('status').textContent="
    "      s.repo?'configured':'not configured';"
    "    document.getElementById('version').textContent='v'+s.version;"
    "    var eb=document.getElementById('error-box');"
    "    if(s.error)\{eb.textContent=s.error;eb.style.display='block'}"
    "    else\{eb.style.display='none'}"
    "  });"
    "}"
    "load();"
  ==
--
