::  git/forge: the single UI over git repo instances. Repos live under
::  /repos/<name>.git_repo; forge creates them, reads their state,
::  and drives their actions and tools by poking. Transport stays in
::  /git/repo — this is the visibility layer. Tools > permissions
::  sub-tab: view the weir on /tools/proc, or edit to sand a new one.
::
::  /main.sig    HTTP at /grubbery/forge
::  /requests/   per-request handlers. Page URLs:
::    /                      the workspace shell
::    /repo/<name>           a repo's workspace (?file=, ?panel=)
::  Data endpoints live under /api:
::    GET  /api/list /api/detail?repo= /api/tools?repo= /api/src
::    POST /api/add /api/delete /api/action /api/run /api/cull /api/src
::  /repos/      the repo instances
::
/<  nex-tools  /lib/nex/tools.hoon
/&  icon        forge/icon.svg
/&  forge-html  forge/index.html
/&  forge-js    forge/app.js
/&  forge-css   forge/style.css
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Forge'
            info+s+'git repos & tools'
            color+s+'#3d3a45'
            image+s+'/grubbery/tiles/icon/forge.git_forge'
            href+s+'/grubbery/forge'
        ==
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
              [%api %action ~]  (do-action rail eyre-id jon)
              [%api %run ~]     (do-run rail eyre-id jon)
              [%api %cull ~]    (do-cull rail eyre-id jon)
              [%api %weir ~]    (do-weir rail eyre-id jon)
          ==
        ?:  ?=([%api %list ~] suffix)
          ;<  lst=json  bind:m  (gather-repos rail)
          (send-json rail eyre-id lst)
        ?:  ?=([%api %detail ~] suffix)
          =/  repo=(unit @t)  (quay-get args 'repo')
          ?~  repo  (respond rail eyre-id 400 'repo required')
          ;<  det=json  bind:m  (gather-detail rail u.repo)
          (send-json rail eyre-id det)
        ?:  ?=([%api %tools ~] suffix)
          =/  repo=(unit @t)  (quay-get args 'repo')
          ?~  repo  (respond rail eyre-id 400 'repo required')
          ;<  tls=json  bind:m  (gather-tools rail u.repo)
          (send-json rail eyre-id tls)
        ?:  ?=([%api %src ~] suffix)
          =/  repo=(unit @t)  (quay-get args 'repo')
          =/  file=(unit @t)  (quay-get args 'file')
          ?:  |(?=(~ repo) ?=(~ file))
            (respond rail eyre-id 400 'repo and file required')
          =/  root=path  (src-root (fall (quay-get args 'root') 'tools'))
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
::  +src-root: which subtree of a repo instance a src request targets
::
++  src-root
  |=  root=@t
  ^-  path
  ?:(=('tree' root) /data/tree /tools/code)
::  +parse-src-path: a client file path like "lib/commit-all.hoon"
::  as [dir name], rejecting anything that could walk out of the
::  tools/code subtree
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
  %-  pure:m
  %-  pairs:enjs:format
  :~  ['status' (fall status ~)]
      ['commits' (fall commits ~)]
      ['branches' (fall branches ~)]
      ['current' (fall cur ~)]
  ==
::  +gather-tools: available tool definitions from the repo's
::  /tools/code, and installed procs from /tools/proc with their
::  live step and result
::
::  +weir-to-json: a weir -> {make,poke,peek: [path strings]}, for the UI.
::
++  weir-to-json
  |=  =weir:tarball
  ^-  json
  =/  cat
    |=  rs=(set road:tarball)
    ^-  json
    a+(turn ~(tap in rs) |=(r=road:tarball s+(road-to-cord:tarball r)))
  %-  pairs:enjs:format
  :~  ['make' (cat make.weir)]
      ['poke' (cat poke.weir)]
      ['peek' (cat peek.weir)]
  ==
::
++  gather-tools
  |=  [=rail:tarball repo=@t]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  kid=@ta  `@ta`repo
  ;<  lv=view:nexus  bind:m
    (peek:io (nex-road:io rail [%| /repos/[kid]/tools/code/lib/tools]) ~)
  =/  names=(list @ta)
    ?.  ?=([%ball *] lv)  ~
    ?~  fil.ball.lv  ~
    %+  murn  ~(tap by contents.u.fil.ball.lv)
    |=  [n=@ta *]
    =/  t=tape  (trip n)
    ?.  =(".hoon" (slag (sub (lent t) 5) t))  ~
    `(crip (scag (sub (lent t) 5) t))
  ;<  cv=view:nexus  bind:m
    (peek:io (nex-road:io rail [%| /repos/[kid]/tools/code]) ~)
  =/  files=(list path)
    ?.  ?=([%ball *] cv)  ~
    (walk-files ball.cv /)
  ;<  tv=view:nexus  bind:m
    (peek:io (nex-road:io rail [%| /repos/[kid]/data/tree]) ~)
  =/  tree=(list path)
    ?.  ?=([%ball *] tv)  ~
    (walk-files ball.tv /)
  =|  defs=(list json)
  |-
  ?~  names
    ;<  procs=json  bind:m  (gather-procs rail kid)
    ::  requested weir: the repo's tree tools/weir.json — the roads its
    ::  tools ask for. Shown in the UI as "requested"; the user grants.
    ;<  wv=view:nexus  bind:m
      (peek:io (nex-road:io rail [%& /repos/[kid]/data/tree/tools %'weir.json']) ~)
    =/  requested=json
      ?.  ?=([%file *] wv)  ~
      ?:  (is-boom:tarball sang.wv)  ~
      =/  mim=(unit mime)  (mole |.(!<(mime (need-vase:tarball sang.wv))))
      ?~  mim  ~
      (fall (de:json:html q.q.u.mim) ~)
    ::  active weir: what's enforced on /tools/proc RIGHT NOW (its weir
    ::  lives in the parent /tools dir entry — deep-peek and read it).
    ;<  av=view:nexus  bind:m
      (peek:io (nex-road:io rail [%| /repos/[kid]/tools]) ~)
    =/  active=json
      ?.  ?=([%ball *] av)  ~
      =/  pc=(unit ball:tarball)  (~(get by dir.ball.av) %proc)
      ?~  pc  ~
      ?~  fil.u.pc  ~
      =/  w=(unit weir:tarball)  weir.u.fil.u.pc
      ?~(w ~ (weir-to-json u.w))
    %-  pure:m
    %-  pairs:enjs:format
    :~  ['tools' a+(flop defs)]
        ['procs' procs]
        ['files' a+(turn files |=(p=path s+(crip (slag 1 (spud p)))))]
        ['tree' a+(turn tree |=(p=path s+(crip (slag 1 (spud p)))))]
        ['weir-requested' requested]
        ['weir-active' active]
    ==
  ;<  res=built:nexus  bind:m
    (get-code-full:io (nex-road:io rail [%& /repos/[kid]/tools/code/lib/tools i.names]))
  =/  err=(unit @t)
    ?-  -.res
      %vase  ~
      %tang  `(render-tang:build tang.res)
      %mime  `'not hoon: built as mime'
    ==
  =/  tul=(unit tool:nex-tools)
    ?^  err  ~
    ?.  ?=(%vase -.res)  ~
    =/  got=(each tool:nex-tools tang)
      (mule |.(!<(tool:nex-tools vase.res)))
    ?:(?=(%| -.got) ~ `p.got)
  ?~  tul
    =/  bad=json
      %-  pairs:enjs:format
      :~  ['file' s+i.names]
          ['error' s+(fall err 'compiles, but is not a tool core')]
      ==
    $(names t.names, defs [bad defs])
  =/  params=json
    %-  pairs:enjs:format
    %+  turn  ~(tap by parameters:u.tul)
    |=  [k=@t d=parameter-def:nex-tools]
    :-  k
    (pairs:enjs:format ~[['type' s+`@t`type.d] ['description' s+description.d]])
  =/  def=json
    %-  pairs:enjs:format
    :~  ['file' s+i.names]
        ['name' s+name:u.tul]
        ['description' s+description:u.tul]
        ['parameters' params]
        ['required' a+(turn required:u.tul |=(r=@t s+r))]
    ==
  $(names t.names, defs [def defs])
::
++  gather-procs
  |=  [=rail:tarball kid=@ta]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  pv=view:nexus  bind:m
    (peek:io (nex-road:io rail [%| /repos/[kid]/tools/proc]) ~)
  ?.  ?=([%ball *] pv)  (pure:m a+~)
  ?~  fil.ball.pv  (pure:m a+~)
  %-  pure:m
  :-  %a
  %+  murn  ~(tap by contents.u.fil.ball.pv)
  |=  [n=@ta =sang:tarball gain=? bang=(unit tang)]
  ^-  (unit json)
  =/  st=(unit tool-state:nex-tools)
    ?:  (is-boom:tarball sang)  ~
    =/  got  (mule |.(!<(tool-state:nex-tools (need-vase:tarball sang))))
    ?:(?=(%| -.got) ~ `p.got)
  ?~  st
    `(pairs:enjs:format ~[['name' s+n] ['error' s+'unreadable state']])
  :-  ~
  %-  pairs:enjs:format
  :~  ['name' s+n]
      ['tool' s+tool.u.st]
      ['step' s+`@t`step.u.st]
      ['args' o+args.u.st]
      ['result' ?~(update.u.st ~ u.update.u.st)]
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
  ::  seed the tool support types so /lib/tools.hoon imports work
  ::  from the first tool written
  ;<  lib-view=view:nexus  bind:m
    (peek:io [%& %& /code/lib/nex %'tools.hoon'] ~)
  ;<  ~  bind:m
    ?.  ?=([%file *] lib-view)  (pure:(fiber:fiber:nexus ,~) ~)
    =/  lib-road=road:tarball
      (nex-road:io rail [%& /repos/[dir-name]/tools/code/lib %'tools.hoon'])
    ;<  ~  bind:(fiber:fiber:nexus ,~)
      %+  make:io  lib-road
      |+[[p.sang.lib-view (sang-noun:tarball sang.lib-view)] ~]
    (gain:io lib-road %.y)
  =/  config=json
    %-  pairs:enjs:format
    :~  ['repo' s+(jstr jon 'repo')]
        ['ref' s+?:(=('' (jstr jon 'ref')) 'main' (jstr jon 'ref'))]
        ['token' s+(jstr jon 'token')]
    ==
  ;<  ~  bind:m
    (over:io (nex-road:io rail [%& /repos/[dir-name] %'config.json']) [[/ %json] config])
  ?:  =('' (jstr jon 'repo'))
    (respond rail eyre-id 200 'created')
  ;<  ~  bind:m
    (poke:io (nex-road:io rail [%& /repos/[dir-name]/actions %'sync.sig']) [[/ %sig] ~])
  (respond rail eyre-id 200 'created')
::  +do-src: write a tool source file — the in-browser editor's save.
::  Writing into /tools/code is deploying: the code nexus rebuilds
::  and any procs necked to the file respin on the new source.
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
    ::  tools sources are hoon; tree files keep whatever blot the
    ::  checkout gave them (over-as tubes the text through it)
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
    ?:  =(/tools/code root)
      [[/ %hoon] p.u.text]
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
  =/  pol=(unit json)  ?.(?=(%o -.jon) ~ (~(get by p.jon) 'poll'))
  =?  om  ?=([~ %n *] pol)  (~(put by om) 'poll' u.pol)
  ;<  ~  bind:m  (over:io cfg-road [[/ %json] `json`[%o om]])
  (respond rail eyre-id 200 'saved')
::  +refresh-status: after a working-tree write, reload the repo's
::  data nexus so its derived ui (status especially) reflects the
::  edit. The reload is safe for the tree — checkout never clobbers
::  a live working tree — and a no-op for tools writes.
::
++  refresh-status
  |=  [=rail:tarball repo=@t root=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  =(/data/tree root)  (pure:m ~)
  (reload:io (nex-road:io rail [%| /repos/[`@ta`repo]/data]))
::  +do-src-del: delete a source file from the tools code tree
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
++  do-action
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  repo=@t  (jstr jon 'repo')
  =/  act=@t   (jstr jon 'action')
  ?:  |(=('' repo) =('' act))
    (respond rail eyre-id 400 'repo and action required')
  =/  kid=@ta  `@ta`repo
  =/  sig-file=@ta  (cat 3 act '.sig')
  =/  act-road=road:tarball
    (nex-road:io rail [%& /repos/[kid]/actions sig-file])
  ;<  has=?  bind:m  (peek-exists:io act-road)
  ?.  has  (respond rail eyre-id 404 'no such action')
  ?:  ?=(^ (find ~[act] ~['sync' 'push' 'stash' 'stash-pop']))
    ;<  ~  bind:m  (poke:io act-road [[/ %sig] ~])
    (respond rail eyre-id 200 'ok')
  ?:  =('add' act)
    =/  payload=json
      =/  p  ?.(?=(%o -.jon) ~ (~(get by p.jon) 'payload'))
      ?^(p u.p (pairs:enjs:format ~[['all' b+%.y]]))
    ;<  ~  bind:m  (poke:io act-road [[/ %json] payload])
    (respond rail eyre-id 200 'ok')
  =/  text=@t  (jstr jon 'text')
  ?:  =('' text)  (respond rail eyre-id 400 'text required')
  ;<  ~  bind:m  (poke:io act-road [[/ %txt] (to-wain:format text)])
  (respond rail eyre-id 200 'ok')
::
::  +do-weir: set the sandbox on a repo's tools. Pokes the repo's
::  tools/weir.sig with {make,poke,peek} road-string lists; the repo
::  nexus sands its own /tools/proc.
::
++  do-weir
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  repo=@t  (jstr jon 'repo')
  ?:  =('' repo)  (respond rail eyre-id 400 'repo required')
  =/  weir=(unit json)  ?.(?=(%o -.jon) ~ (~(get by p.jon) 'weir'))
  ?~  weir  (respond rail eyre-id 400 'weir required')
  ;<  ~  bind:m
    %+  poke:io  (nex-road:io rail [%& /repos/[`@ta`repo]/tools %'weir.sig'])
    [[/ %json] u.weir]
  (respond rail eyre-id 200 'ok')
::
++  do-run
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  repo=@t  (jstr jon 'repo')
  ?:  =('' repo)  (respond rail eyre-id 400 'repo required')
  ?:  |(=('' (jstr jon 'name')) =('' (jstr jon 'tool')))
    (respond rail eyre-id 400 'name and tool required')
  ;<  ~  bind:m
    %+  poke:io
      (nex-road:io rail [%& /repos/[`@ta`repo]/tools %'run.sig'])
    [[/ %json] jon]
  (respond rail eyre-id 200 'ok')
::
++  do-cull
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  repo=@t  (jstr jon 'repo')
  =/  proc=@t  (jstr jon 'proc')
  ?:  |(=('' repo) =('' proc))
    (respond rail eyre-id 400 'repo and proc required')
  ;<  err=(unit tang)  bind:m
    (cull-soft:io (nex-road:io rail [%& /repos/[`@ta`repo]/tools/proc `@ta`proc]))
  ?^  err  (respond rail eyre-id 500 'cull failed')
  (respond rail eyre-id 200 'ok')
--
