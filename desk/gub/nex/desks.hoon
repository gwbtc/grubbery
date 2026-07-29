::  desks: one UI over the desk nexuses installed in /apps. it owns no
::  transport of its own — the /desk (cross-ship) and /git/desk (git)
::  nexuses do the real work. desks discovers their instances by
::  convention (a dir named <x>.desk or <x>.git_desk), reads their
::  state (config + version), and drives their actions by poking. this
::  is the UI half of the desk / tiles / notifications shell.
::
::  /main.sig              HTTP at /grubbery/desks
::  /requests/             per-request handlers; also serves:
::    GET  /list           discovered desks as json
::  /index.html /app.js /style.css /icon.svg /tile.json   static UI
::
/&  icon        desks/icon.svg
/&  desks-html  desks/index.html
/&  desks-js    desks/app.js
/&  desks-css   desks/style.css
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Desks'
            info+s+'Installed desks'
            color+s+'#8558b0'
            image+s+'/grubbery/tiles/icon/desks.desks'
            href+s+'/grubbery/desks'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'index.html'] [[/ %mime] desks-html]]
          [%over %& [/ %'app.js'] [[/ %mime] desks-js]]
          [%over %& [/ %'style.css'] [[/ %mime] desks-css]]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%desks main: failed")
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/desks])
        (http-dispatch:io %desks)
          ::
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%desks request: failed")
        =/  eyre-id=@ta  name.rail
        =/  s  ~(. http-res:io (nex-road:io rail [%& / %'main.sig']))
        ;<  [src=@p req=inbound-request:eyre]  bind:m
          (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:s eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  suffix=path
          %+  skip  (slag (lent `path`/grubbery/desks) site)
          |=(seg=@ta =('' seg))
        ::  writes: add / configure / drive a backend
        ?:  =('POST' method.request.req)
          =/  body=@t  ?~(body.request.req '' q.u.body.request.req)
          =/  jon=json  (fall (de:json:html body) *json)
          ?+    suffix
            ;<  ~  bind:m  (send-simple:s eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
              [%add ~]     (do-add rail eyre-id jon)
              [%config ~]  (do-config rail eyre-id jon)
              [%sync ~]    (do-sync rail eyre-id jon)
              [%push ~]    (do-push rail eyre-id jon)
              [%detail ~]  (do-detail rail eyre-id jon)
              [%delete ~]  (do-delete rail eyre-id jon)
          ==
        ::  reads: the discovered desk list
        ?:  ?=([%list ~] suffix)
          ;<  lst=json  bind:m  discover-desks
          =/  bod=octs  (as-octs:mimes:html (en:json:html lst))
          ;<  ~  bind:m  (send-simple:s eyre-id (mime-response:http-utils [/application/json bod]))
          (pure:m ~)
        ::  otherwise serve a static file from the nexus root
        =/  filename=@ta  ?~(suffix 'index.html' i.suffix)
        ;<  fv=view:nexus  bind:m
          (peek:io (nex-road:io rail [%& / filename]) `[/ %mime])
        ?.  ?=([%file *] fv)
          ;<  ~  bind:m  (send-simple:s eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
          (pure:m ~)
        =/  =mime  !<(mime (need-vase:tarball sang.fv))
        ;<  ~  bind:m  (send-simple:s eyre-id (mime-response:http-utils mime))
        (pure:m ~)
      ==
    --
|%
::  +discover-desks: every /apps/<x>.desk and <x>.git_desk, with its
::  config (minus any token) and current version, as a json array.
::
++  discover-desks
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io [%& %| /apps] ~)
  ?.  ?=([%ball *] view)  (pure:m a+~)
  =/  apps=(list @ta)  ~(tap in ~(key by dir.ball.view))
  ;<  cards=(list json)  bind:m  (gather apps)
  (pure:m a+cards)
::
++  gather
  |=  apps=(list @ta)
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ?~  apps  (pure:m ~)
  ;<  one=(unit json)  bind:m  (desk-card i.apps)
  ;<  rest=(list json)  bind:m  $(apps t.apps)
  (pure:m ?~(one rest [u.one rest]))
::
++  desk-card
  |=  app=@ta
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  =/  typ=(unit @t)  (desk-type app)
  ?~  typ  (pure:m ~)
  ;<  cfg=(unit json)  bind:m
    (peek-as:io [%& %& /apps/[app] %'config.json'] ,json)
  ;<  ver=(unit @ud)  bind:m
    (peek-as:io [%& %& /apps/[app] %'version.ud'] ,@ud)
  =/  cm=(map @t json)  ?:(?=([~ %o *] cfg) p.u.cfg ~)
  =/  get  |=(k=@t `json`(~(gut by cm) k ~))
  =/  card=json
    %-  pairs:enjs:format
    :~  ['name' s+app]
        ['type' s+u.typ]
        ['version' (numb:enjs:format (fall ver 0))]
        ['repo' (get 'repo')]
        ['ref' (get 'ref')]
        ['source' (get 'source')]
        ['poll' (get 'poll')]
        ['public' (get 'public')]
        ['token' (get 'token')]
        ['url' s+(desk-url app u.typ)]
    ==
  (pure:m `card)
::  +desk-type: 'git' for <x>.git_desk, 'cross-ship' for <x>.desk, else
::  ~ (not a desk we manage).
::
++  desk-type
  |=  app=@ta
  ^-  (unit @t)
  =/  t=tape  (trip app)
  =/  idx=(unit @ud)  (find "." (flop t))
  ?~  idx  ~
  =/  suff=@t  (crip (slag (sub (lent t) u.idx) t))
  ?:  =('git_desk' suff)  `'git'
  ?:  =('desk' suff)  `'cross-ship'
  ~
::  +desk-url: the backend nexus's own page (until its UI is folded in)
::
++  desk-url
  |=  [app=@ta typ=@t]
  ^-  @t
  =/  slug=@t  (desk-slug app)
  ?:  =('git' typ)  (cat 3 '/grubbery/git-desk/' slug)
  (cat 3 '/grubbery/desk/' slug)
::  +desk-slug: the dir name before the first dot ('wallet.git_desk' ->
::  'wallet'), matching how the backends bind their URLs.
::
++  desk-slug
  |=  app=@ta
  ^-  @t
  =/  t=tape  (trip app)
  =/  idx=(unit @ud)  (find "." t)
  ?~  idx  app
  (crip (scag u.idx t))
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
++  jbol
  |=  [jon=json k=@t]
  ^-  ?
  ?.  ?=([%o *] jon)  %.n
  =/  v  (~(get by p.jon) k)
  ?.(?=([~ %b *] v) %.n p.u.v)
::  +app-weir: the standard weir (upward makes vetoed, poke/peek open)
::  for instances desks creates.
::
++  app-weir
  ^-  (unit weir:tarball)
  `[make=~ poke=(sy ~[[%& %| /]]) peek=(sy ~[[%& %| /]])]
::  +respond: a plaintext HTTP reply through main.sig
::
++  respond
  |=  [=rail:tarball eyre-id=@ta code=@ud msg=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  %+  ~(send-simple http-res:io (nex-road:io rail [%& / %'main.sig']))
    eyre-id
  [[code ~] `(as-octs:mimes:html msg)]
::  +do-add: create a new backend in /apps and configure it — same
::  shape as create-desk: make a [/git %desk] or [/ %desk] necked dir,
::  poke config, and (git with a repo) kick an initial sync.
::
++  do-add
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  name=@t  (jstr jon 'name')
  =/  typ=@t   (jstr jon 'type')
  =/  is-git=?  =('git' typ)
  ?:  =('' name)  (respond rail eyre-id 400 'name required')
  ?.  |(is-git =('cross-ship' typ) =('desk' typ))
    (respond rail eyre-id 400 'type must be git or cross-ship')
  =/  dir-name=@ta
    (cat 3 (crip (trip name)) ?:(is-git '.git_desk' '.desk'))
  =/  dir-path=path  /apps/[dir-name]
  ;<  live=?  bind:m  (peek-exists:io [%& %| dir-path])
  ?:  live  (respond rail eyre-id 409 'a desk by that name already exists')
  =/  neck=rail:tarball  ?:(is-git [/git %desk] [/ %desk])
  ;<  ~  bind:m
    (make:io [%& %| dir-path] &+`bole:tarball`[`[`neck app-weir %.n ~] ~])
  =/  config=json
    ?:  is-git
      %-  pairs:enjs:format
      :~  ['repo' s+(jstr jon 'repo')]
          ['ref' s+?:(=('' (jstr jon 'ref')) 'main' (jstr jon 'ref'))]
          ['public' b+(jbol jon 'public')]
          ['poll' (numb:enjs:format (jnum jon 'poll'))]
          ['token' s+(jstr jon 'token')]
      ==
    %-  pairs:enjs:format
    :~  ['source' s+(jstr jon 'source')]
        ['public' b+(jbol jon 'public')]
    ==
  ;<  ~  bind:m  (poke:io [%& %& dir-path %'config.json'] [[/ %json] config])
  ?:  &(is-git !=('' (jstr jon 'repo')))
    ;<  ~  bind:m  (poke:io [%& %& dir-path %'sync.sig'] [[/ %sig] ~])
    (respond rail eyre-id 200 'created')
  (respond rail eyre-id 200 'created')
::  +do-config: merge poked fields into a backend's config.json. string
::  fields overwrite only when non-empty (so a blank token is kept);
::  poll + public are set whenever the form sends them.
::
++  do-config
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  app=@t  (jstr jon 'app')
  ?:  =('' app)  (respond rail eyre-id 400 'app required')
  =/  cfg-road=road:tarball  [%& %& /apps/[(crip (trip app))] %'config.json']
  ;<  old=(unit json)  bind:m  (peek-as:io cfg-road ,json)
  =/  om=(map @t json)  ?:(?=([~ %o *] old) p.u.old ~)
  =/  jm=(map @t json)  ?:(?=([%o *] jon) p.jon ~)
  ::  the form is the source of truth — write back exactly the fields it
  ::  sent (a blank token clears the token; absent fields are untouched).
  =/  put-present
    |=  [mp=(map @t json) k=@t]
    ^-  (map @t json)
    =/  v  (~(get by jm) k)
    ?~(v mp (~(put by mp) k u.v))
  =.  om  (put-present om 'repo')
  =.  om  (put-present om 'ref')
  =.  om  (put-present om 'source')
  =.  om  (put-present om 'token')
  =.  om  (put-present om 'poll')
  =.  om  (put-present om 'public')
  ;<  ~  bind:m  (poke:io cfg-road [[/ %json] [%o om]])
  (respond rail eyre-id 200 'configured')
::  +do-detail: a backend's fuller state for the detail modal — its
::  config, version, and the checkpoint history of its code + data
::  axes (the "open the desk's page" content, served inline).
::
++  do-detail
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  app=@t  (jstr jon 'app')
  ?:  =('' app)  (respond rail eyre-id 400 'app required')
  =/  ap=@ta  (crip (trip app))
  ;<  cfg=(unit json)  bind:m
    (peek-as:io [%& %& /apps/[ap] %'config.json'] ,json)
  ;<  ver=(unit @ud)  bind:m
    (peek-as:io [%& %& /apps/[ap] %'version.ud'] ,@ud)
  ;<  code=(each binfo tang)  bind:m  (born:io [%& %| (weld /apps/[ap] /desk/code)])
  ;<  data=(each binfo tang)  bind:m  (born:io [%& %| (weld /apps/[ap] /desk/data)])
  =/  out=json
    %-  pairs:enjs:format
    :~  ['config' (fall cfg [%o ~])]
        ['version' (numb:enjs:format (fall ver 0))]
        ['code' (binfo-to-json code)]
        ['data' (binfo-to-json data)]
    ==
  =/  bod=octs  (as-octs:mimes:html (en:json:html out))
  %+  ~(send-simple http-res:io (nex-road:io rail [%& / %'main.sig']))
    eyre-id
  (mime-response:http-utils [/application/json bod])
::  born-history metadata + its json shape (only firmed, tagged, live
::  revisions are checkpoints worth showing).
::
+$  binfo  (list [=cass:clay tags=(set @t) tomb=?])
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
::  +do-sync: poke a git backend's sync.sig to fetch + install.
::
++  do-sync
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  app=@t  (jstr jon 'app')
  ?:  =('' app)  (respond rail eyre-id 400 'app required')
  ;<  ~  bind:m
    (poke:io [%& %& /apps/[(crip (trip app))] %'sync.sig'] [[/ %sig] ~])
  (respond rail eyre-id 200 'syncing')
::  +do-push: poke a git backend's push.sig with {branch, message}.
::
++  do-push
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  app=@t  (jstr jon 'app')
  ?:  =('' app)  (respond rail eyre-id 400 'app required')
  =/  push-body=json
    %-  pairs:enjs:format
    :~  ['branch' s+(jstr jon 'branch')]
        ['message' s+(jstr jon 'message')]
    ==
  ;<  ~  bind:m
    (poke:io [%& %& /apps/[(crip (trip app))] %'push.sig'] [[/ %json] push-body])
  (respond rail eyre-id 200 'pushing')
::  +do-delete: remove a desk entirely — cull its /apps/<app> subtree,
::  the same op delete_folder uses. gone from the ship, not from git.
::
++  do-delete
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  app=@t  (jstr jon 'app')
  ?:  =('' app)  (respond rail eyre-id 400 'app required')
  ;<  ~  bind:m  (cull:io [%& %| /apps/[(crip (trip app))]])
  (respond rail eyre-id 200 'deleted')
--
