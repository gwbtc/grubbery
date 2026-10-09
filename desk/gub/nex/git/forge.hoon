::  git/forge: the single UI over git repo instances. Repos live under
::  (respin: single expand/collapse-all toggle, label = pending action)
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
/<  dc  /lib/doc-coverage.hoon
::  git-repo/git-transport/load-repo: load a repo's store from its /data and
::  read a file's slice at a pinned commit, to compute live-block freshness.
/<  git-repo  /lib/git/repository.hoon
/<  git-transport  /lib/git/transport.hoon
/<  load-repo  /lib/git/load-repo.hoon
/&  icon        forge/icon.svg
/&  forge-html  forge/index.html
/&  forge-js    forge/app.js
/&  forge-reader-html  forge/docs-reader.html
/&  forge-reader-js  forge/docs-reader.js
/&  forge-css   forge/style.css
/&  todo        /lib/todo.md
::  the self-hosting development flow, materialized like TODO.md
/&  ratchet-md  forge/ratchet.md
::  web-component kit: shared sources in /lib/ui (one copy for all nexuses),
::  welded into one components.js bundle in on-load so a page makes a single
::  request (no staggered per-file "flash-in").
/&  modal-js    /lib/ui/modal-dialog.js
/&  dropmenu-js  /lib/ui/drop-menu.js
/&  splitview-js  /lib/ui/split-view.js
/&  tabgroup-js  /lib/ui/tab-group.js
/&  treeview-js  /lib/ui/tree-view.js
/&  filetable-js  /lib/ui/file-table.js
::  the floating window the docs reader's handbook chat lives in; the
::  manager publishes window.floatwm and MUST precede float-window
/&  windowmgr-js  /lib/ui/window-manager.js
/&  floatwin-js   /lib/ui/float-window.js
::  shared classic helpers — the FileView editor (and the FilePreview renderer
::  it leans on) reused from the explorer, loaded before app.js
/&  fp-js       /lib/ui/file-preview.js
/&  fv-js       /lib/ui/file-view.js
::  marked: renders markdown previews (window.marked), loaded before app.js
/&  marked-js   forge/marked.min.js
/<  nex-tools   /lib/tools.hoon
/&  forge-tools  forge/tool-bundle/
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
        (as-octs:mimes:html (rap 3 ~[(wrap modal-js) (wrap dropmenu-js) (wrap splitview-js) (wrap tabgroup-js) (wrap treeview-js) (wrap filetable-js) (wrap windowmgr-js) (wrap floatwin-js)]))
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%fall %| /repos empty-dir:loader]
          ::  forge-level defaults: identity + account stamped into each new
          ::  repo on create (per-repo config still overrides). Forge's own
          ::  config — the one thing not scoped to a selected repo.
          [%fall %& [/ %'defaults.json'] [[/ %json] (pairs:enjs:format ~[['author_name' s+''] ['author_email' s+''] ['account' s+'']])]]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'forge'] ['description' s+'git repos: the UI over repo instances']])]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'index.html'] [[/ %mime] forge-html]]
          [%over %& [/ %'app.js'] [[/ %mime] forge-js]]
          [%over %& [/ %'docs-reader.html'] [[/ %mime] forge-reader-html]]
          [%over %& [/ %'docs-reader.js'] [[/ %mime] forge-reader-js]]
          ::  the nexus backlog, materialized like README — browsable at root
          [%over %& [/ %'TODO.md'] [[/ %mime] todo]]
          ::  the ratchet: how grubbery develops itself from in-ship
          [%over %& [/ %'RATCHET.md'] [[/ %mime] ratchet-md]]
          [%over %& [/ %'style.css'] [[/ %mime] forge-css]]
          [%over %& [/ %'components.js'] [[/ %mime] kit-js]]
          [%over %& [/ %'file-preview.js'] [[/ %mime] fp-js]]
          [%over %& [/ %'file-view.js'] [[/ %mime] fv-js]]
          [%over %& [/ %'marked.min.js'] [[/ %mime] marked-js]]
          [%over %| /tools (seed-tools:nex-tools forge-tools)]
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
              [%api %defaults ~]  (do-defaults rail eyre-id jon)
              [%api %run ~]     (do-run rail eyre-id jon)
          ==
        ?:  ?=([%api %defaults ~] suffix)
          ;<  cur=(unit json)  bind:m
            (peek-as:io (nex-road:io rail [%& / %'defaults.json']) ,json)
          (send-json rail eyre-id (fall cur ~))
        ?:  ?=([%api %stock ~] suffix)
          (send-json rail eyre-id stock-repos)
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
        ::  per-repo handbook, path-segment style: /repo/<name>/docs is the
        ::  reader page; /repo/<name>/docs/<endpoint> are its data routes:
        ::  nav.json + coverage.json (read from the data nexus's precomputed
        ::  ui/ grubs), page (markdown + its resolved live blocks in one json),
        ::  and slice (the exact lines of a file at a pinned commit).
        ?:  ?=([%repo @ %docs *] suffix)
          ::  the url carries the SHORT repo name (as the workspace does); the
          ::  docs arms key by the full instance dir <name>.git_repo
          =/  seg=tape  (trip i.t.suffix)
          =/  repo=@ta
            ?:  =(".git_repo" (slag ?:((gth (lent seg) 9) (sub (lent seg) 9) 0) seg))
              i.t.suffix
            (cat 3 i.t.suffix '.git_repo')
          ?+    t.t.t.suffix
            (respond rail eyre-id 404 'not found')
              ~
            ;<  fv=view:nexus  bind:m
              (peek:io (nex-road:io rail [%& / %'docs-reader.html']) `[/ %mime])
            ?.  ?=([%file *] fv)  (respond rail eyre-id 404 'reader missing')
            ;<  ~  bind:m  (send-simple:s eyre-id (mime-response:http-utils !<(mime (need-vase:tarball sang.fv))))
            (pure:m ~)
            ::  nav + coverage are read from the data nexus's precomputed ui/
            ::  grubs (the git trick) — no per-request fold or source reads.
              [%'nav.json' ~]
            ;<  nav=(unit json)  bind:m
              (peek-as:io (nex-road:io rail [%& /repos/[repo]/data/ui %'docs-nav.json']) ,json)
            ?~  nav  (send-json rail eyre-id [%a ~])
            (send-json rail eyre-id (annotate-nav:dc u.nav))
              [%'coverage.json' ~]
            =/  sec=@t  (fall (quay-get args 'section') '')
            ;<  nav=(unit json)  bind:m
              (peek-as:io (nex-road:io rail [%& /repos/[repo]/data/ui %'docs-nav.json']) ,json)
            ;<  cs=(unit cov-state:dc)  bind:m
              (peek-as:io (nex-road:io rail [%& /repos/[repo]/data/ui %'docs-covstate']) ,cov-state:dc)
            ?:  |(?=(~ nav) ?=(~ cs))  (send-json rail eyre-id ~)
            ::  the view is OF HEAD: name the commit it was measured against,
            ::  so the reader can stamp every file with it (a pinned block's
            ::  lines are at its pin; the file view is at this commit)
            ;<  cur=(unit json)  bind:m
              (peek-as:io (nex-road:io rail [%& /repos/[repo]/data/ui %'current.json']) ,json)
            =/  head=@t
              ?~  cur  ''
              =/  h=@t  (jstr u.cur 'hash')
              (crip (scag 7 (trip h)))
            =/  out=json  (render-coverage:dc u.cs u.nav sec %.y)
            =?  out  ?=([%o *] out)  [%o (~(put by p.out) 'head' s+head)]
            (send-json rail eyre-id out)
            ::  /chat → the repo's clanker (its agent, in the clanker collection
            ::  at forge/<repo>.clanker: bundle "repo", tools that read this
            ::  checkout, a weir reaching the working tree) and the `docs` chat
            ::  on it with the handbook prompt, made if missing. Answers where
            ::  that chat's log lives, so the reader mounts clanker's own chat
            ::  pane on it. null when no clanker is installed (the panel is
            ::  then simply absent).
              [%chat ~]
            ;<  cl=(unit lane:tarball)  bind:m  (resolve-link:io '@clanker')
            ?.  ?=([~ %| *] cl)  (send-json rail eyre-id ~)
            ;<  fo=(unit lane:tarball)  bind:m  (resolve-link:io '@forge')
            ?.  ?=([~ %| *] fo)  (send-json rail eyre-id ~)
            =/  short=@t  (crip (scag (sub (lent (trip repo)) 9) (trip repo)))
            =/  inst=@t  (spat (weld p.u.fo /repos/[repo]))
            =/  tree=@t  (spat (weld p.u.fo /repos/[repo]/data/tree))
            =/  ui=@t  (spat (weld p.u.fo /repos/[repo]/data/ui))
            =/  lane=@t  (cat 3 inst '/run.git-action')
            ::  ONE clanker per repo, bundle "build": it can read the working
            ::  tree and the docs cache, write the tree, and poke the repo's git
            ::  lane. Which chat may do which is the chats' POLICY: docs is
            ::  read-only (the writing tools withheld), build asks before any
            ::  write or git command. Prompts and policies are seeds (made once).
            =/  chat
              |=  [name=@t system=@t policy=json]
              ^-  json
              (pairs:enjs:format ~[['name' s+name] ['system' s+system] ['policy' policy]])
            =/  strs  |=(l=(list @t) ^-(json a+(turn l |=(s=@t `json`s+s))))
            =/  ensure=json
              %-  pairs:enjs:format
              :~  ['action' s+'ensure']
                  ['parent' s+'/forge']
                  ['name' s+short]
                  ['bundle' s+'build']
                  ['system' s+(repo-clanker-prompt short tree)]
                  ['repo' s+tree]
                  ['config' (pairs:enjs:format ~[['ui' s+ui]])]
                  :-  'roads'
                  %-  pairs:enjs:format
                  :~  ['peek' (strs ~[(cat 3 tree '/') (cat 3 ui '/') lane])]
                      ['make' (strs ~[(cat 3 tree '/')])]
                      ['poke' (strs ~[lane])]
                  ==
                  :-  'chats'
                  :-  %a
                  :~  %^  chat  'docs'  docs-chat-prompt
                      %-  pairs:enjs:format
                      :~  ['default' s+'allow']
                          ['deny' (strs ~['repo_write' 'repo_edit' 'repo_git' 'write_file' 'delete_file'])]
                      ==
                      %^  chat  'build'  build-chat-prompt
                      %-  pairs:enjs:format
                      :~  ['default' s+'allow']
                          ['ask' (strs ~['repo_write' 'repo_edit' 'repo_git' 'write_file' 'delete_file'])]
                      ==
                  ==
              ==
            ::  Robust to the clanker app being absent, stale, or old: no link
            ::  → null above; a link whose nexus is gone or predates main.sig
            ::  → the peek finds no file → null; a poke that never packs →
            ::  the deadline → null. Forge never waits on the clanker app.
            =/  sig=road:tarball  [%& %& p.u.cl %'main.sig']
            ;<  sv=(unit view:nexus)  bind:m  (peek-soft:io sig ~)
            ?.  ?=([~ %file *] sv)  (send-json rail eyre-id ~)
            ;<  res=(unit (unit tang))  bind:m
              %^  (with-timeout:io ,(unit tang))  /clanker-ensure  ~s15
              (poke-soft:io sig [/ %json] ensure)
            ?.  ?=([~ ~] res)  (send-json rail eyre-id ~)
            %^  send-json  rail  eyre-id
            %-  pairs:enjs:format
            :~  ['proj' s+(crip "/forge/{(trip short)}.clanker")]
                ['chat' s+'docs']
                ['url' s+(crip "/grubbery/ball{(spud p.u.cl)}/projects/forge/{(trip short)}.clanker/chats/docs/log.chat-log")]
                ['viewer' s+'/grubbery/clanker/viewer.js']
            ==
            ::  /search?q= → full-text search over this repo's handbook pages,
            ::  the shell docs' search bar: the ship greps the checkout's
            ::  .grubbery/docs pages, answers hits as {path, title, snippet};
            ::  the browser never loads the corpus, only what it clicks.
              [%search ~]
            =/  q=@t  (fall (quay-get args 'q') '')
            =/  qlow=tape  (cass (trip q))
            ?:  =(~ qlow)  (send-json rail eyre-id [%a ~])
            ;<  nav=(unit json)  bind:m
              (peek-as:io (nex-road:io rail [%& /repos/[repo]/data/ui %'docs-nav.json']) ,json)
            =/  items=(list [path=@t title=@t])  ?~(nav ~ (nav-items:dc u.nav))
            =|  hits=(list json)
            |-  ^-  form:m
            ?~  items  (send-json rail eyre-id [%a (flop hits)])
            ;<  txt=@t  bind:m  (docs-page rail repo `path`~[%'.grubbery' %docs] path.i.items)
            =/  snip=(unit @t)  (docs-find-snippet txt q)
            =/  tmatch=?  !=(~ (find qlow (cass (trip title.i.items))))
            =?  hits  |(?=(^ snip) tmatch)
              =/  s=@t  ?~(snip title.i.items u.snip)
              [(docs-hit path.i.items title.i.items s) hits]
            $(items t.items)
            ::  a handbook page as {markdown, blocks}: the raw .md from the
            ::  checkout at .grubbery/docs/<page>, plus its live blocks already
            ::  resolved (lines at the pinned commit, short commit, status) from
            ::  the data nexus's cached docs-blocks.json — so the browser renders
            ::  the page in ONE fetch, with no per-block store load.
              [%page ~]
            =/  page=@t  (fall (quay-get args 'path') '')
            ;<  txt=@t  bind:m  (docs-page rail repo `path`~[%'.grubbery' %docs] page)
            ;<  bl=(unit json)  bind:m
              (peek-as:io (nex-road:io rail [%& /repos/[repo]/data/ui %'docs-blocks.json']) ,json)
            =/  blocks=json
              ?.  ?=([~ %o *] bl)  [%a ~]
              (fall (~(get by p.u.bl) page) [%a ~])
            (send-json rail eyre-id (pairs:enjs:format ~[['markdown' s+txt] ['blocks' blocks]]))
            ::  render FROM THE PINNED COMMIT: the exact [from..to] lines of a
            ::  live block's file as of its `commit`, read from the git object
            ::  store via +blob-at-commit — the browser displays what the ship
            ::  returns, no client slicing. `file` is the file's real repo path,
            ::  so there is no alias. No `commit` = at HEAD (the heatmap's view).
              [%slice ~]
            =/  file=@t  (fall (quay-get args 'file') '')
            =/  commit=(unit @t)  (quay-get args 'commit')
            =/  from=@ud  (fall (biff (quay-get args 'from') |=(a=@t (rush a dem))) 1)
            =/  to=@ud    (fall (biff (quay-get args 'to') |=(a=@t (rush a dem))) 0)
            ;<  eff=(unit @t)  bind:m  (resolve-commit rail repo commit)
            ;<  store=(unit repository:git-repo)  bind:m
              (load-repo-from-ns:load-repo rail /repos/[repo]/data)
            =/  span=(unit (list @t))  (pin-span-at store eff file from to)
            =/  txt=@t  ?~(span '' (of-wain:format u.span))
            ;<  ~  bind:m  (send-simple:s eyre-id (mime-response:http-utils [/text/plain (as-octs:mimes:html txt)]))
            (pure:m ~)
          ==
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
::  +stock-repos: the house catalog — one-click clones surfaced on the
::  landing page. Names here become <name>.git_repo instances; do-add
::  handles the rest exactly as if typed into the create form.
++  stock-repos
  ^-  json
  =/  entry
    |=  [name=@t repo=@t desc=@t]
    ^-  json
    %-  pairs:enjs:format
    :~  ['name' s+name]  ['repo' s+repo]  ['ref' s+'main']  ['desc' s+desc]
    ==
  :-  %a
  :~  (entry 'grubbery' 'gwbtc/grubbery' 'grubbery itself — kernel + desk. The self-hosting ratchet: see RATCHET.md')
      (entry 'hatchery' 'gwbtc/hatchery' 'experimental apps migrated out of the kernel, followed as a desk')
  ==
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
::  as [dir name], rejecting anything that could walk out of the tree.
::  Splits on "/" allowing any printable non-slash char per segment —
::  NOT `stap`, whose @ta segments are lowercase-only and so reject
::  uppercase names like README.md / LICENSE.txt (grub names carry case
::  fine; only the parser choked).
::
++  parse-src-path
  |=  file=@t
  ^-  (unit [dir=path name=@ta])
  =/  t=tape  (trip file)
  =.  t  ?:(&(?=(^ t) =('/' i.t)) t.t t)
  =/  segs=(unit (list tape))
    (rush (crip t) (more fas (plus ;~(less fas prn))))
  ?~  segs  ~
  =/  pax=path  (turn u.segs |=(s=tape `@ta`(crip s)))
  ?.  %+  levy  pax
      |=(seg=@ta !|(=('' seg) =('.' seg) =('..' seg)))
    ~
  =/  flopped=path  (flop pax)
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
::  ---- handbook: pages + pinned slices (coverage is computed in the data
::  nexus on-load; see +build-docs-coverage there — forge only reads ui/) ----
::  +resolve-commit: the commit a /slice renders at — the pinned `commit` when
::  present, else the repo's current HEAD (from its data nexus's current.json).
::  A pinned block names its commit; the coverage heatmap passes none and gets
::  HEAD, where coverage is measured.
++  resolve-commit
  |=  [=rail:tarball repo=@ta commit=(unit @t)]
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ?^  commit  (pure:m commit)
  ;<  cur=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /repos/[repo]/data/ui %'current.json']) ,json)
  ?~  cur  (pure:m ~)
  ?.  ?=([%o *] u.cur)  (pure:m ~)
  =/  h  (~(get by p.u.cur) 'hash')
  (pure:m ?.(?=([~ %s *] h) ~ `p.u.h))
::  +pin-span-at: the EXACT lines [from..to] of `file` AS OF `commit`, read from
::  the git object store via +blob-at-commit — the render-from-pin primitive the
::  /slice endpoint serves. `file` is the file's real repo path ("/desk/..."),
::  so it maps straight to a tree path with no alias. ~ when the anchor floats
::  (no commit), the store is missing, the commit/path is absent there, or the
::  range falls outside the file.
++  pin-span-at
  |=  $:  store=(unit repository:git-repo)  commit=(unit @t)
          file=@t  from=@ud  to=@ud
      ==
  ^-  (unit (list @t))
  ?~  commit  ~
  ?~  store   ~
  =/  ch=(unit @ux)  (rust (trip u.commit) parse-hash-sha-1:git-transport)
  ?~  ch  ~
  =/  blob=(unit octs)  (blob-at-commit:~(. git-repo u.store) u.ch (stab file))
  ?~  blob  ~
  =/  lines=(list @t)  (to-wain:format q.u.blob)
  =/  total=@ud  (lent lines)
  ?:  =(0 total)  ~
  =/  hi=@ud  (min total ?:(=(0 to) total to))
  ?:  (gth from hi)  ~
  `(swag [(dec from) +((sub hi from))] lines)
::  +docs-page: a handbook page's raw markdown, read from the checkout.
::  the repo clanker's standing prompt, and the docs chat's own. The
::  clanker is one identity per repo; a chat is one role of it.
++  repo-clanker-prompt
  |=  [short=@t tree=@t]
  ^-  @t
  %-  crip
  """
  You are the agent for the git repository "{(trip short)}", kept in this
  ship's forge. Its working tree (the checkout of the current branch) is
  at {(trip tree)}. Your repo tools: repo_list to see a directory,
  repo_read to read a file, repo_grep to search, docs_page to read a
  handbook page as rendered; repo_write and repo_edit change files in the
  working tree; repo_git runs one git command through the forge (add,
  commit, push, pull, status, checkout). Paths are relative to the repo
  root, like "lib/foo.hoon". Read before you answer or change anything;
  name the files and lines you relied on. Which tools a chat may use, and
  which ask the user first, is that chat's policy. Your own directory
  (memories, skills) is yours to keep notes in.
  """
++  build-chat-prompt
  ^-  @t
  '''
  This chat changes the repository. Work in small, verified steps: read
  the code you are about to change, make the change with repo_edit (or
  repo_write for a new file), then stage and commit with repo_git ("add",
  then "commit -m <message>"), and push only when asked. Every write and
  every git command asks the user first; explain what you are about to do
  and why in the message before the tool call, so the user can decide.
  Commit messages say what changed and why, in plain prose. Never commit
  secrets, local paths or personal details.
  '''
++  docs-chat-prompt
  ^-  @t
  '''
  This chat is about the repository's handbook, the pages under
  .grubbery/docs (docs.json is its table of contents: nav, with each
  page's path). Read pages with docs_page, which shows them as a reader
  sees them: each live code block expanded to the lines it cites at
  their pinned commit, marked fresh, drifted or gone against HEAD. Say
  when a block you relied on has drifted. Answer from those pages and
  the code they cite; say which page, and say plainly when the handbook
  does not cover something rather than guessing. Prefer short answers
  with a pointer over long ones.
  '''
::  +docs-find-snippet: the first line of a page containing the query,
::  case-insensitive, clipped — the search result's one line of context
++  docs-find-snippet
  |=  [text=@t q=@t]
  ^-  (unit @t)
  =/  ql=tape  (cass (trip q))
  =/  lines=(list @t)  (to-wain:format text)
  |-  ^-  (unit @t)
  ?~  lines  ~
  ?.  =(~ (find ql (cass (trip i.lines))))
    `(crip (scag 200 (trip i.lines)))
  $(lines t.lines)
::  +docs-hit: one search result as the reader expects it
++  docs-hit
  |=  [p=@t t=@t snip=@t]
  ^-  json
  (pairs:enjs:format ~[['path' s+p] ['title' s+t] ['snippet' s+snip]])
++  docs-page
  |=  [=rail:tarball repo=@ta prose=path page=@t]
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  =/  pax=(unit [dir=path name=@ta])  (parse-src-path page)
  ?~  pax  (pure:m '')
  =/  fdir=path  :(weld /repos/[repo]/data/tree prose dir.u.pax)
  ;<  fv=view:nexus  bind:m  (peek:io (nex-road:io rail [%& fdir name.u.pax]) ~)
  (pure:m ?.(?=([%file *] fv) '' (sang-text:dc sang.fv)))
::  +gather-repos: every instance under /repos as a card — config plus
::  the current.json its data nexus maintains
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
  ;<  stash=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /repos/[kid]/data/ui %'stash.json']) ,json)
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
      ['stash' (fall stash a+~)]
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
  ::  stamp forge-level defaults (identity + account) into the new repo;
  ::  the create form's account wins if supplied, else the default.
  ;<  defs=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& / %'defaults.json']) ,json)
  =/  dget
    |=  key=@t  ^-  @t
    ?.  ?=([~ %o *] defs)  ''
    =/  v  (~(get by p.u.defs) key)
    ?.(?=([~ %s *] v) '' p.u.v)
  =/  form-account=@t  (jstr jon 'account')
  =/  config=json
    %-  pairs:enjs:format
    :~  ['repo' s+(jstr jon 'repo')]
        ['ref' s+?:(=('' (jstr jon 'ref')) 'main' (jstr jon 'ref'))]
        ['account' s+?:(=('' form-account) (dget 'account') form-account)]
        ['author_name' s+(dget 'author_name')]
        ['author_email' s+(dget 'author_email')]
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
::  +do-config: merge repo/ref/account/author fields into a repo's config.
::  Empty strings leave the existing value alone, so the form can send only
::  what changed. Auth lives in the github proxy, keyed by account.
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
::  +do-defaults: save forge-level defaults (identity + account) stamped
::  into new repos on create. The editor form echoes all fields, so a full
::  overwrite is correct — empty means empty.
::
++  do-defaults
  |=  [=rail:tarball eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  new=json
    %-  pairs:enjs:format
    :~  ['author_name' s+(jstr jon 'author_name')]
        ['author_email' s+(jstr jon 'author_email')]
        ['account' s+(jstr jon 'account')]
    ==
  ;<  ~  bind:m
    (over:io (nex-road:io rail [%& / %'defaults.json']) [[/ %json] new])
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
