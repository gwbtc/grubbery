::  desks: unified desk manager — acquire desk trees from sources
::  (git for now; ship transport later), stage them as inert
::  mirrors, and deploy them deliberately into app directories.
::
::  /main.sig                 json pokes: install / sync / deploy /
::                            push / config
::  /entries/<name>/
::    config.json             {repo, ref, app, token}
::    state.json              {synced, deployed}
::    mirror/                 inert full checkout — NOT a code
::                            nexus; sync only ever writes here
::
::  deploy writes /apps/<app>/: code/ (a real code nexus), data/
::  instance dirs from bill.json (created once, preserved across
::  deploys), tile.json, icon.svg at the app root.
::
::  source vs sink: an entry with poll > 0 (minutes) is a SINK — it
::  periodically syncs its mirror and deploys when the author bumped
::  version.json. poll 0 / absent is a SOURCE — you author here, so
::  nothing is ever pulled or deployed except by explicit poke. sync
::  only ever writes the mirror either way; the live app moves only
::  on deploy.
::
/<  git-pack  /lib/git/pack.hoon
/<  git-repo  /lib/git/repository.hoon
/<  git-transport  /lib/git/transport.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Desks'
            info+s+'Install & update apps'
            color+s+'#7a4f9e'
            href+s+'/grubbery/explorer'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'poll.sig'] [[/ %sig] ~]]
          [%fall %| /entries empty-dir:loader]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
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
        ;<  ~  bind:m  (rise-wait:io prod "%desks main: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        =/  act=@t   (jstr jon 'action')
        =/  name=@t  (jstr jon 'name')
        ?:  =('' name)
          ~&  >>>  "%desks: name required"
          $
        =/  nam=@ta  (crip (trip name))
        ?:  =('install' act)
          ;<  ~  bind:m  (do-config rail nam jon)
          ;<  ok=?  bind:m  (do-sync rail nam)
          ;<  ~  bind:m
            ?.  ok  (pure:(fiber:fiber:nexus ,~) ~)
            (do-deploy rail nam jon)
          $
        ?:  =('config' act)
          ;<  ~  bind:m  (do-config rail nam jon)
          $
        ?:  =('sync' act)
          ;<  *  bind:m  (do-sync rail nam)
          $
        ?:  =('deploy' act)
          ;<  ~  bind:m  (do-deploy rail nam jon)
          $
        ?:  =('push' act)
          ;<  ~  bind:m  (do-push rail nam jon)
          $
        ~&  >>>  [%desks %unknown-action act]
        $
          ::  poll.sig: sinks only. every entry with poll > 0 gets a
          ::  periodic sync, and a deploy when the author bumped
          ::  version.json (synced > deployed). sources (poll 0 or
          ::  absent) are never touched. watches /entries so config
          ::  changes re-arm the timer.
          ::
          [~ %'poll.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%desks poll: failed")
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        ;<  *  bind:m
          (keep:io /ent (nex-road:io here [%| /entries]) ~)
        |-
        ;<  names=(list @ta)  bind:m  (entry-names here)
        ;<  min-poll=@ud  bind:m  (min-poll-of here names)
        ?:  =(0 min-poll)
          ::  no sinks — sleep until entries change
          ;<  *  bind:m  (take-news:io /ent)
          $
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m  (set-timer:io /tick (add now (mul ~m1 min-poll)))
        ;<  *  bind:m  (take-news-or-wake:io /ent)
        ;<  due=(list @ta)  bind:m  (entry-names here)
        |-
        ?~  due  ^$
        ;<  cfg=json  bind:m  (read-entry-json here i.due %'config.json')
        ;<  ~  bind:m
          ?:  =(0 (jnum cfg 'poll'))  (pure:(fiber:fiber:nexus ,~) ~)
          (poll-one here i.due)
        $(due t.due)
      ==
    --
|%
::  json helpers
::
++  jstr
  |=  [jon=json k=@t]
  ^-  @t
  ?.  ?=([%o *] jon)  ''
  =/  v  (~(get by p.jon) k)
  ?.(?=([~ %s *] v) '' p.u.v)
::
++  jnum
  |=  [jon=json k=@t]
  ^-  @ud
  ?.  ?=([%o *] jon)  0
  =/  v  (~(get by p.jon) k)
  ?.  ?=([~ %n *] v)  0
  (fall (rush p.u.v dem) 0)
::
++  entry-names
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(list @ta))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io (nex-road:io rail [%| /entries]) ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  (pure:m ~(tap in ~(key by dir.ball.view)))
::
++  min-poll-of
  |=  [=rail:tarball names=(list @ta)]
  =/  m  (fiber:fiber:nexus ,@ud)
  ^-  form:m
  ?~  names  (pure:m 0)
  ;<  cfg=json  bind:m  (read-entry-json rail i.names %'config.json')
  ;<  rest=@ud  bind:m  $(names t.names)
  =/  p=@ud  (jnum cfg 'poll')
  %-  pure:m
  ?:  =(0 p)  rest
  ?:  =(0 rest)  p
  (min p rest)
::  +poll-one: sink maintenance for one entry — sync the mirror,
::  and deploy only when the author bumped version.json
::
++  poll-one
  |=  [=rail:tarball nam=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ok=?  bind:m  (do-sync rail nam)
  ?.  ok  (pure:m ~)
  ;<  st=json  bind:m  (read-entry-json rail nam %'state.json')
  ?.  (gth (jnum st 'synced') (jnum st 'deployed'))
    (pure:m ~)
  ~&  >  [%desks nam %poll-deploying]
  (do-deploy rail nam *json)
::  entry roads (relative to the nexus root)
::
++  entry-file
  |=  [=rail:tarball nam=@ta file=@ta]
  ^-  road:tarball
  (nex-road:io rail [%& /entries/[nam] file])
::
++  entry-dir
  |=  [=rail:tarball nam=@ta sub=path]
  ^-  road:tarball
  (nex-road:io rail [%| (weld /entries/[nam] sub)])
::
++  read-entry-json
  |=  [=rail:tarball nam=@ta file=@ta]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  j=(unit json)  bind:m  (peek-as:io (entry-file rail nam file) ,json)
  (pure:m (fall j *json))
::  +do-config: merge poked fields into the entry's config.json.
::  never triggers a sync — configuring and pulling are separate acts.
::
++  do-config
  |=  [=rail:tarball nam=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  old=json  bind:m  (read-entry-json rail nam %'config.json')
  =/  om=(map @t json)  ?:(?=([%o *] old) p.old ~)
  =/  merge
    |=  [m=(map @t json) k=@t]
    ^-  (map @t json)
    =/  v=@t  (jstr jon k)
    ?:(=('' v) m (~(put by m) k s+v))
  =.  om  (merge om 'repo')
  =.  om  (merge om 'ref')
  =.  om  (merge om 'app')
  =.  om  (merge om 'token')
  ::  poll (minutes) declares sink-hood: > 0 = periodic sync +
  ::  version-gated deploy; 0/absent = source, everything manual
  =?  om  ?=([~ %n *] (~(get by ?:(?=([%o *] jon) p.jon ~)) 'poll'))
    (~(put by om) 'poll' (numb:enjs:format (jnum jon 'poll')))
  ::  app defaults to the entry name
  =?  om  !(~(has by om) 'app')  (~(put by om) 'app' s+nam)
  ;<  *  bind:m  (make-soft:io (entry-dir rail nam /) &+[~ ~])
  (put:io (entry-file rail nam %'config.json') [[/ %json] [%o om]])
::  +do-sync: fetch from source and rewrite the mirror. never
::  touches the live app. returns whether anything was fetched.
::
++  do-sync
  |=  [=rail:tarball nam=@ta]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  cfg=json  bind:m  (read-entry-json rail nam %'config.json')
  =/  repo=@t  (jstr cfg 'repo')
  ?:  =('' repo)
    ~&  >>>  [%desks nam %no-repo-configured]
    (pure:m %.n)
  ~&  >  [%desks nam %syncing repo]
  ;<  files=(list [pax=path data=octs])  bind:m
    (do-fetch repo (jstr cfg 'ref'))
  ?:  =(~ files)
    ~&  >>>  [%desks nam %fetch-empty]
    (pure:m %.n)
  =/  bfiles=(list bfile)  (filter-prefix files ~)
  ;<  *  bind:m  (cull-soft:io (entry-dir rail nam /mirror))
  ;<  ~  bind:m  (make:io (entry-dir rail nam /mirror) &+(files-to-bole bfiles ~))
  =/  ver=@ud  (fall (extract-version files) 0)
  ;<  st=json  bind:m  (read-entry-json rail nam %'state.json')
  =/  sm=(map @t json)  ?:(?=([%o *] st) p.st ~)
  =.  sm  (~(put by sm) 'synced' (numb:enjs:format ver))
  ;<  ~  bind:m  (put:io (entry-file rail nam %'state.json') [[/ %json] [%o sm]])
  ~&  >  [%desks nam %synced (lent bfiles) %files ver=ver]
  (pure:m %.y)
::  +do-deploy: mirror -> live app. refuses when the live code tree
::  differs from the last deploy (local edits) unless force: true.
::
++  do-deploy
  |=  [=rail:tarball nam=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg=json  bind:m  (read-entry-json rail nam %'config.json')
  =/  app=@t  (jstr cfg 'app')
  ?:  =('' app)
    ~&  >>>  [%desks nam %no-app-configured]
    (pure:m ~)
  =/  app-dir=path  /apps/[(crip (trip app))]
  ;<  mirror=(unit (list bfile))  bind:m
    (fetch-dir-at (entry-dir rail nam /mirror))
  ?~  mirror
    ~&  >>>  [%desks nam %mirror-empty %sync-first]
    (pure:m ~)
  ?:  =(~ u.mirror)
    ~&  >>>  [%desks nam %mirror-empty %sync-first]
    (pure:m ~)
  =/  bfiles=(list bfile)  u.mirror
  =/  code-files=(list bfile)
    %+  murn  bfiles
    |=  b=bfile
    ^-  (unit bfile)
    ?.  ?=([%code *] pax.b)  ~
    `b(pax t.pax.b)
  ;<  st=json  bind:m  (read-entry-json rail nam %'state.json')
  ::  lay code as a fresh code nexus
  ;<  *  bind:m  (cull-soft:io [%& %| (snoc app-dir %code)])
  ;<  *  bind:m  (make-soft:io [%& %| app-dir] &+[~ ~])
  ;<  ~  bind:m
    (make:io [%& %| (snoc app-dir %code)] &+(files-to-bole code-files `[/ %code]))
  ::  root files: tile, icon
  ;<  ~  bind:m
    =/  tile=(unit bfile)  (find-bfile bfiles ~ %'tile.json')
    ?~  tile  (pure:(fiber:fiber:nexus ,~) ~)
    ?:  (is-boom:tarball sang.u.tile)  (pure:(fiber:fiber:nexus ,~) ~)
    (put:io [%& %& app-dir %'tile.json'] [p.sang.u.tile (sang-noun:tarball sang.u.tile)])
  ;<  ~  bind:m
    =/  icon=(unit bfile)  (find-bfile bfiles ~ %'icon.svg')
    ?~  icon  (pure:(fiber:fiber:nexus ,~) ~)
    ?:  (is-boom:tarball sang.u.icon)  (pure:(fiber:fiber:nexus ,~) ~)
    (put:io [%& %& app-dir %'icon.svg'] [p.sang.u.icon (sang-noun:tarball sang.u.icon)])
  ::  bill instances under data/ — created once, preserved after
  ;<  *  bind:m  (make-soft:io [%& %| (snoc app-dir %data)] &+[~ ~])
  ;<  ~  bind:m  (apply-bill-entries app-dir bfiles)
  =/  ver=@ud
    =/  vb=(unit bfile)  (find-bfile bfiles ~ %'version.json')
    ?~  vb  0
    (fall (version-from-sang sang.u.vb) 0)
  =/  sm=(map @t json)  ?:(?=([%o *] st) p.st ~)
  =.  sm  (~(put by sm) 'deployed' (numb:enjs:format ver))
  ;<  ~  bind:m  (put:io (entry-file rail nam %'state.json') [[/ %json] [%o sm]])
  ~&  >  [%desks nam %deployed (lent code-files) %code-files %to app-dir]
  (pure:m ~)
::  +do-push: live app code -> GitHub via the REST API (the remote
::  is the object store). poke: {branch, message?}.
::
++  do-push
  |=  [=rail:tarball nam=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg=json  bind:m  (read-entry-json rail nam %'config.json')
  =/  repo=@t   (jstr cfg 'repo')
  =/  token=@t  (jstr cfg 'token')
  =/  app=@t    (jstr cfg 'app')
  =/  branch=@t  (jstr jon 'branch')
  =/  msg=@t
    =/  t=@t  (jstr jon 'message')
    ?:(=('' t) 'update from ship' t)
  ?:  |(=('' repo) =('' token) =('' app) =('' branch))
    ~&  >>>  [%desks nam %push %need-repo-token-app-branch]
    (pure:m ~)
  =/  base-branch=@t
    =/  r=@t  (jstr cfg 'ref')
    ?:(=('' r) 'main' r)
  =/  app-dir=path  /apps/[(crip (trip app))]
  ;<  live=(unit (list bfile))  bind:m
    (fetch-dir-at [%& %| (snoc app-dir %code)])
  =/  entries=(list [pax=tape txt=@t])
    %+  murn  (fall live ~)
    |=  b=bfile
    ^-  (unit [tape @t])
    =/  txt=(unit @t)  (bfile-text b)
    ?~  txt  ~
    `[(repo-path pax.b name.b) u.txt]
  ?:  =(~ entries)
    ~&  >>>  [%desks nam %push %nothing-to-push]
    (pure:m ~)
  ~&  >  [%desks nam %pushing (lent entries) %files %to branch]
  =/  api=@t  'https://api.github.com'
  =/  hdr  (gh-headers token)
  ;<  [st1=@ud base-jon=json]  bind:m
    (gh-call %'GET' (repo-url api repo (cat 3 '/git/ref/heads/' base-branch)) hdr ~)
  ?.  =(200 st1)
    ~&  >>>  [%desks %push %no-base-ref st1]
    (pure:m ~)
  =/  base-sha=@t  (ref-sha base-jon)
  ;<  [st2=@ud com-jon=json]  bind:m
    (gh-call %'GET' (repo-url api repo (cat 3 '/git/commits/' base-sha)) hdr ~)
  ?.  =(200 st2)
    ~&  >>>  [%desks %push %no-base-commit st2]
    (pure:m ~)
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
    (gh-call %'POST' (repo-url api repo '/git/trees') hdr `tree-body)
  ?.  =(201 st3)
    ~&  >>>  [%desks %push %tree-failed st3]
    (pure:m ~)
  =/  commit-body=json
    %-  pairs:enjs:format
    :~  ['message' s+msg]
        ['tree' s+(obj-sha tree-jon)]
        ['parents' a+~[s+base-sha]]
    ==
  ;<  [st4=@ud com2=json]  bind:m
    (gh-call %'POST' (repo-url api repo '/git/commits') hdr `commit-body)
  ?.  =(201 st4)
    ~&  >>>  [%desks %push %commit-failed st4]
    (pure:m ~)
  =/  new-sha=@t  (obj-sha com2)
  ;<  [st5=@ud *]  bind:m
    (gh-call %'GET' (repo-url api repo (cat 3 '/git/ref/heads/' branch)) hdr ~)
  ;<  [st6=@ud *]  bind:m
    ?:  =(200 st5)
      %-  gh-call
      :^    %'PATCH'
          (repo-url api repo (cat 3 '/git/refs/heads/' branch))
        hdr
      `(pairs:enjs:format ~[['sha' s+new-sha] ['force' b+%.n]])
    %-  gh-call
    :^    %'POST'
        (repo-url api repo '/git/refs')
      hdr
    `(pairs:enjs:format ~[['ref' s+(cat 3 'refs/heads/' branch)] ['sha' s+new-sha]])
  ?.  |(=(200 st6) =(201 st6))
    ~&  >>>  [%desks %push %ref-failed st6]
    (pure:m ~)
  ~&  >  [%desks nam %push %done branch (crip (scag 7 (trip new-sha)))]
  (pure:m ~)
::  bfile machinery (shared shapes with git/desk)
::
+$  bfile  [pax=path name=@ta =sang:tarball]
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
  =/  =mime  [(guess-mime name) data]
  `[dir name [/ %mime] %& !>(mime)]
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
++  fetch-dir-at
  |=  =road:tarball
  =/  m  (fiber:fiber:nexus ,(unit (list bfile)))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  (pure:m `(ball-to-files ball.view))
::
++  find-bfile
  |=  [files=(list bfile) pax=path name=@ta]
  ^-  (unit bfile)
  ?~  files  ~
  ?:  &(=(pax pax.i.files) =(name name.i.files))  `i.files
  $(files t.files)
++  version-from-sang
  |=  =sang:tarball
  ^-  (unit @ud)
  ?:  (is-boom:tarball sang)  ~
  =/  jon=(unit json)
    ?:  =([/ %json] p.sang)
      `!<(json (need-vase:tarball sang))
    ?.  =([/ %mime] p.sang)  ~
    (de:json:html q.q:!<(mime (need-vase:tarball sang)))
  ?~  jon  ~
  ?.  ?=([~ %o *] jon)  ~
  =/  v  (~(get by p.u.jon) 'version')
  ?.  ?=([~ %n *] v)  ~
  (rush p.u.v dem)
::
++  extract-version
  |=  files=(list [pax=path data=octs])
  ^-  (unit @ud)
  =/  vf=(unit octs)  (extract-file files ~['version.json'])
  ?~  vf  ~
  =/  jon=(unit json)  (de:json:html q.u.vf)
  ?~  jon  ~
  ?.  ?=([%o *] u.jon)  ~
  =/  v  (~(get by p.u.jon) 'version')
  ?.  ?=([~ %n *] v)  ~
  (rush p.u.v dem)
::
++  extract-file
  |=  [files=(list [pax=path data=octs]) target=path]
  ^-  (unit octs)
  ?~  files  ~
  ?:  =(pax.i.files target)  `data.i.files
  $(files t.files)
::  +apply-bill-entries: bill.json -> necked instance dirs under
::  data/. an existing instance dir is left untouched.
::
++  apply-bill-entries
  |=  [app-dir=path bfiles=(list bfile)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bill=(unit bfile)  (find-bfile bfiles ~ %'bill.json')
  ?~  bill  (pure:m ~)
  ?:  (is-boom:tarball sang.u.bill)  (pure:m ~)
  =/  jon=json
    ?:  =([/ %json] p.sang.u.bill)
      !<(json (need-vase:tarball sang.u.bill))
    ?.  =([/ %mime] p.sang.u.bill)  *json
    (fall (de:json:html q.q:!<(mime (need-vase:tarball sang.u.bill))) *json)
  ?.  ?=([%o *] jon)  (pure:m ~)
  =/  entries=(list [k=@t v=json])  ~(tap by p.jon)
  |-
  ?~  entries  (pure:m ~)
  =/  nam=@ta  (crip (trip k.i.entries))
  =/  cod=(unit path)
    ?.  ?=(%s -.v.i.entries)  ~
    (mole |.((stab p.v.i.entries)))
  ?~  cod  $(entries t.entries)
  =/  neck=rail:tarball  [(snip u.cod) (rear u.cod)]
  =/  dir-road=road:tarball  [%& %| (weld app-dir /data/[nam])]
  ;<  =view:nexus  bind:m  (peek:io dir-road ~)
  ?:  ?=([%ball *] view)  $(entries t.entries)
  ~&  >  [%desks %bill-instance nam neck]
  ;<  ~  bind:m  (make:io dir-road &+`bole:tarball`[`[`neck ~ %.n ~] ~])
  $(entries t.entries)
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
::  git transport (shared shapes with git/desk)
::
++  do-fetch
  |=  [repo=@t ref=@t]
  =/  m  (fiber:fiber:nexus ,(list [pax=path data=octs]))
  ^-  form:m
  ;<  disc=discovery:git-transport  bind:m  (fetch-discovery repo)
  =/  ref=@t
    ?:  =('' ref)
      (fall (default-branch:git-transport caps.disc) 'main')
    ref
  =/  want-hashes=(list @ux)
    (turn refs.disc |=(r=git-ref:git-transport hash.r))
  ;<  pack-body=octs  bind:m  (fetch-pack repo want-hashes)
  =/  pack-data=octs  (extract-pack:git-transport pack-body %.y)
  =/  =pack:git-pack
    (read:git-pack (from-octs:bytestream pack-data))
  =/  repo-obj=repository:git-repo
    (~(clone-from-pack git-repo *repository:git-repo) pack refs.disc)
  =/  sto  store:~(. git-repo repo-obj)
  =/  ref-hash=(unit @ux)
    =+  got=(get:refs:~(. git-repo repo-obj) ~[ref])
    ?^  got  got
    (get:refs:~(. git-repo repo-obj) ~['refs' 'heads' ref])
  =/  commit-hash=@ux  (fall ref-hash 0x0)
  =/  com=(unit commit:git-repo)  (get-commit:sto commit-hash)
  ?~  com
    ~&  >>>  [%desks %commit-not-found]
    (pure:m ~)
  =/  get-tree=$-(@ux (unit tree-dir:git-repo))
    |=(h=@ux (get-tree:sto h))
  =/  get-blob=$-(@ux (unit octs))
    |=(h=@ux (get-blob:sto h))
  (pure:m (checkout:git-transport get-tree get-blob tree.u.com))
::
++  fetch-discovery
  |=  repo=@t
  =/  m  (fiber:fiber:nexus ,discovery:git-transport)
  ^-  form:m
  =/  url=@t
    (rap 3 ~['https://github.com/' repo '.git/info/refs?service=git-upload-pack'])
  ;<  body=octs  bind:m
    (fetch-with-redirect [%'GET' url ~[['User-Agent' 'grubbery']] ~])
  (pure:m (parse-discovery:git-transport body))
::
++  fetch-pack
  |=  [repo=@t want=(list @ux)]
  =/  m  (fiber:fiber:nexus ,octs)
  ^-  form:m
  =/  url=@t
    (rap 3 ~['https://github.com/' repo '.git/git-upload-pack'])
  =/  body=octs
    (build-want:git-transport want ~['side-band-64k' 'ofs-delta'] ~ ~)
  %-  fetch-with-redirect
  :^    %'POST'
      url
    :~  ['User-Agent' 'grubbery']
        ['Content-Type' 'application/x-git-upload-pack-request']
    ==
  `body
::
++  fetch-with-redirect
  |=  [=request:http]
  =/  m  (fiber:fiber:nexus ,octs)
  ^-  form:m
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.client-response)
    ~|  "%desks: request failed"  !!
  =/  status  status-code.response-header.client-response
  ?:  ?|  =(status 301)
          =(status 302)
          =(status 307)
      ==
    =/  location=(unit @t)
      (~(get by (malt headers.response-header.client-response)) 'location')
    ?~  location  ~|(%desks-redirect-no-location !!)
    ;<  ~  bind:m  (send-request:io [%'GET' u.location ~[['User-Agent' 'grubbery']] ~])
    ;<  =client-response:iris  bind:m  take-client-response:io
    ?.  ?=(%finished -.client-response)
      ~|  "%desks: redirect failed"  !!
    ?~  full-file.client-response
      ~|  "%desks: empty after redirect"  !!
    (pure:m data.u.full-file.client-response)
  ?.  =(200 status)
    ~|  "%desks: HTTP {<status>}"  !!
  ?~  full-file.client-response
    ~|  "%desks: empty response"  !!
  (pure:m data.u.full-file.client-response)
::  github REST helpers
::
++  repo-url
  |=  [api=@t repo=@t tail=@t]
  ^-  @t
  (cat 3 api (cat 3 '/repos/' (cat 3 repo tail)))
::
++  gh-headers
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
++  obj-sha  |=(jon=json (jstr jon 'sha'))
::
++  ref-sha
  |=  jon=json
  ^-  @t
  ?.  ?=([%o *] jon)  ''
  =/  obj  (~(get by p.jon) 'object')
  ?~  obj  ''
  (jstr u.obj 'sha')
::
++  commit-tree-sha
  |=  jon=json
  ^-  @t
  ?.  ?=([%o *] jon)  ''
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
  =/  =mime  !<(mime (need-vase:tarball sang.b))
  `q.q.mime
--
