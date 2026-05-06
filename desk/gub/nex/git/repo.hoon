::  git/repo nexus: clone a public repo via git smart HTTP
::
::  Config: /config.json with fields:
::    repo:   owner/repo (e.g. "urbit/urbit")
::    ref:    branch, tag, or commit sha (e.g. "main")
::
::  Git data lives in the /data sub-nexus. On clone, we write
::  pack + index + refs + HEAD into /data, then reload it.
::  The data nexus's on-load atomically checks out the tree.
::
::  Poke sync.sig to trigger a re-fetch.
::  Poke checkout.sig with a commit hash to checkout.
::
/<  git-bundle  /lib/git/bundle.hoon
/<  git-pack  /lib/git/pack.hoon
/<  git-repo  /lib/git/repository.hoon
/<  git-transport  /lib/git/transport.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      =/  default-config=json
        %-  pairs:enjs:format
        :~  ['repo' s+'']
            ['ref' s+'']
            ['token' s+'']
        ==
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%fall %& [/ %'config.json'] %.n [~ [/ %json] !>(default-config)]]
            [%fall %& [/ %'sync.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %& [/ %'switch.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %& [/ %'checkout.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %& [/ %'commit.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %& [/ %'import.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %& [/ %'push.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %& [/ %'push.json'] %.n [~ [/ %json] !>([%o ~])]]
            [%fall %| /ui [~ ~] [~ ~] empty-dir:loader]
            [%fall %& [/ui %'status.json'] %.n [~ [/ %json] !>((pairs:enjs:format ~[['status' s+'idle']]))]]
            [%fall %& [/ui %'commit.json'] %.n [~ [/ %json] !>([%a ~])]]
            [%over %& [/ %'page.html'] %.n [~ [/ %manx] !>((repo-page '' '' '' ~ ~ [%a ~] [%o ~]))]]
            [%fall %| /data [~ ~] [~ ~] [`[~ `[/git %data] ~] ~]]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =mark]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  /import.sig: bundle import — poke with octs to parse
          ::
          [~ %'import.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo import: failed")
        ~&  >>  "%git/repo: bundle import ready"
        |-
        ;<  poke=*  bind:m  take-poke:io
        ~&  >>  "%git/repo: import poke received"
        =/  bun=bundle:git-bundle
          (read:git-bundle (from-octs:bytestream ;;(octs poke)))
        =/  repo=repository:git-repo
          (~(clone-from-bundle git-repo *repository:git-repo) bun)
        ~&  >>  ["%git/repo: bundle parsed" count.pack.bun "objects"]
        ~&  >>  ["%git/repo: refs" (turn refs.header.bun |=([p=* q=*] p))]
        $
          ::  /page.html: watches config + repo data, re-renders
          ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo /page: failed")
        ;<  here=rail:tarball  bind:m  get-here:io
        =/  api=@t
          (crip "/grubbery/api/file{(spud path.here)}")
        ;<  init-cfg=view:nexus  bind:m
          (keep:io /cfg (cord-to-road:tarball './config.json') `%json)
        ;<  init-tree=view:nexus  bind:m
          (keep:io /tree (cord-to-road:tarball './data/tree/') ~)
        ;<  init-status=view:nexus  bind:m
          (keep:io /status (cord-to-road:tarball './ui/status.json') `%json)
        ;<  init-branches=view:nexus  bind:m
          (keep:io /branches (cord-to-road:tarball './data/branches.json') `%json)
        ;<  init-commits=view:nexus  bind:m
          (keep:io /commits (cord-to-road:tarball './data/commits.json') `%json)
        ;<  init-current=view:nexus  bind:m
          (keep:io /current (cord-to-road:tarball './data/current.json') `%json)
        =/  cfg=repo-config  (view-to-config init-cfg)
        =/  files=(list @t)  (view-to-files init-tree)
        =/  branches=(list @t)  (view-to-branches init-branches)
        =/  commits=json  (view-to-json init-commits)
        =/  current=json  (view-to-json init-current)
        ;<  ~  bind:m  (replace:io !>((repo-page api repo.cfg ref.cfg branches files commits current)))
        |-
        ;<  evt=page-event  bind:m  take-page-event
        ?-    -.evt
            %fell  $
            %news
          =?  cfg  =(/cfg wire.evt)  (view-to-config view.evt)
          =?  files  =(/tree wire.evt)  (view-to-files view.evt)
          =?  branches  =(/branches wire.evt)  (view-to-branches view.evt)
          =?  commits  =(/commits wire.evt)  (view-to-json view.evt)
          =?  current  =(/current wire.evt)  (view-to-json view.evt)
          ;<  ~  bind:m  (replace:io !>((repo-page api repo.cfg ref.cfg branches files commits current)))
          $
        ==
          ::  /checkout.sig: checkout a specific commit by hash
          ::
          [~ %'checkout.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo checkout: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  hash-text=@t  (of-wain:format !<(wain q.sage))
        ~&  >>  ["%git/repo: checkout poke" hash-text]
        ;<  ~  bind:m  (set-status 'syncing')
        ::  write new HEAD and reload repo
        ;<  ~  bind:m  (write-head hash-text)
        ;<  ~  bind:m  (reload:io (cord-to-road:tarball './data/'))
        ;<  ~  bind:m  (set-status 'idle')
        $
          ::  /switch.sig: switch branch locally (no remote fetch)
          ::
          [~ %'switch.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo switch: failed")
        |-
        ;<  *  bind:m  take-poke:io
        ;<  cfg=repo-config  bind:m  read-config
        ?:  =('' repo.cfg)  $
        ;<  has-pack=?  bind:m
          (peek-exists:io (cord-to-road:tarball './data/pack.dat'))
        ?.  has-pack
          ~&  >>>  "%git/repo: no pack cached, use sync"
          $
        ~&  >>  ["%git/repo: switching to" ref.cfg]
        ;<  ~  bind:m  (set-status 'syncing')
        =/  active-ref=@t  ?:(=('' ref.cfg) 'main' ref.cfg)
        ;<  ref-hash=@t  bind:m  (resolve-ref ref.cfg)
        ;<  ~  bind:m  (write-head ref-hash)
        ;<  ~  bind:m  (write-ref active-ref)
        ;<  ~  bind:m  (reload:io (cord-to-road:tarball './data/'))
        ;<  ~  bind:m
          (over:io (cord-to-road:tarball './config.json') [[/ %json] !>((pairs:enjs:format ~[['repo' s+repo.cfg] ['ref' s+ref.cfg] ['token' s+token.cfg]]))])
        ;<  ~  bind:m  (set-status 'idle')
        $
          ::  /commit.sig: compute diff for a commit
          ::
          [~ %'commit.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo commit: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  hash-text=@t  (of-wain:format !<(wain q.sage))
        ~&  >>  ["%git/repo: diff for" hash-text]
        =/  target-hash=(unit @ux)
          (rust (trip hash-text) parse-hash-sha-1:git-transport)
        ?~  target-hash
          ~&  >>>  "%git/repo: invalid commit hash"
          $
        ;<  repo=repository:git-repo  bind:m  load-repo-from-ns
        =/  sto  store:~(. git-repo repo)
        =/  com=(unit commit:git-repo)  (get-commit:sto u.target-hash)
        ?~  com
          ~&  >>>  "%git/repo: commit not found"
          $
        ::  get parent tree for diff (~ for first commit)
        =/  parent-tree=(unit @ux)
          ?~  parents.u.com  ~
          =/  par=(unit commit:git-repo)  (get-commit:sto i.parents.u.com)
          ?~  par  ~
          `tree.u.par
        =/  get-tree=$-(@ux (unit tree-dir:git-repo))
          |=(h=@ux (get-tree:sto h))
        =/  get-blob=$-(@ux (unit octs))
          |=(h=@ux (get-blob:sto h))
        =/  changes=(list tree-change:git-transport)
          ?~  parent-tree
            ::  first commit: all files are additions
            =/  top-tree=(unit tree-dir:git-repo)  (get-tree tree.u.com)
            ?~  top-tree  ~
            %+  turn  (all-blobs:git-transport get-tree / u.top-tree)
            |=([p=path h=@ux] `tree-change:git-transport`[%add p h])
          (diff-trees:git-transport get-tree u.parent-tree tree.u.com)
        ~&  >>  ["%git/repo: diff" (lent changes) "files changed"]
        =/  result=json
          %-  pairs:enjs:format
          :~  ['hash' s+hash-text]
              ['short' s+(crip (scag 7 (trip hash-text)))]
              ['message' s+(crip message.u.com)]
              ['author' s+(crip name.author.u.com)]
              ['files' (build-diff-json get-blob changes)]
          ==
        ;<  ~  bind:m
          (over:io (cord-to-road:tarball './ui/commit.json') [[/ %json] !>(result)])
        $
          ::  /sync.sig: clone or re-checkout
          ::
          [~ %'sync.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo sync: failed")
        ~&  >>  "%git/repo: sync fiber started, waiting for poke"
        ;<  *  bind:m  take-poke:io
        |-
        ;<  cfg=repo-config  bind:m  read-config
        ?:  =('' repo.cfg)
          ~&  >>>  "%git/repo: no repo configured"
          ;<  *  bind:m  take-poke:io
          $
        ;<  ~  bind:m  (set-status 'syncing')
        ::  always fetch from remote
        ::  full clone
        ~&  >>  "%git/repo: cloning..."
        ;<  disc=discovery:git-transport  bind:m
          (fetch-discovery repo.cfg)
        ~&  >>  ["%git/repo: found" (lent refs.disc) "refs"]
        =?  ref.cfg  =('' ref.cfg)
          (fall (default-branch:git-transport caps.disc) 'main')
        ;<  ~  bind:m
          (over:io (cord-to-road:tarball './config.json') [[/ %json] !>((pairs:enjs:format ~[['repo' s+repo.cfg] ['ref' s+ref.cfg] ['token' s+token.cfg]]))])
        ~&  >>  "%git/repo: fetching pack..."
        =/  want-hashes=(list @ux)
          (turn refs.disc |=(r=git-ref:git-transport hash.r))
        ;<  pack-body=octs  bind:m
          (fetch-pack repo.cfg (build-want:git-transport want-hashes ~['side-band-64k' 'ofs-delta'] ~))
        ~&  >>  ["%git/repo: pack received" p.pack-body "bytes"]
        =/  pack-data=octs
          (extract-pack:git-transport pack-body %.y)
        ~&  >>  "%git/repo: parsing pack..."
        =/  =pack:git-pack
          (read:git-pack (from-octs:bytestream pack-data))
        ~&  >>  ["%git/repo: unpacked" count.pack "objects"]
        =/  repo=repository:git-repo
          (~(clone-from-pack git-repo *repository:git-repo) pack refs.disc)
        ::  build index text
        ?<  ?=(~ archive.object-store.repo)
        =/  pak=pack:git-pack  i.archive.object-store.repo
        =/  all-entries=(list [key=hash:git-repo val=@ud])
          (tap:pack-on:git-pack index.pak)
        =/  idx-text=tape
          %-  zing
          %+  turn  all-entries
          |=  [key=hash:git-repo val=@ud]
          "{(print-hash-sha-1:git-transport key)} {(a-co:co val)}\0a"
        ::  build refs json
        =/  refs-json=json
          %-  pairs:enjs:format
          %+  murn  refs.disc
          |=  r=git-ref:git-transport
          ^-  (unit [@t json])
          ?.  =(`(list @t)`~['refs' 'heads'] (scag 2 refname.r))  ~
          =/  branch-name=@t
            (crip (join:git-transport '/' (turn (slag 2 refname.r) trip)))
          `[branch-name s+(crip (print-hash-sha-1:git-transport hash.r))]
        ::  resolve HEAD hash
        =/  active-ref=@t  ?:(=('' ref.cfg) 'main' ref.cfg)
        =/  ref-hash=(unit @ux)
          =+  got=(get:refs:~(. git-repo repo) ~[active-ref])
          ?^  got  got
          (get:refs:~(. git-repo repo) ~['refs' 'heads' active-ref])
        =/  head-hash=@ux  (fall ref-hash 0x0)
        =/  head-text=@t  (crip (print-hash-sha-1:git-transport head-hash))
        ~&  >>  ["%git/repo: saving to data nexus"]
        ::  write all repo data then reload
        ;<  ~  bind:m  (save-repo pack-data idx-text refs-json head-text active-ref)
        ;<  ~  bind:m  (reload:io (cord-to-road:tarball './data/'))
        ~&  >>  "%git/repo: reload triggered"
        ;<  ~  bind:m  (set-status 'idle')
        ;<  *  bind:m  take-poke:io
        $
          ::  /push.sig: push files to GitHub via REST API
          ::
          [~ %'push.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo push: failed")
        |-
        ;<  *  bind:m  take-poke:io
        ;<  cfg=repo-config  bind:m  read-config
        ?:  =('' repo.cfg)
          ~&  >>>  "%git/repo push: no repo configured"
          $
        ?:  =('' token.cfg)
          ~&  >>>  "%git/repo push: no token configured"
          $
        ::  read push.json for files + message
        =/  push-road=road:tarball  (cord-to-road:tarball './push.json')
        ;<  push-seen=seen:nexus  bind:m  (peek:io push-road `%json)
        ?.  ?=([%& %file *] push-seen)
          ~&  >>>  "%git/repo push: no push.json"
          $
        =/  push-json=json  (fall (mole |.(!<(json q.sage.p.push-seen))) *json)
        ?.  ?=(%o -.push-json)
          ~&  >>>  "%git/repo push: invalid push.json"
          $
        =/  get-str
          |=  [key=@t default=@t]
          ^-  @t
          =/  v  (~(get by p.push-json) key)
          ?.  ?=([~ %s *] v)  default
          p.u.v
        =/  message=@t  (get-str 'message' '')
        =/  author-name=@t   (get-str 'author_name' 'grubbery')
        =/  author-email=@t  (get-str 'author_email' 'grubbery@urbit.org')
        =/  files-val=(unit json)  (~(get by p.push-json) 'files')
        ?~  files-val
          ~&  >>>  "%git/repo push: no files in push.json"
          $
        ?.  ?=([~ %a *] files-val)
          ~&  >>>  "%git/repo push: files must be an array"
          $
        =/  files=(list json)  p.u.files-val
        ?~  files
          ~&  >>>  "%git/repo push: empty files array"
          $
        ?:  =('' message)
          ~&  >>>  "%git/repo push: no commit message"
          $
        ~&  >>  ["%git/repo push:" (lent files) "files"]
        ;<  ~  bind:m  (set-status 'pushing')
        ::  1. get current HEAD ref
        =/  branch=@t  ?:(=('' ref.cfg) 'main' ref.cfg)
        =/  api=@t  'https://api.github.com'
        =/  headers=(list [key=@t value=@t])  (gh-headers token.cfg)
        =/  ref-url=@t
          (cat 3 api (cat 3 '/repos/' (cat 3 repo.cfg (cat 3 '/git/refs/heads/' branch))))
        ;<  ref-resp=json  bind:m  (gh-get ref-url headers)
        ?.  ?=(%o -.ref-resp)
          ~|  "%git/repo push: unexpected ref response"  !!
        =/  head-sha=@t
          =/  obj  (~(get by p.ref-resp) 'object')
          ?.  ?=([~ %o *] obj)
            ~|  "%git/repo push: no 'object' in ref response"  !!
          =/  sha  (~(get by p.u.obj) 'sha')
          ?.  ?=([~ %s *] sha)
            ~|  "%git/repo push: no 'sha' in ref object"  !!
          p.u.sha
        ::  2. get HEAD commit to find tree SHA
        =/  commit-url=@t
          (cat 3 api (cat 3 '/repos/' (cat 3 repo.cfg (cat 3 '/git/commits/' head-sha))))
        ;<  commit-resp=json  bind:m  (gh-get commit-url headers)
        ?.  ?=(%o -.commit-resp)
          ~|  "%git/repo push: unexpected commit response"  !!
        =/  base-tree-sha=@t
          =/  tree  (~(get by p.commit-resp) 'tree')
          ?.  ?=([~ %o *] tree)
            ~|  "%git/repo push: no 'tree' in commit"  !!
          =/  sha  (~(get by p.u.tree) 'sha')
          ?.  ?=([~ %s *] sha)
            ~|  "%git/repo push: no 'sha' in tree"  !!
          p.u.sha
        ::  3. create blobs for each file
        =/  blob-url=@t
          (cat 3 api (cat 3 '/repos/' (cat 3 repo.cfg '/git/blobs')))
        =|  tree-entries=(list json)
        =/  remaining=(list json)  files
        |-
        ?~  remaining
          ::  4. create tree
          =/  tree-body=json
            %-  pairs:enjs:format
            :~  ['base_tree' s+base-tree-sha]
                ['tree' [%a (flop tree-entries)]]
            ==
          =/  tree-url=@t
            (cat 3 api (cat 3 '/repos/' (cat 3 repo.cfg '/git/trees')))
          ;<  tree-resp=json  bind:m  (gh-post tree-url headers tree-body)
          ?.  ?=(%o -.tree-resp)
            ~|  "%git/repo push: unexpected tree response"  !!
          =/  new-tree-sha=@t
            =/  sha  (~(get by p.tree-resp) 'sha')
            ?.  ?=([~ %s *] sha)
              ~|  "%git/repo push: no 'sha' in tree response"  !!
            p.u.sha
          ::  5. create commit
          =/  commit-body=json
            %-  pairs:enjs:format
            :~  ['message' s+message]
                ['tree' s+new-tree-sha]
                ['parents' [%a ~[s+head-sha]]]
                :-  'author'
                %-  pairs:enjs:format
                :~  ['name' s+author-name]
                    ['email' s+author-email]
                ==
            ==
          =/  new-commit-url=@t
            (cat 3 api (cat 3 '/repos/' (cat 3 repo.cfg '/git/commits')))
          ;<  new-commit-resp=json  bind:m  (gh-post new-commit-url headers commit-body)
          ?.  ?=(%o -.new-commit-resp)
            ~|  "%git/repo push: unexpected commit create response"  !!
          =/  new-commit-sha=@t
            =/  sha  (~(get by p.new-commit-resp) 'sha')
            ?.  ?=([~ %s *] sha)
              ~|  "%git/repo push: no 'sha' in new commit"  !!
            p.u.sha
          ::  6. update ref
          =/  update-body=json
            (pairs:enjs:format ~[['sha' s+new-commit-sha]])
          =/  update-url=@t
            (cat 3 api (cat 3 '/repos/' (cat 3 repo.cfg (cat 3 '/git/refs/heads/' branch))))
          ;<  *  bind:m  (gh-patch update-url headers update-body)
          ~&  >>  ["%git/repo push: pushed" (crip (scag 7 (trip new-commit-sha))) "to" repo.cfg branch]
          ::  clear push.json
          ;<  ~  bind:m
            (over:io push-road [[/ %json] !>([%o ~])])
          ;<  ~  bind:m  (set-status 'idle')
          ^$
        ::  process current file — create blob
        =/  file=json  i.remaining
        ?.  ?=(%o -.file)
          $(remaining t.remaining)
        =/  file-path=(unit json)  (~(get by p.file) 'path')
        =/  file-content=(unit json)  (~(get by p.file) 'content')
        ?~  file-path    $(remaining t.remaining)
        ?.  ?=([%s *] u.file-path)  $(remaining t.remaining)
        ?~  file-content   $(remaining t.remaining)
        ?.  ?=([%s *] u.file-content)  $(remaining t.remaining)
        =/  blob-body=json
          %-  pairs:enjs:format
          :~  ['content' u.file-content]
              ['encoding' s+'utf-8']
          ==
        ;<  blob-resp=json  bind:m  (gh-post blob-url headers blob-body)
        ?.  ?=(%o -.blob-resp)
          ~|  "%git/repo push: unexpected blob response"  !!
        =/  blob-sha=@t
          =/  sha  (~(get by p.blob-resp) 'sha')
          ?.  ?=([~ %s *] sha)
            ~|  "%git/repo push: no 'sha' in blob"  !!
          p.u.sha
        =/  entry=json
          %-  pairs:enjs:format
          :~  ['path' u.file-path]
              ['mode' s+'100644']
              ['type' s+'blob']
              ['sha' s+blob-sha]
          ==
        $(remaining t.remaining, tree-entries [entry tree-entries])
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Git repo clone.'
            ~
          'Clone a public git repo into the namespace. Config: repo, ref.'
        ==
          %|
        ?+  rail.p.mana  'File under git/repo.'
          [~ %'config.json']  'Config: repo (owner/repo), ref (branch/tag/sha), token.'
          [~ %'sync.sig']     'Poke to fetch from remote.'
          [~ %'switch.sig']   'Poke to switch branch locally.'
          [~ %'checkout.sig']  'Poke with commit hash to checkout.'
          [~ %'commit.sig']   'Poke with commit hash to compute diff.'
          [~ %'push.sig']     'Poke to push files to GitHub via REST API.'
          [~ %'push.json']    'Push request: {message, files: [{path, content}]}.'
          [~ %'page.html']    'Dashboard page. Shows config, sync button, file tree.'
        ==
      ==
    --
::
|%
+$  repo-config
  $:  repo=@t
      ref=@t
      token=@t
  ==
::
++  read-config
  =/  m  (fiber:fiber:nexus ,repo-config)
  ^-  form:m
  =/  road=road:tarball  (cord-to-road:tarball './config.json')
  ;<  =seen:nexus  bind:m  (peek:io road `%json)
  ?.  ?=([%& %file *] seen)
    (pure:m ['' 'main' ''])
  =/  cfg=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
  ?.  ?=(%o -.cfg)
    (pure:m ['' 'main' ''])
  =/  get
    |=  [key=@t default=@t]
    ^-  @t
    =/  v  (~(get by p.cfg) key)
    ?.  ?=([~ %s *] v)  default
    ?:(=('' p.u.v) default p.u.v)
  (pure:m [(get 'repo' '') (get 'ref' '') (get 'token' '')])
::
::  +write-repo-file: write or create a file in the repo sub-nexus
::
++  write-repo-file
  |=  [=road:tarball =sage:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    (over:io road sage)
  (make:io road |+[%.n sage ~])
::
::  +save-repo: write pack + index + refs + HEAD + ref into repo sub-nexus
::
++  save-repo
  |=  [pack-data=octs idx-text=tape refs-json=json head-text=@t ref-name=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  idx-octs=octs  (as-octt:bytestream idx-text)
  =/  head-octs=octs  (as-octt:bytestream (trip head-text))
  =/  ref-octs=octs  (as-octt:bytestream (trip ref-name))
  ;<  ~  bind:m
    (write-repo-file (cord-to-road:tarball './data/pack.dat') [[/ %mime] !>([/application/octet-stream pack-data])])
  ;<  ~  bind:m
    (write-repo-file (cord-to-road:tarball './data/pack.idx') [[/ %mime] !>([/text/plain idx-octs])])
  ;<  ~  bind:m
    (write-repo-file (cord-to-road:tarball './data/refs.json') [[/ %json] !>(refs-json)])
  ;<  ~  bind:m
    (write-repo-file (cord-to-road:tarball './data/HEAD') [[/ %mime] !>([/text/plain head-octs])])
  ;<  ~  bind:m
    (write-repo-file (cord-to-road:tarball './data/ref') [[/ %mime] !>([/text/plain ref-octs])])
  (pure:m ~)
::
::  +write-head: update HEAD in repo sub-nexus
::
++  write-head
  |=  hash-text=@t
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  head-octs=octs  (as-octt:bytestream (trip hash-text))
  (over:io (cord-to-road:tarball './data/HEAD') [[/ %mime] !>([/text/plain head-octs])])
::
::  +write-ref: update ref (branch name) in repo sub-nexus
::
++  write-ref
  |=  ref-name=@t
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  ref-octs=octs  (as-octt:bytestream (trip ref-name))
  (over:io (cord-to-road:tarball './data/ref') [[/ %mime] !>([/text/plain ref-octs])])
::
::  +resolve-ref: read ref hash from repo's refs.json
::
++  resolve-ref
  |=  ref=@t
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  =/  road=road:tarball  (cord-to-road:tarball './data/refs.json')
  ;<  =seen:nexus  bind:m  (peek:io road `%json)
  ?.  ?=([%& %file *] seen)
    ~&  >>>  "%git/repo: no refs.json found"
    (pure:m '')
  =/  j=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
  ?.  ?=(%o -.j)
    (pure:m '')
  =/  active=@t  ?:(=('' ref) 'main' ref)
  =/  hash-json=(unit json)  (~(get by p.j) active)
  ?.  ?=([~ %s *] hash-json)
    ~&  >>>  ["%git/repo: ref not found in refs.json:" active]
    (pure:m '')
  (pure:m p.u.hash-json)
::
++  set-status
  |=  s=@t
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (over:io (cord-to-road:tarball './ui/status.json') [[/ %json] !>((pairs:enjs:format ~[['status' s+s]]))])
::
::  +load-repo-from-ns: rebuild git repository from ./data/ namespace files
::
++  load-repo-from-ns
  =/  m  (fiber:fiber:nexus ,repository:git-repo)
  ^-  form:m
  ;<  pack-seen=seen:nexus  bind:m  (peek:io (cord-to-road:tarball './data/pack.dat') `%mime)
  ?.  ?=([%& %file *] pack-seen)
    ~|  "%git/repo: no pack data"  !!
  =/  pack-mim=mime  !<(mime q.sage.p.pack-seen)
  ;<  idx-seen=seen:nexus  bind:m  (peek:io (cord-to-road:tarball './data/pack.idx') `%mime)
  ?.  ?=([%& %file *] idx-seen)
    ~|  "%git/repo: no pack index"  !!
  =/  idx-mim=mime  !<(mime q.sage.p.idx-seen)
  =/  idx-text=tape  (trip q.q.idx-mim)
  =/  idx=pack-index:git-pack
    (rebuild-index (split:git-transport idx-text `@t`10))
  =/  entries=(list [key=hash:git-repo val=@ud])
    (tap:pack-on:git-pack idx)
  =/  sea=bays:bytestream  (from-octs:bytestream q.pack-mim)
  =/  pak=pack:git-pack
    [%sha-1 (lent entries) idx p.q.pack-mim sea]
  ;<  refs-seen=seen:nexus  bind:m  (peek:io (cord-to-road:tarball './data/refs.json') `%json)
  =/  built-refs=(axal ref:git-repo)
    ?.  ?=([%& %file *] refs-seen)  [~ ~]
    =/  j=json  (fall (mole |.(!<(json q.sage.p.refs-seen))) *json)
    ?.  ?=(%o -.j)  [~ ~]
    %+  roll  ~(tap by p.j)
    |=  [[name=@t hash-cord=json] r=(axal ref:git-repo)]
    ?.  ?=(%s -.hash-cord)  r
    =/  h=(unit @ux)
      (rust (trip p.hash-cord) parse-hash-sha-1:git-transport)
    ?~  h  r
    (~(put of r) [~['refs' 'heads' name] u.h])
  =/  repo=repository:git-repo
    [%sha-1 [~ ~[pak]] built-refs ~ ~]
  (pure:m repo)
::
::  +rebuild-index: parse index text lines into pack-index
::
++  rebuild-index
  |=  lines=(list tape)
  ^-  pack-index:git-pack
  =|  idx=pack-index:git-pack
  |-
  ?~  lines  idx
  =/  line=tape  i.lines
  ?:  =(~ line)  $(lines t.lines)
  =/  parts=(list tape)  (split:git-transport line ' ')
  ?.  =((lent parts) 2)  $(lines t.lines)
  =/  hex=tape  (snag 0 parts)
  =/  off=tape  (snag 1 parts)
  =/  h=hash:git-repo  (scan hex parse-hash-sha-1:git-transport)
  =/  o=@ud  (scan off dum:ag)
  $(lines t.lines, idx (put:pack-on:git-pack idx h o))
::
::  +build-diff-json: convert tree changes to JSON with line-level diffs
::
++  build-diff-json
  |=  [get-blob=$-(@ux (unit octs)) changes=(list tree-change:git-transport)]
  ^-  json
  :-  %a
  %+  turn  changes
  |=  c=tree-change:git-transport
  ^-  json
  ?-    -.c
      %add
    =/  blob=(unit octs)  (get-blob hash.c)
    =/  lines=wain  ?~(blob ~ (to-wain:format q.u.blob))
    %-  pairs:enjs:format
    :~  ['path' s+(spat path.c)]
        ['status' s+'add']
        ['lines' [%a (turn lines |=(l=@t (pairs:enjs:format ~[['t' s+'add'] ['v' s+l]])))]]
    ==
  ::
      %del
    =/  blob=(unit octs)  (get-blob hash.c)
    =/  lines=wain  ?~(blob ~ (to-wain:format q.u.blob))
    %-  pairs:enjs:format
    :~  ['path' s+(spat path.c)]
        ['status' s+'del']
        ['lines' [%a (turn lines |=(l=@t (pairs:enjs:format ~[['t' s+'del'] ['v' s+l]])))]]
    ==
  ::
      %mod
    =/  old-blob=(unit octs)  (get-blob old.c)
    =/  new-blob=(unit octs)  (get-blob new.c)
    =/  old-lines=wain  ?~(old-blob ~ (to-wain:format q.u.old-blob))
    =/  new-lines=wain  ?~(new-blob ~ (to-wain:format q.u.new-blob))
    =/  diff=(urge:clay cord)
      (lusk:differ old-lines new-lines (loss:differ old-lines new-lines))
    %-  pairs:enjs:format
    :~  ['path' s+(spat path.c)]
        ['status' s+'mod']
        ['lines' (urge-to-json old-lines diff)]
    ==
  ==
::
::  +urge-to-json: convert (urge:clay cord) diff to JSON line array with types
::
++  urge-to-json
  |=  [old=wain urg=(urge:clay cord)]
  ^-  json
  =|  pos=@ud
  =|  acc=(list json)
  |-
  ?~  urg  [%a acc]
  ?-    -.i.urg
      %&
    =/  ctx=(list @t)  (swag [pos p.i.urg] old)
    =/  ctx-json=(list json)
      (turn ctx |=(l=@t (pairs:enjs:format ~[['t' s+'ctx'] ['v' s+l]])))
    $(urg t.urg, pos (add pos p.i.urg), acc (weld acc ctx-json))
  ::
      %|
    =/  del-json=(list json)
      (turn (flop p.i.urg) |=(l=@t (pairs:enjs:format ~[['t' s+'del'] ['v' s+l]])))
    =/  add-json=(list json)
      (turn (flop q.i.urg) |=(l=@t (pairs:enjs:format ~[['t' s+'add'] ['v' s+l]])))
    %=  $
      urg  t.urg
      pos  (add pos (lent p.i.urg))
      acc  (weld acc (weld del-json add-json))
    ==
  ==
::
::  +fetch-with-redirect: GET a URL, follow one redirect
::
++  fetch-with-redirect
  |=  [=request:http]
  =/  m  (fiber:fiber:nexus ,octs)
  ^-  form:m
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.client-response)
    ~|  "%git/repo: request failed (not finished)"  !!
  =/  status  status-code.response-header.client-response
  ?:  ?|  =(status 301)
          =(status 302)
          =(status 307)
      ==
    =/  location=(unit @t)
      (~(get by (malt headers.response-header.client-response)) 'location')
    ?~  location
      ~|  "%git/repo: redirect without location header"  !!
    =/  redir=request:http
      [%'GET' u.location ~[['User-Agent' 'grubbery']] ~]
    ;<  ~  bind:m  (send-request:io redir)
    ;<  =client-response:iris  bind:m  take-client-response:io
    ?.  ?=(%finished -.client-response)
      ~|  "%git/repo: redirect failed"  !!
    ?.  =(200 status-code.response-header.client-response)
      ~|  "%git/repo: non-200 after redirect"  !!
    ?~  full-file.client-response
      ~|  "%git/repo: empty response after redirect"  !!
    (pure:m data.u.full-file.client-response)
  ?.  =(200 status)
    ~|  "%git/repo: unexpected status {<status>}"  !!
  ?~  full-file.client-response
    ~|  "%git/repo: empty response"  !!
  (pure:m data.u.full-file.client-response)
::
::  +fetch-discovery: GET /info/refs for a repo
::
++  fetch-discovery
  |=  repo=@t
  =/  m  (fiber:fiber:nexus ,discovery:git-transport)
  ^-  form:m
  =/  url=@t
    (rap 3 ~['https://github.com/' repo '.git/info/refs?service=git-upload-pack'])
  =/  =request:http
    [%'GET' url ~[['User-Agent' 'grubbery']] ~]
  ;<  body=octs  bind:m  (fetch-with-redirect request)
  (pure:m (parse-discovery:git-transport body))
::
::  +fetch-pack: POST /git-upload-pack for a repo
::
++  fetch-pack
  |=  [repo=@t want-body=octs]
  =/  m  (fiber:fiber:nexus ,octs)
  ^-  form:m
  =/  url=@t
    (rap 3 ~['https://github.com/' repo '.git/git-upload-pack'])
  =/  =request:http
    :^  %'POST'  url
      :~  ['Content-Type' 'application/x-git-upload-pack-request']
          ['User-Agent' 'grubbery']
      ==
    `want-body
  ;<  body=octs  bind:m  (fetch-with-redirect request)
  (pure:m body)
::
::  +gh-request: make a GitHub REST API request, follow redirects
::
++  gh-request
  |=  [method=method:http url=@t headers=(list [key=@t value=@t]) bod=(unit octs)]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  =request:http  [method url headers bod]
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.client-response)
    ~|  "%git/repo: GitHub API request did not finish"  !!
  =/  status=@ud  status-code.response-header.client-response
  ?:  ?|  =(301 status)
          =(302 status)
          =(307 status)
      ==
    =/  location=(unit @t)
      (~(get by (malt headers.response-header.client-response)) 'location')
    ?~  location
      ~|  "%git/repo: GitHub API redirect without location"  !!
    (gh-request method u.location headers bod)
  ?~  full-file.client-response
    ~|  "%git/repo: GitHub API empty response (status {<status>})"  !!
  =/  body=@t  q.data.u.full-file.client-response
  ?.  ?&  (gte status 200)
          (lth status 300)
      ==
    ~|  "%git/repo: GitHub API error (status {<status>}): {(trip body)}"  !!
  =/  parsed=(unit json)  (de:json:html body)
  ?~  parsed
    ~|  "%git/repo: GitHub API invalid JSON"  !!
  (pure:m u.parsed)
::
++  gh-get
  |=  [url=@t headers=(list [key=@t value=@t])]
  (gh-request %'GET' url headers ~)
::
++  gh-post
  |=  [url=@t headers=(list [key=@t value=@t]) body=json]
  =/  body-octs=octs  (as-octs:mimes:html (en:json:html body))
  (gh-request %'POST' url headers `body-octs)
::
++  gh-patch
  |=  [url=@t headers=(list [key=@t value=@t]) body=json]
  =/  body-octs=octs  (as-octs:mimes:html (en:json:html body))
  (gh-request %'PATCH' url headers `body-octs)
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
+$  page-event
  $%  [%news =wire =view:nexus]
      [%fell =wire]
  ==
::
++  take-page-event
  =/  m  (fiber:fiber:nexus ,page-event)
  ^-  form:m
  |=  =input:fiber:nexus
  :+  ~  state.input
  ?+  in.input  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    [%done %news [wire view]:u.in.input]
      [~ %fell *]
    [%done %fell wire.u.in.input]
  ==
::
++  view-to-config
  |=  =view:nexus
  ^-  repo-config
  ?.  ?=([%file *] view)  ['' 'main' '']
  =/  cfg=json  (fall (mole |.(!<(json q.sage.view))) *json)
  ?.  ?=(%o -.cfg)  ['' 'main' '']
  =/  get
    |=  [key=@t default=@t]
    ^-  @t
    =/  v  (~(get by p.cfg) key)
    ?.  ?=([~ %s *] v)  default
    ?:(=('' p.u.v) default p.u.v)
  [(get 'repo' '') (get 'ref' '') (get 'token' '')]
::
++  view-to-branches
  |=  =view:nexus
  ^-  (list @t)
  ?.  ?=([%file *] view)  ~
  =/  j=json  (fall (mole |.(!<(json q.sage.view))) *json)
  ?.  ?=(%a -.j)  ~
  (murn p.j |=(v=json ?.(?=(%s -.v) ~ `p.v)))
::
++  view-to-json
  |=  =view:nexus
  ^-  json
  ?.  ?=([%file *] view)  [%a ~]
  (fall (mole |.(!<(json q.sage.view))) [%a ~])
::
++  view-to-files
  |=  =view:nexus
  ^-  (list @t)
  ?.  ?=([%ball *] view)  ~
  (collect-files '' ball.view)
::
++  collect-files
  |=  [prefix=@t =ball:tarball]
  ^-  (list @t)
  =/  file-names=(list @t)
    ?~  fil.ball  ~
    %+  turn  ~(tap by contents.u.fil.ball)
    |=  [name=@ta *]
    ?:(=('' prefix) name (crip "{(trip prefix)}/{(trip name)}"))
  =/  dir-files=(list @t)
    %-  zing
    %+  turn  ~(tap by dir.ball)
    |=  [name=@ta sub=ball:tarball]
    =/  sub-prefix=@t
      ?:(=('' prefix) name (crip "{(trip prefix)}/{(trip name)}"))
    (collect-files sub-prefix sub)
  (weld file-names dir-files)
::
++  page-css
  ^-  tape
  %-  zing
  ^-  (list tape)
  :~  "*\{box-sizing:border-box;margin:0;padding:0}"
      "body\{font-family:-apple-system,system-ui,monospace;color:#1a1a1a;"
      "font-size:14px;line-height:1.5;height:100vh}"
      ::  -- setup screen (no files yet) --
      ".setup\{display:flex;align-items:center;justify-content:center;"
      "height:100vh;flex-direction:column;gap:1rem}"
      ".setup h1\{font-size:1.2rem;font-weight:500}"
      ".setup .form\{display:flex;flex-direction:column;gap:.5rem;width:320px}"
      ".setup label\{font-size:12px;opacity:.5}"
      ".setup input\{padding:.4rem .6rem;border:1px solid #ccc;"
      "border-radius:3px;font:inherit;font-size:14px;width:100%}"
      ".setup .row\{display:flex;gap:.5rem}"
      ".setup .row input\{flex:1}"
      ::  -- browser screen (files present) --
      ".browser\{display:flex;flex-direction:column;height:100vh}"
      ".toolbar\{display:flex;gap:.5rem;padding:.4rem .75rem;"
      "border-bottom:1px solid #e0e0e0;align-items:center;"
      "background:#fafafa;flex-shrink:0}"
      ".toolbar input\{padding:.3rem .5rem;border:1px solid #ccc;"
      "border-radius:3px;font:inherit;font-size:13px}"
      ".toolbar .repo\{flex:1;min-width:160px}"
      ".toolbar select.ref\{padding:.3rem .5rem;border:1px solid #ccc;"
      "border-radius:3px;font:inherit;font-size:13px;max-width:200px}"
      ".btn\{padding:.3rem .75rem;border:1px solid #ccc;border-radius:3px;"
      "background:#fff;font:inherit;font-size:13px;cursor:pointer;"
      "white-space:nowrap}"
      ".btn:hover\{background:#f0f0f0}"
      ".btn.primary\{background:#1a1a1a;color:#fff;border-color:#1a1a1a}"
      ".btn.primary:hover\{background:#333}"
      ".btn:disabled\{opacity:.4;cursor:default}"
      ".info\{font-size:12px;opacity:.4;margin-left:auto}"
      ".panes\{display:flex;flex:1;overflow:hidden}"
      ".tree-pane\{width:260px;min-width:0;border-right:1px solid #e0e0e0;"
      "overflow-y:auto;padding:.25rem 0;flex-shrink:0;"
      "transition:width .15s}"
      ".tree-pane.collapsed\{width:0;padding:0;border:0;overflow:hidden}"
      ".toggle-tree\{background:none;border:none;border-right:1px solid #e0e0e0;"
      "cursor:pointer;padding:0 6px;font-size:16px;opacity:.4;"
      "flex-shrink:0}"
      ".toggle-tree:hover\{opacity:.7;background:#f5f5f5}"
      ".content-pane\{flex:1;overflow-y:auto;padding:1rem}"
      ::  -- tree --
      ".dir\{cursor:pointer;user-select:none}"
      ".dir-label\{display:flex;align-items:center;padding:2px 8px}"
      ".dir-label:hover\{background:#f0f0f0}"
      ".dir-label .arrow\{width:14px;font-size:9px;flex-shrink:0;"
      "transition:transform .1s}"
      ".dir-label .arrow.open\{transform:rotate(90deg)}"
      ".dir-children\{display:none}"
      ".dir.open>.dir-children\{display:block}"
      ".file\{padding:2px 8px;cursor:pointer;font-size:13px}"
      ".file:hover\{background:#f0f0f0}"
      ".file.active\{background:#e8f0fe}"
      ::  -- file viewer --
      ".file-view .path\{font-size:12px;opacity:.4;margin-bottom:.75rem}"
      ".file-view pre\{white-space:pre-wrap;word-break:break-all;"
      "font-size:13px;line-height:1.6}"
      ".placeholder\{opacity:.3;padding:3rem;text-align:center}"
      ".syncing\{display:flex;align-items:center;gap:8px;padding:8px 10px;"
      "font-size:13px;opacity:.5}"
      "@keyframes spin\{to\{transform:rotate(360deg)}}"
      ".spinner\{display:inline-block;width:14px;height:14px;"
      "border:2px solid #ccc;border-top-color:#333;border-radius:50%;"
      "animation:spin .6s linear infinite}"
      ::  -- commit log --
      ".commit-pane\{border-top:1px solid #e0e0e0;max-height:220px;"
      "overflow-y:auto;flex-shrink:0}"
      ".commit-pane .header\{display:flex;align-items:center;"
      "padding:6px 12px;font-size:12px;font-weight:600;"
      "background:#fafafa;border-bottom:1px solid #e0e0e0;"
      "cursor:pointer;user-select:none;position:sticky;top:0;z-index:1}"
      ".commit-pane .header .arrow\{margin-right:6px;font-size:9px;"
      "transition:transform .1s}"
      ".commit-pane .header .arrow.open\{transform:rotate(90deg)}"
      ".commit-pane.collapsed .commit-list\{display:none}"
      ".commit-entry\{display:flex;align-items:baseline;gap:8px;"
      "padding:4px 12px;font-size:12px;cursor:pointer;"
      "border-bottom:1px solid #f0f0f0}"
      ".commit-entry:hover\{background:#f5f8ff}"
      ".commit-entry.active\{background:#e8f0fe}"
      ".commit-entry.head\{background:#f0fdf4}"
      ".commit-entry.head .hash:after\{content:'HEAD';margin-left:4px;"
      "font-size:10px;background:#1a7f37;color:#fff;padding:0 4px;"
      "border-radius:3px;font-family:-apple-system,system-ui,sans-serif}"
      ".commit-entry .hash\{font-family:monospace;color:#0969da;"
      "flex-shrink:0}"
      ".commit-entry .msg\{flex:1;overflow:hidden;"
      "text-overflow:ellipsis;white-space:nowrap}"
      ".commit-entry .author\{opacity:.5;flex-shrink:0}"
      ".head-bar\{display:flex;align-items:center;gap:8px;"
      "padding:3px 12px;border-bottom:1px solid #e0e0e0;"
      "background:#f0fdf4;font-size:12px;cursor:pointer;flex-shrink:0}"
      ".head-bar:hover\{background:#dcfce7}"
      ".head-bar .hash\{font-family:monospace;color:#1a7f37;font-weight:600}"
      ".head-bar .msg\{opacity:.7;overflow:hidden;"
      "text-overflow:ellipsis;white-space:nowrap}"
      ".head-bar .badge\{font-size:10px;background:#1a7f37;color:#fff;"
      "padding:0 4px;border-radius:3px;flex-shrink:0}"
      ".commit-popup\{position:fixed;top:0;left:0;right:0;bottom:0;"
      "background:rgba(0,0,0,.3);display:flex;align-items:center;"
      "justify-content:center;z-index:100}"
      ".commit-popup .card\{background:#fff;border-radius:6px;padding:1rem;"
      "max-width:560px;width:90%;max-height:80vh;overflow-y:auto;"
      "box-shadow:0 4px 24px rgba(0,0,0,.15)}"
      ".commit-popup .card h3\{font-size:14px;margin-bottom:.5rem}"
      ".commit-popup .card .meta\{font-size:12px;margin-bottom:.75rem;"
      "border-collapse:collapse;width:100%}"
      ".commit-popup .card .meta td\{padding:2px 8px 2px 0;vertical-align:top}"
      ".commit-popup .card .meta td:first-child\{opacity:.5;white-space:nowrap;"
      "font-weight:500;width:90px}"
      ".commit-popup .card .meta code\{font-size:11px;background:#f5f5f5;"
      "padding:1px 4px;border-radius:2px;word-break:break-all}"
      ".commit-popup .card .body\{font-size:13px;white-space:pre-wrap;"
      "line-height:1.6;font-family:monospace}"
      ".commit-popup .card .close\{float:right;background:none;border:none;"
      "font-size:18px;cursor:pointer;opacity:.4;padding:0 4px}"
      ".commit-popup .card .close:hover\{opacity:.8}"
      ::  -- diff view --
      ".diff-view\{font-size:13px}"
      ".diff-header\{padding:0 0 .75rem;display:flex;align-items:center;gap:8px}"
      ".diff-header .hash\{font-family:monospace;color:#0969da;font-weight:600}"
      ".diff-header .msg\{opacity:.7}"
      ".diff-file\{margin-bottom:1rem;border:1px solid #e0e0e0;"
      "border-radius:4px;overflow:hidden}"
      ".diff-file-header\{padding:6px 12px;background:#f6f8fa;"
      "border-bottom:1px solid #e0e0e0;font-size:12px;"
      "display:flex;align-items:center;gap:8px;cursor:pointer}"
      ".diff-file-header:hover\{background:#eef1f5}"
      ".diff-file-header .badge\{font-size:10px;padding:0 4px;"
      "border-radius:3px;color:#fff;flex-shrink:0}"
      ".badge-add\{background:#1a7f37}"
      ".badge-del\{background:#cf222e}"
      ".badge-mod\{background:#9a6700}"
      ".diff-lines\{font-family:monospace;font-size:12px;line-height:1.5;"
      "overflow-x:auto;display:none}"
      ".diff-file.open .diff-lines\{display:block}"
      ".diff-line\{padding:0 12px;white-space:pre-wrap;word-break:break-all}"
      ".diff-line.ctx\{background:#fff}"
      ".diff-line.add\{background:#e6ffec}"
      ".diff-line.del\{background:#ffebe9}"
      ".diff-line .pre\{opacity:.4;display:inline-block;width:12px;"
      "text-align:center;margin-right:4px;user-select:none}"
  ==
::
++  page-script
  |=  [api=@t repo=@t ref=@t]
  ^-  tape
  %-  zing
  ^-  (list tape)
  :~  "var A='{(trip api)}';"
      "var R='{(trip repo)}';"
      "var F='{(trip ref)}';"
      "var _files=window._FILES||[];"
      ::  fetch: pull latest from remote
      "function doFetch()\{"
      "var r=document.getElementById('repo').value;"
      "var sel=document.getElementById('ref');"
      "var f=sel?(sel.value||''):(''||'');"
      "if(!r)\{return}"
      "var btn=document.getElementById('fetch-btn');"
      "if(btn)\{btn.disabled=true;btn.textContent='\\u21bb'}"
      "fetch(A.replace('/file/','/over/')+'/config.json?mark=json',"
      "\{method:'POST',headers:\{'Content-Type':'application/json'},"
      "body:JSON.stringify(\{repo:r,ref:f})})"
      ".then(function()\{"
      "return fetch(A.replace('/file/','/poke/')+'/sync.sig',"
      "\{method:'POST',headers:\{'Content-Type':'text/plain'},body:'sync'})"
      "}).catch(function()\{"
      "if(btn)\{btn.disabled=false}"
      "})}"
      ::  branch switch: local only
      "function doSwitch()\{"
      "var r=document.getElementById('repo').value;"
      "var sel=document.getElementById('ref');"
      "var f=sel?(sel.value||''):(''||'');"
      "if(!r)\{return}"
      "if(sel)\{sel.disabled=true}"
      "fetch(A.replace('/file/','/over/')+'/config.json?mark=json',"
      "\{method:'POST',headers:\{'Content-Type':'application/json'},"
      "body:JSON.stringify(\{repo:r,ref:f})})"
      ".then(function()\{"
      "return fetch(A.replace('/file/','/poke/')+'/switch.sig',"
      "\{method:'POST',headers:\{'Content-Type':'text/plain'},body:'switch'})"
      "}).catch(function()\{"
      "if(sel)\{sel.disabled=false}"
      "})}"
      "var refSel=document.getElementById('ref');"
      "if(refSel)\{refSel.onchange=doSwitch}"
      ::  build tree from flat file list
      "function buildTree(files)\{"
      "var root=\{_f:[],_d:\{}};"
      "files.forEach(function(f)\{"
      "var p=f.split('/'),n=root;"
      "for(var i=0;i<p.length-1;i++)\{"
      "if(!n._d[p[i]])n._d[p[i]]=\{_f:[],_d:\{}};"
      "n=n._d[p[i]]}n._f.push(p[p.length-1])"
      "});return root}"
      ::  render tree into DOM
      "function renderTree(node,el,depth,prefix)\{"
      "var dirs=Object.keys(node._d).sort();"
      "dirs.forEach(function(d)\{"
      "var div=document.createElement('div');div.className='dir';"
      "var label=document.createElement('div');"
      "label.className='dir-label';"
      "label.style.paddingLeft=(8+depth*14)+'px';"
      "label.innerHTML='<span class=\"arrow\">\\u25b6</span> '+d+'/';"
      "label.onclick=function()\{"
      "div.classList.toggle('open');"
      "label.querySelector('.arrow').classList.toggle('open')};"
      "div.appendChild(label);"
      "var ch=document.createElement('div');ch.className='dir-children';"
      "renderTree(node._d[d],ch,depth+1,prefix+d+'/');"
      "div.appendChild(ch);el.appendChild(div)});"
      "node._f.sort().forEach(function(f)\{"
      "var fe=document.createElement('div');fe.className='file';"
      "fe.style.paddingLeft=(22+depth*14)+'px';"
      "fe.textContent=f;"
      "fe.onclick=function()\{viewFile(prefix+f,fe)};"
      "el.appendChild(fe)})}"
      ::  view file content
      "function viewFile(path,el)\{"
      "document.querySelectorAll('.file.active').forEach("
      "function(e)\{e.classList.remove('active')});"
      "document.querySelectorAll('.commit-entry.active').forEach("
      "function(e)\{e.classList.remove('active')});"
      "if(el)el.classList.add('active');"
      "var pane=document.getElementById('content');"
      "pane.innerHTML='<div class=\"file-view\">"
      "<div class=\"path\">'+path+'</div>"
      "<pre>Loading...</pre></div>';"
      "fetch(A+'/data/tree/'+path).then(function(r)\{"
      "if(!r.ok)throw new Error(r.status);"
      "var ct=r.headers.get('content-type')||'';"
      "if(ct.indexOf('text')>=0||ct.indexOf('json')>=0"
      "||ct.indexOf('javascript')>=0)"
      "return r.text().then(function(t)\{"
      "pane.querySelector('pre').textContent=t});"
      "pane.querySelector('pre').textContent='[binary '+ct+']'"
      "}).catch(function(e)\{"
      "pane.querySelector('pre').textContent='Error: '+e.message})}"
      ::  bind fetch button + setup clone button
      "var fb=document.getElementById('fetch-btn');"
      "if(fb)\{fb.onclick=doFetch}"
      "document.querySelectorAll('.btn.primary').forEach("
      "function(b)\{b.onclick=doFetch});"
      ::  sidebar toggle
      "var tgl=document.getElementById('toggle-tree');"
      "var tpane=document.getElementById('tree-pane');"
      "if(tgl&&tpane)\{tgl.onclick=function()\{"
      "tpane.classList.toggle('collapsed')}}"
      ::  render tree if files exist
      "var tp=document.getElementById('tree');"
      "if(tp&&_files.length)\{"
      "renderTree(buildTree(_files),tp,0,'')}"
      ::  SSE: watch status.json for syncing indicator
      "var SK=A.replace('/file/','/keep/')+'/ui/status.json';"
      "function watchStatus()\{"
      "fetch(SK+'?mark=json',\{headers:\{Accept:'text/event-stream'}})"
      ".then(function(r)\{"
      "var rd=r.body.getReader(),dec=new TextDecoder(),buf='';"
      "function pump()\{"
      "rd.read().then(function(res)\{"
      "if(res.done)return;"
      "buf+=dec.decode(res.value,\{stream:true});"
      "var ps=buf.split('\\n\\n');buf=ps.pop();"
      "for(var i=0;i<ps.length;i++)\{"
      "if(!ps[i].trim())continue;"
      "var ls=ps[i].split('\\n'),data='';"
      "for(var j=0;j<ls.length;j++)\{"
      "if(ls[j].indexOf('data: ')===0)data+=ls[j].slice(6)}"
      "try\{var st=JSON.parse(data);"
      "var el=document.getElementById('syncing');"
      "if(st.status==='syncing')\{"
      "var fb=document.getElementById('fetch-btn');"
      "if(fb)\{fb.disabled=true}"
      "if(!el)\{"
      "var s=document.createElement('div');s.id='syncing';"
      "s.className='syncing';"
      "s.innerHTML='<span class=\"spinner\"></span> syncing...';"
      "var tp=document.getElementById('tree')||document.getElementById('content');"
      "if(tp)tp.parentNode.insertBefore(s,tp)}}"
      "if(st.status==='idle'&&el)\{"
      "el.remove();setTimeout(function()\{location.reload()},1500)}"
      "}catch(e)\{}}pump()}).catch(function()\{})}"
      "pump()})"
      ".catch(function()\{setTimeout(watchStatus,3000)})}"
      "watchStatus();"
      ::  SSE: watch repo tree for changes
      "var K=A.replace('/file/','/keep/')+'/data/tree';"
      "function watchTree()\{"
      "var _r;"
      "fetch(K+'?mark=txt',\{headers:\{Accept:'text/event-stream'}})"
      ".then(function(r)\{"
      "var rd=r.body.getReader(),dec=new TextDecoder(),buf='';"
      "function pump()\{"
      "rd.read().then(function(res)\{"
      "if(res.done)return;"
      "buf+=dec.decode(res.value,\{stream:true});"
      "var ps=buf.split('\\n\\n');buf=ps.pop();"
      "for(var i=0;i<ps.length;i++)\{"
      "if(!ps[i].trim())continue;"
      "var ls=ps[i].split('\\n'),ev='';"
      "for(var j=0;j<ls.length;j++)\{"
      "if(ls[j].indexOf('event: ')===0)ev=ls[j].slice(7)}"
      "if(ev&&ev.indexOf('old ')!==0)\{"
      "clearTimeout(_r);"
      "_r=setTimeout(function()\{location.reload()},1500)}}"
      "pump()}).catch(function()\{})}"
      "pump()})"
      ".catch(function()\{setTimeout(watchTree,3000)})}"
      "watchTree();"
      ::  commit log toggle + render
      "var cpane=document.getElementById('commit-pane');"
      "var ctgl=document.getElementById('commit-toggle');"
      "if(ctgl)\{ctgl.onclick=function()\{"
      "cpane.classList.toggle('collapsed');"
      "ctgl.querySelector('.arrow').classList.toggle('open')}}"
      "function renderCommits()\{"
      "var cl=document.getElementById('commit-list');"
      "if(!cl||!window._COMMITS||!window._COMMITS.length)return;"
      "cl.innerHTML='';"
      "var cur=window._CURRENT||window._COMMITS[0].hash;"
      "var curCommit=window._COMMITS.find(function(c)\{return c.hash===cur})||window._COMMITS[0];"
      "var hb=document.getElementById('head-bar');"
      "if(hb)\{"
      "hb.innerHTML='<span class=\"badge\">HEAD</span>"
      "<span class=\"hash\">'+curCommit.short+'</span>"
      "<span class=\"msg\">'+curCommit.message+'</span>';"
      "hb.onclick=function()\{showCommitPopup(curCommit)}}"
      "window._COMMITS.forEach(function(c,i)\{"
      "var d=document.createElement('div');"
      "d.className='commit-entry'+(c.hash===cur?' head':'');"
      "d.innerHTML='<span class=\"hash\">'+c.short+'</span>"
      "<span class=\"msg\">'+c.message+'</span>"
      "<span class=\"author\">'+c.author+'</span>';"
      "d.onclick=function()\{"
      "document.querySelectorAll('.commit-entry.active').forEach("
      "function(e)\{e.classList.remove('active')});"
      "d.classList.add('active');"
      "viewCommitDiff(c.hash)};"
      "cl.appendChild(d)});"
      "if(window._COMMITS.length>=50)\{"
      "var m=document.createElement('div');"
      "m.style.cssText='padding:6px 12px;font-size:11px;opacity:.4;text-align:center;border-top:1px solid #e0e0e0';"
      "m.textContent='older commits not shown...';"
      "cl.appendChild(m)}}"
      "function checkoutCommit(hash)\{"
      "fetch(A.replace('/file/','/poke/')+'/checkout.sig?mark=txt',"
      "\{method:'POST',headers:\{'Content-Type':'text/plain'},body:hash})"
      ".catch(function()\{})}"
      "function showCommitPopup(c)\{"
      "var bg=document.createElement('div');bg.className='commit-popup';"
      "var rows='';"
      "rows+='<tr><td>commit</td><td><code>'+c.hash+'</code></td></tr>';"
      "if(c.tree)rows+='<tr><td>tree</td><td><code>'+c.tree+'</code></td></tr>';"
      "if(c.parents&&c.parents.length)"
      "rows+='<tr><td>parent'+(c.parents.length>1?'s':'')+'</td><td><code>'+c.parents.join('<br>')+'</code></td></tr>';"
      "var ae=c.authorEmail?' &lt;'+c.authorEmail+'&gt;':'';"
      "rows+='<tr><td>author</td><td><b>'+c.author+'</b>'+ae+'</td></tr>';"
      "if(c.date)rows+='<tr><td>authored</td><td>'+new Date(c.date).toLocaleString()+'</td></tr>';"
      "if(c.committer&&c.committer!==c.author)\{"
      "var ce=c.committerEmail?' &lt;'+c.committerEmail+'&gt;':'';"
      "rows+='<tr><td>committer</td><td><b>'+c.committer+'</b>'+ce+'</td></tr>'}"
      "if(c.commitDate)rows+='<tr><td>committed</td><td>'+new Date(c.commitDate).toLocaleString()+'</td></tr>';"
      "var body=(c.body||c.message||'').trim();"
      "var title=body.split('\\n')[0];"
      "var rest=body.split('\\n').slice(1).join('\\n').trim();"
      "bg.innerHTML='<div class=\"card\">"
      "<button class=\"close\">&times;</button>"
      "<h3>'+title+'</h3>"
      "<table class=\"meta\">'+rows+'</table>"
      "'+( rest?'<div class=\"body\">'+rest+'</div>':'' )+'</div>';"
      "bg.querySelector('.close').onclick=function()\{bg.remove()};"
      "bg.onclick=function(e)\{if(e.target===bg)bg.remove()};"
      "document.body.appendChild(bg)}"
      "renderCommits();"
      ::  diff view: poke commit.sig, watch commit.json, render
      "function viewCommitDiff(hash)\{"
      "document.querySelectorAll('.file.active').forEach("
      "function(e)\{e.classList.remove('active')});"
      "var pane=document.getElementById('content');"
      "pane.innerHTML='<div class=\"placeholder\">"
      "<span class=\"spinner\"></span> computing diff...</div>';"
      "fetch(A.replace('/file/','/poke/')+'/commit.sig?mark=txt',"
      "\{method:'POST',headers:\{'Content-Type':'text/plain'},body:hash})}"
      ::
      "function escHtml(s)\{"
      "return s.replace(/&/g,'\\&amp;').replace(/</g,'\\&lt;')"
      ".replace(/>/g,'\\&gt;')}"
      ::
      "function clearDiff()\{"
      "var pane=document.getElementById('content');"
      "pane.innerHTML='<div class=\"placeholder\">select a file</div>';"
      "document.querySelectorAll('.commit-entry.active').forEach("
      "function(e)\{e.classList.remove('active')})}"
      ::
      "function renderDiff(d)\{"
      "var pane=document.getElementById('content');"
      "var h='<div class=\"diff-view\">';"
      "h+='<div class=\"diff-header\">';"
      "h+='<button class=\"btn\" style=\"font-size:11px\""
      " onclick=\"clearDiff()\">\\u2190 files</button>';"
      "h+='<span class=\"hash\">'+d.short+'</span>';"
      "h+='<span class=\"msg\">'+escHtml(d.message)+'</span>';"
      "h+='<span style=\"opacity:.5\">'+escHtml(d.author)+'</span>';"
      "h+='<button class=\"btn\" style=\"margin-left:auto;font-size:11px\""
      " onclick=\"checkoutCommit(\\x27'+d.hash+'\\x27)\">checkout</button>';"
      "h+='</div>';"
      "if(!d.files||!d.files.length)\{"
      "h+='<div class=\"placeholder\">no file changes</div>'}"
      "else\{d.files.forEach(function(f)\{"
      "var bc=f.status==='add'?'badge-add':"
      "f.status==='del'?'badge-del':'badge-mod';"
      "h+='<div class=\"diff-file open\">';"
      "h+='<div class=\"diff-file-header\" onclick=\"this.parentNode.classList.toggle(\\x27open\\x27)\">';"
      "h+='<span class=\"badge '+bc+'\">'+f.status+'</span>';"
      "h+=escHtml(f.path)+'</div>';"
      "h+='<div class=\"diff-lines\">';"
      "if(f.lines)\{f.lines.forEach(function(l)\{"
      "var pre=l.t==='add'?'+':l.t==='del'?'-':' ';"
      "h+='<div class=\"diff-line '+l.t+'\">"
      "<span class=\"pre\">'+pre+'</span>'+escHtml(l.v)+'</div>'})}"
      "h+='</div></div>'})}"
      "h+='</div>';pane.innerHTML=h}"
      ::  SSE: watch commit.json for diff results
      "var CK=A.replace('/file/','/keep/')+'/ui/commit.json';"
      "function watchCommit()\{"
      "fetch(CK+'?mark=json',\{headers:\{Accept:'text/event-stream'}})"
      ".then(function(r)\{"
      "var rd=r.body.getReader(),dec=new TextDecoder(),buf='';"
      "function pump()\{"
      "rd.read().then(function(res)\{"
      "if(res.done)return;"
      "buf+=dec.decode(res.value,\{stream:true});"
      "var ps=buf.split('\\n\\n');buf=ps.pop();"
      "for(var i=0;i<ps.length;i++)\{"
      "if(!ps[i].trim())continue;"
      "var ls=ps[i].split('\\n'),ev='',data='';"
      "for(var j=0;j<ls.length;j++)\{"
      "if(ls[j].indexOf('event: ')===0)ev=ls[j].slice(7);"
      "if(ls[j].indexOf('data: ')===0)data+=ls[j].slice(6)}"
      "if(ev&&ev.indexOf('old ')!==0&&data)\{"
      "try\{renderDiff(JSON.parse(data))}catch(e)\{}}}"
      "pump()}).catch(function()\{})}pump()})"
      ".catch(function()\{setTimeout(watchCommit,3000)})}"
      "watchCommit();"
  ==
::
++  repo-page
  |=  [api=@t repo=@t ref=@t branches=(list @t) files=(list @t) commits=json current=json]
  ^-  manx
  =/  has-files=?  !=(~ files)
  ;html
    ;head
      ;title: {?:(=('' repo) "git repo" "{(trip repo)}")}
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  page-css
      ==
    ==
    ;body
      ;*  ?:  has-files
            ::  -- browser mode --
            :~  ;div.browser
                  ;div.toolbar
                    ;input.repo(id "repo", type "text", value "{(trip repo)}", placeholder "owner/repo");
                    ;select.ref(id "ref")
                      ;*  %+  turn  branches
                          |=  b=@t
                          ?:  =(b ref)
                            ;option(value "{(trip b)}", selected ""): {(trip b)}
                          ;option(value "{(trip b)}"): {(trip b)}
                    ==
                    ;button.btn(id "fetch-btn", title "Fetch from remote"): ↻
                    ;span.info: {(scow %ud (lent files))} files
                  ==
                  ;div.head-bar(id "head-bar");
                  ;div.panes
                    ;button.toggle-tree(id "toggle-tree"): |||
                    ;div.tree-pane(id "tree-pane")
                      ;div(id "tree");
                    ==
                    ;div.content-pane(id "content")
                      ;div.placeholder: select a file
                    ==
                  ==
                  ;div.commit-pane(id "commit-pane")
                    ;div.header(id "commit-toggle")
                      ;span.arrow.open: ▶

                      ;+  ;/  "commits"
                    ==
                    ;div.commit-list(id "commit-list");
                  ==
                ==
            ==
          ::  -- setup mode --
          :~  ;div.setup
                ;h1: git repo
                ;div.form
                  ;label: repository
                  ;input(id "repo", type "text", value "{(trip repo)}", placeholder "owner/repo", autocomplete "off");
                  ;button.btn.primary(id "sync", style "margin-top:.5rem"): Clone
                ==
              ==
          ==
      ;script
        ;+  ;/  (files-json files)
      ==
      ;script
        ;+  ;/  (commits-json commits)
      ==
      ;script
        ;+  ;/  (current-json current)
      ==
      ;script
        ;+  ;/  (page-script api repo ref)
      ==
    ==
  ==
::
++  files-json
  |=  fiz=(list @t)
  ^-  tape
  ?~  fiz  "window._FILES=[];"
  =/  head=tape  (weld "'" (weld (trip i.fiz) "'"))
  =/  rest=tape
    %-  zing
    %+  turn  t.fiz
    |=(f=@t (weld ",'" (weld (trip f) "'")))
  (weld "window._FILES=[" (weld head (weld rest "];")))
::
++  commits-json
  |=  j=json
  ^-  tape
  ?.  ?=(%a -.j)  "window._COMMITS=[];"
  (weld "window._COMMITS=" (weld (trip (en:json:html j)) ";"))
::
++  current-json
  |=  j=json
  ^-  tape
  ?.  ?=(%o -.j)  "window._CURRENT='';"
  =/  h=(unit json)  (~(get by p.j) 'hash')
  ?~  h  "window._CURRENT='';"
  ?.  ?=(%s -.u.h)  "window._CURRENT='';"
  (weld "window._CURRENT='" (weld (trip p.u.h) "';"))
  ::
--
