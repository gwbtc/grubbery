::  git/forge: the single UI over git repo instances. Repos live under
::  /repos/<name>.git_repo; forge creates them, reads their state,
::  and drives their actions by poking. Transport stays in /git/repo —
::  this is the visibility layer.
::
::  /main.sig    HTTP at /grubbery/forge
::  /requests/   per-request handlers. Page URLs:
::    /                      the workspace shell
::    /repo/<name>           a repo's workspace (?file=, ?panel=)
::  Data endpoints live under /api:
::    GET  /api/list /api/detail?repo= /api/src
::    POST /api/add /api/delete /api/action /api/config /api/src
::  /repos/      the repo instances
::
/<  git-act  /lib/git/action.hoon
/&  icon        forge/icon.svg
/&  forge-html  forge/index.html
/&  forge-js    forge/app.js
/&  forge-css   forge/style.css
::  web-component kit: shared sources in /lib/ui (one copy for all nexuses),
::  welded into one components.js bundle in on-load so a page makes a single
::  request (no staggered per-file "flash-in").
/&  modal-js    /lib/ui/modal-dialog.js
/&  dropmenu-js  /lib/ui/drop-menu.js
/&  splitview-js  /lib/ui/split-view.js
::  shared classic helper (window.FilePreview) — loaded before app.js
/&  fp-js       /lib/ui/file-preview.js
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Forge'
            info+s+'git repos'
            color+s+'#3d3a45'
            image+s+'/grubbery/tiles/icon/forge.git_forge'
            href+s+'/grubbery/forge'
        ==
      ::  kit bundle: weld the components into one file. Each is wrapped in a
      ::  { } block so top-level consts don't collide; define runs globally.
      ::  123={  125=}  10=newline.
      =/  wrap  |=(=mime ^-(@ (rap 3 ~[123 10 q.q.mime 10 125 10])))
      =/  kit-js=mime
        :-  /application/javascript
        (as-octs:mimes:html (rap 3 ~[(wrap modal-js) (wrap dropmenu-js) (wrap splitview-js)]))
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%fall %| /repos empty-dir:loader]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'index.html'] [[/ %mime] forge-html]]
          [%over %& [/ %'app.js'] [[/ %mime] forge-js]]
          [%over %& [/ %'style.css'] [[/ %mime] forge-css]]
          [%over %& [/ %'components.js'] [[/ %mime] kit-js]]
          [%over %& [/ %'file-preview.js'] [[/ %mime] fp-js]]
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
        ;<  ~  bind:m  (rise-wait:io prod "%forge main: failed")
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/forge])
        (http-dispatch:io %forge)
          ::
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%forge request: failed")
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
          %+  skip  (slag (lent `path`/grubbery/forge) site)
          |=(seg=@ta =('' seg))
        ?:  =('POST' method.request.req)
          =/  body=@t  ?~(body.request.req '' q.u.body.request.req)
          =/  jon=json  (fall (de:json:html body) *json)
          ?+    suffix
            ;<  ~  bind:m  (send-simple:s eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
              [%api %add ~]     (do-add rail eyre-id jon)
              [%api %src ~]     (do-src rail eyre-id jon)
              [%api %src-delete ~]  (do-src-del rail eyre-id jon)
              [%api %delete ~]  (do-delete rail eyre-id jon)
              [%api %config ~]  (do-config rail eyre-id jon)
              [%api %run ~]     (do-run rail eyre-id jon)
          ==
        ?:  ?=([%api %list ~] suffix)
          ;<  lst=json  bind:m  (gather-repos rail)
          (send-json rail eyre-id lst)
        ?:  ?=([%api %detail ~] suffix)
          =/  repo=(unit @t)  (quay-get args 'repo')
          ?~  repo  (respond rail eyre-id 400 'repo required')
          ;<  det=json  bind:m  (gather-detail rail u.repo)
          (send-json rail eyre-id det)
        ?:  ?=([%api %src ~] suffix)
          =/  repo=(unit @t)  (quay-get args 'repo')
          =/  file=(unit @t)  (quay-get args 'file')
          ?:  |(?=(~ repo) ?=(~ file))
            (respond rail eyre-id 400 'repo and file required')
          =/  root=path  (src-root (fall (quay-get args 'root') 'tree'))
          =/  pax=(unit [dir=path name=@ta])  (parse-src-path u.file)
          ?~  pax  (respond rail eyre-id 400 'bad path')
          ;<  fv=view:nexus  bind:m
            %+  peek:io
              %+  nex-road:io  rail
              [%& :(weld /repos/[`@ta`u.repo] root dir.u.pax) name.u.pax]
            `[/ %mime]
          ?.  ?=([%file *] fv)
            (respond rail eyre-id 404 'not found')
          =/  txt=@t
            ?:  (is-boom:tarball sang.fv)  ''
            =/  got  (mule |.(!<(mime (need-vase:tarball sang.fv))))
            ?:(?=(%| -.got) '' `@t`q.q.p.got)
          (send-json rail eyre-id (pairs:enjs:format ~[['text' s+txt]]))
        ::  page URLs serve the shell; anything else is a static file
        =/  filename=@ta
          ?~  suffix  'index.html'
          ?:  ?=([%repo *] suffix)  'index.html'
          i.suffix
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
++  jstr
  |=  [j=json k=@t]
  ^-  @t
  ?.  ?=(%o -.j)  ''
  =/  v  (~(get by p.j) k)
  ?.(?=([~ %s *] v) '' p.u.v)
::
++  quay-get
  |=  [args=quay:eyre k=@t]
  ^-  (unit @t)
  =/  l  (skim args |=([p=@t q=@t] =(p k)))
  ?~(l ~ `q.i.l)
::
++  respond
  |=  [=rail:tarball eyre-id=@ta code=@ud msg=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m
    %+  ~(send-simple http-res:io (nex-road:io rail [%& / %'main.sig']))
      eyre-id
    [[code ~] `(as-octs:mimes:html msg)]
  (pure:m ~)
::
++  send-json
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=octs  (as-octs:mimes:html (en:json:html jon))
  ;<  ~  bind:m
    %+  ~(send-simple http-res:io (nex-road:io rail [%& / %'main.sig']))
      eyre-id
    [[200 ~[['content-type' 'application/json']]] `bod]
  (pure:m ~)
::  +src-root: the subtree a src request targets — the working tree.
::
++  src-root
  |=  root=@t
  ^-  path
  /data/tree
::  +parse-src-path: a client file path like "lib/commit-all.hoon"
::  as [dir name], rejecting anything that could walk out of the tree
::
++  parse-src-path
  |=  file=@t
  ^-  (unit [dir=path name=@ta])
  =/  t=tape  (trip file)
  =.  t  ?:(&(?=(^ t) =('/' i.t)) t.t t)
  =/  pax=(unit path)  (rush (crip (weld "/" t)) stap)
  ?~  pax  ~
  ?.  %+  levy  `path`u.pax
      |=(seg=@ta !|(=('' seg) =('.' seg) =('..' seg)))
    ~
  =/  flopped=path  (flop `path`u.pax)
  ?~  flopped  ~
  `[(flop `path`t.flopped) i.flopped]
::  +walk-files: every file path in a ball, depth-first, sorted
::
++  walk-files
  |=  [=ball:tarball here=path]
  ^-  (list path)
  =/  fils=(list path)
    ?~  fil.ball  ~
    %+  turn  (sort ~(tap in ~(key by contents.u.fil.ball)) aor)
    |=(n=@ta (snoc here n))
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.ball)
  |-  ^-  (list path)
  ?~  kids  fils
  %+  weld  ^$(ball +.i.kids, here (snoc here -.i.kids))
  $(kids t.kids)
::  +gather-repos: every instance under /repos as a card — config
::  (minus token) plus the current.json its data nexus maintains
::
++  gather-repos
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io (nex-road:io rail [%| /repos]) ~)
  ?.  ?=([%ball *] view)  (pure:m a+~)
  =/  kids=(list @ta)  (sort ~(tap in ~(key by dir.ball.view)) aor)
  =|  acc=(list json)
  |-
  ?~  kids  (pure:m a+(flop acc))
  =/  kid=@ta  i.kids
  ;<  cfg=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /repos/[kid] %'config.json']) ,json)
  ;<  poll-cfg=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /repos/[kid] %'poll.json']) ,json)
  ;<  cur=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /repos/[kid]/data/ui %'current.json']) ,json)
  ;<  commits=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /repos/[kid]/data/ui %'commits.json']) ,json)
  =/  last=json
    ?.  ?&(?=(^ commits) ?=(%a -.u.commits) ?=(^ p.u.commits))  ~
    i.p.u.commits
  =/  card=json
    %-  pairs:enjs:format
    :~  ['name' s+kid]
        ['repo' s+?~(cfg '' (jstr u.cfg 'repo'))]
        ['ref' s+?~(cfg '' (jstr u.cfg 'ref'))]
        ['account' s+?~(cfg '' (jstr u.cfg 'account'))]
        ['author_name' s+?~(cfg '' (jstr u.cfg 'author_name'))]
        ['author_email' s+?~(cfg '' (jstr u.cfg 'author_email'))]
        :-  'poll'
        ?~  poll-cfg  ~
        ?.  ?=(%o -.u.poll-cfg)  ~
        (fall (~(get by p.u.poll-cfg) 'minutes') ~)
        ['current' ?~(cur ~ u.cur)]
        ['last' last]
    ==
  $(kids t.kids, acc [card acc])
::  +gather-detail: the ui outputs the repo's data nexus maintains
::
++  gather-detail
  |=  [=rail:tarball repo=@t]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  kid=@ta  `@ta`repo
  ;<  status=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /repos/[kid]/data/ui %'status.json']) ,json)
  ;<  commits=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /repos/[kid]/data/ui %'commits.json']) ,json)
  ;<  branches=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /repos/[kid]/data/ui %'branches.json']) ,json)
  ;<  cur=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /repos/[kid]/data/ui %'current.json']) ,json)
  ;<  tv=view:nexus  bind:m
    (peek:io (nex-road:io rail [%| /repos/[kid]/data/tree]) ~)
  =/  tree=(list path)
    ?.  ?=([%ball *] tv)  ~
    (walk-files ball.tv /)
  ::  the command lane's state (queue/active/log), grown to json
  ;<  lv=view:nexus  bind:m
    (peek:io (nex-road:io rail [%& /repos/[kid] %'run.git-action']) ~)
  =/  lane=json
    ?.  ?=([%file *] lv)  ~
    =/  s=(unit action-state:git-act)
      (mole |.(!<(action-state:git-act (need-vase:tarball sang.lv))))
    ?~(s ~ (state-to-json:git-act u.s))
  %-  pure:m
  %-  pairs:enjs:format
  :~  ['status' (fall status ~)]
      ['commits' (fall commits ~)]
      ['branches' (fall branches ~)]
      ['current' (fall cur ~)]
      ['tree' a+(turn tree |=(p=path s+(crip (slag 1 (spud p)))))]
      ['lane' lane]
  ==
::  +do-add: create a repo instance under /repos, write its config,
::  and kick a first sync when a remote is configured
::
++  do-add
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  name=@t  (jstr jon 'name')
  ?:  =('' name)  (respond rail eyre-id 400 'name required')
  =/  dir-name=@ta  (cat 3 name '.git_repo')
  =/  dir-road=road:tarball  (nex-road:io rail [%| /repos/[dir-name]])
  ;<  live=?  bind:m  (peek-exists:io dir-road)
  ?:  live  (respond rail eyre-id 409 'a repo by that name already exists')
  ;<  ~  bind:m
    (make:io dir-road &+`bole:tarball`[`[`[/git %repo] ~ %.n ~] ~])
  ;<  ~  bind:m  (gain:io dir-road %.y)
  =/  config=json
    %-  pairs:enjs:format
    :~  ['repo' s+(jstr jon 'repo')]
        ['ref' s+?:(=('' (jstr jon 'ref')) 'main' (jstr jon 'ref'))]
        ['token' s+(jstr jon 'token')]
        ['account' s+(jstr jon 'account')]
    ==
  ;<  ~  bind:m
    (over:io (nex-road:io rail [%& /repos/[dir-name] %'config.json']) [[/ %json] config])
  ?:  =('' (jstr jon 'repo'))
    (respond rail eyre-id 200 'created')
  ;<  ~  bind:m
    %+  poke:io  (nex-road:io rail [%& /repos/[dir-name] %'run.git-action'])
    [[/ %json] (pairs:enjs:format ~[['command' s+'pull']])]
  (respond rail eyre-id 200 'created')
::  +do-src: write a working-tree file — the in-browser editor's save.
::
++  do-src
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  repo=@t  (jstr jon 'repo')
  =/  file=@t  (jstr jon 'file')
  =/  text=(unit json)  ?.(?=(%o -.jon) ~ (~(get by p.jon) 'text'))
  ?:  |(=('' repo) =('' file))
    (respond rail eyre-id 400 'repo and file required')
  ?.  ?=([~ %s *] text)  (respond rail eyre-id 400 'text required')
  =/  root=path  (src-root (jstr jon 'root'))
  =/  pax=(unit [dir=path name=@ta])  (parse-src-path file)
  ?~  pax  (respond rail eyre-id 400 'bad path')
  =/  =road:tarball
    %+  nex-road:io  rail
    [%& :(weld /repos/[`@ta`repo] root dir.u.pax) name.u.pax]
  ;<  has=?  bind:m  (peek-exists:io road)
  ?:  has
    ::  tree files keep whatever blot the checkout gave them
    ::  (over-as tubes the text through it)
    ;<  cur=view:nexus  bind:m  (peek:io road ~)
    =/  src-mime=mime  [/text/plain (as-octs:mimes:html p.u.text)]
    ;<  ~  bind:m
      ?:  ?&(?=([%file *] cur) !=([/ %mime] p.sang.cur))
        ?:  =([/ %hoon] p.sang.cur)
          (over:io road [[/ %hoon] p.u.text])
        (over-as:io road [[/ %mime] src-mime] p.sang.cur)
      (over:io road [[/ %mime] src-mime])
    ;<  ~  bind:m  (refresh-status rail repo root)
    (respond rail eyre-id 200 'saved')
  =/  =bask:tarball
    [[/ %mime] `mime`[/text/plain (as-octs:mimes:html p.u.text)]]
  ;<  err=(unit tang)  bind:m  (make-soft:io road |+[bask ~])
  ?^  err  (respond rail eyre-id 500 'create failed')
  ;<  ~  bind:m  (gain:io road %.y)
  ;<  ~  bind:m  (refresh-status rail repo root)
  (respond rail eyre-id 200 'created')
::  +do-config: merge repo/ref/token fields into a repo's config.
::  Empty strings leave the existing value alone, so the form can
::  send only what changed (and never needs to echo the token).
::
++  do-config
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  repo=@t  (jstr jon 'repo')
  ?:  =('' repo)  (respond rail eyre-id 400 'repo required')
  =/  cfg-road=road:tarball
    (nex-road:io rail [%& /repos/[`@ta`repo] %'config.json'])
  ;<  cur=(unit json)  bind:m  (peek-as:io cfg-road ,json)
  =/  om=(map @t json)  ?:(?=([~ %o *] cur) p.u.cur ~)
  =/  origin=@t  (jstr jon 'origin')
  =?  om  !=('' origin)  (~(put by om) 'repo' s+origin)
  =/  ref=@t  (jstr jon 'ref')
  =?  om  !=('' ref)  (~(put by om) 'ref' s+ref)
  =/  token=@t  (jstr jon 'token')
  =?  om  !=('' token)  (~(put by om) 'token' s+token)
  =/  aname=@t  (jstr jon 'author_name')
  =?  om  !=('' aname)  (~(put by om) 'author_name' s+aname)
  =/  aemail=@t  (jstr jon 'author_email')
  =?  om  !=('' aemail)  (~(put by om) 'author_email' s+aemail)
  =/  pol=(unit json)  ?.(?=(%o -.jon) ~ (~(get by p.jon) 'poll'))
  ::  account is not secret, so the form always echoes it: presence
  ::  means set, empty string means clear (back to any-account)
  =/  acc=(unit json)  ?.(?=(%o -.jon) ~ (~(get by p.jon) 'account'))
  =?  om  ?=([~ %s *] acc)
    ?:(=('' p.u.acc) (~(del by om) 'account') (~(put by om) 'account' s+p.u.acc))
  ;<  ~  bind:m  (over:io cfg-road [[/ %json] `json`[%o om]])
  ::  the poll interval lives in its own daemon grub (poll.json), not config
  ;<  ~  bind:m
    ?.  ?=([~ %n *] pol)  (pure:m ~)
    %+  over:io  (nex-road:io rail [%& /repos/[`@ta`repo] %'poll.json'])
    [[/ %json] (pairs:enjs:format ~[['minutes' u.pol]])]
  (respond rail eyre-id 200 'saved')
::  +refresh-status: after a working-tree write, reload the repo's
::  data nexus so its derived ui (status especially) reflects the
::  edit. The reload is safe for the tree — checkout never clobbers
::  a live working tree.
::
++  refresh-status
  |=  [=rail:tarball repo=@t root=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  =(/data/tree root)  (pure:m ~)
  (reload:io (nex-road:io rail [%| /repos/[`@ta`repo]/data]))
::  +do-src-del: delete a file from the working tree
::
++  do-src-del
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  repo=@t  (jstr jon 'repo')
  =/  file=@t  (jstr jon 'file')
  ?:  |(=('' repo) =('' file))
    (respond rail eyre-id 400 'repo and file required')
  =/  root=path  (src-root (jstr jon 'root'))
  =/  pax=(unit [dir=path name=@ta])  (parse-src-path file)
  ?~  pax  (respond rail eyre-id 400 'bad path')
  ;<  err=(unit tang)  bind:m
    %-  cull-soft:io
    %+  nex-road:io  rail
    [%& :(weld /repos/[`@ta`repo] root dir.u.pax) name.u.pax]
  ?^  err  (respond rail eyre-id 500 'delete failed')
  ;<  ~  bind:m  (refresh-status rail repo root)
  (respond rail eyre-id 200 'deleted')
::
++  do-delete
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  repo=@t  (jstr jon 'repo')
  ?:  =('' repo)  (respond rail eyre-id 400 'repo required')
  ;<  err=(unit tang)  bind:m
    (cull-soft:io (nex-road:io rail [%| /repos/[`@ta`repo]]))
  ?^  err  (respond rail eyre-id 500 'delete failed')
  (respond rail eyre-id 200 'deleted')
::  +do-action: drive one of the repo's action files. sig actions
::  take an empty poke, txt actions the text field as a wain, add
::  a json payload
::
::  +do-run: submit a git command to a repo's serial command lane. Pokes
::  /run.git-action with {command}; the lane parses and runs it.
::
++  do-run
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  repo=@t     (jstr jon 'repo')
  =/  command=@t  (jstr jon 'command')
  ?:  |(=('' repo) =('' command))
    (respond rail eyre-id 400 'repo and command required')
  ;<  ~  bind:m
    %+  poke:io  (nex-road:io rail [%& /repos/[`@ta`repo] %'run.git-action'])
    [[/ %json] (pairs:enjs:format ~[['command' s+command]])]
  (respond rail eyre-id 200 'ok')
::
--
