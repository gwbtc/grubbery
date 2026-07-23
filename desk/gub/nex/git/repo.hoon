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
/<  git-obj  /lib/git/object.hoon
/<  git-pack  /lib/git/pack.hoon
/<  git-repo  /lib/git/repository.hoon
/<  git-transport  /lib/git/transport.hoon
/&  man  ../../man/git/repo/readme.md
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  default-config=json
        %-  pairs:enjs:format
        :~  ['repo' s+'']
            ['ref' s+'']
            ['token' s+'']
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'config.json'] [[/ %json] default-config]]
          [%fall %& [/actions %'sync.sig'] [[/ %sig] ~]]
          [%fall %& [/actions %'switch.sig'] [[/ %sig] ~]]
          [%fall %& [/actions %'checkout.sig'] [[/ %sig] ~]]
          [%fall %& [/actions %'diff.sig'] [[/ %sig] ~]]
          [%fall %& [/actions %'add.sig'] [[/ %sig] ~]]
          [%fall %& [/actions %'commit.sig'] [[/ %sig] ~]]
          [%fall %& [/actions %'import.sig'] [[/ %sig] ~]]
          [%fall %& [/actions %'branch.sig'] [[/ %sig] ~]]
          [%fall %& [/actions %'delete-branch.sig'] [[/ %sig] ~]]
          [%fall %& [/actions %'stash.sig'] [[/ %sig] ~]]
          [%fall %& [/actions %'stash-pop.sig'] [[/ %sig] ~]]
          [%fall %& [/actions %'push.sig'] [[/ %sig] ~]]
          [%fall %| /ui empty-dir:loader]
          [%fall %& [/ui %'status.json'] [[/ %json] (pairs:enjs:format ~[['status' s+'idle']])]]
          [%fall %& [/ui %'commit.json'] [[/ %json] [%a ~]]]
          [%over %& [/ %'page.html'] [[/ %html] (crip (en-xml:html (repo-page '' '' '' ~ ~ [%a ~] [%o ~] clean-status)))]]
          [%fall %| /data [`[`[/git %data] ~ %.n ~] ~]]
          [%over %& [/man %'readme.md'] [[/ %mime] man]]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  /actions/branch.sig: create a new branch at HEAD
          ::
          [[%actions ~] %'branch.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo branch: failed")
        |-
        ;<  poke-sage=sage:tarball  bind:m  take-poke:io
        =/  branch=@t  (of-wain:format !<(wain q.poke-sage))
        ?:  =('' branch)
          ~&  >>>  "%git/repo: branch requires a name"
          $
        ::  resolve current HEAD to a commit hash
        ;<  head-hash=@t  bind:m  resolve-head
        ?:  =('' head-hash)
          ~&  >>>  "%git/repo: no HEAD to branch from"
          $
        ::  check branch doesn't already exist
        ;<  exists-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& /data/refs/heads (crip (trip branch))])
        ;<  exists=?  bind:m  (peek-exists:io exists-rd)
        ?:  exists
          ~&  >>>  ["%git/repo: branch already exists:" branch]
          $
        ::  create refs/heads/<branch> pointing to HEAD
        =/  ref-octs=octs  (as-octt:bytestream (trip head-hash))
        ;<  ref-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& /data/refs/heads (crip (trip branch))])
        ;<  ~  bind:m  (over:io ref-rd [[/ %mime] [/text/plain ref-octs]])
        ~&  >>  ["%git/repo: created branch" branch "at" head-hash]
        ::  reload data to rebuild branch list
        ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
        ;<  ~  bind:m  (reload:io data-rd)
        $
          ::
          ::  /actions/delete-branch.sig: delete a local branch
          ::
          [[%actions ~] %'delete-branch.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo delete-branch: failed")
        |-
        ;<  poke-sage=sage:tarball  bind:m  take-poke:io
        =/  branch=@t  (of-wain:format !<(wain q.poke-sage))
        ?:  =('' branch)
          ~&  >>>  "%git/repo: delete-branch requires a name"
          $
        ::  read current branch from HEAD to prevent deleting active branch
        ;<  current-branch=@t  bind:m  read-head-branch
        ?:  =(branch current-branch)
          ~&  >>>  ["%git/repo: cannot delete current branch:" branch]
          $
        ::  delete refs/heads/<branch>
        ;<  del-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& /data/refs/heads (crip (trip branch))])
        ;<  exists=?  bind:m  (peek-exists:io del-rd)
        ?.  exists
          ~&  >>>  ["%git/repo: branch not found:" branch]
          $
        ;<  ~  bind:m  (drop:io /delete-branch del-rd)
        ~&  >>  ["%git/repo: deleted branch" branch]
        ::  reload data to rebuild branch list
        ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
        ;<  ~  bind:m  (reload:io data-rd)
        $
          ::
          ::  /actions/stash.sig: stash dirty index and reset to HEAD
          ::
          [[%actions ~] %'stash.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo stash: failed")
        |-
        ;<  *  bind:m  take-poke:io
        ~&  >>  "%git/repo: stashing"
        ::  write stash-request.sig into data ball, reload
        ;<  req-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& /data %'stash-request.sig'])
        ;<  ~  bind:m  (write-repo-file req-rd [[/ %sig] ~])
        ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
        ;<  ~  bind:m  (reload:io data-rd)
        $
          ::
          ::  /actions/stash-pop.sig: pop the most recent stash
          ::
          [[%actions ~] %'stash-pop.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo stash-pop: failed")
        |-
        ;<  *  bind:m  take-poke:io
        ~&  >>  "%git/repo: popping stash"
        ::  write stash-pop-request.sig into data ball, reload
        ;<  req-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& /data %'stash-pop-request.sig'])
        ;<  ~  bind:m  (write-repo-file req-rd [[/ %sig] ~])
        ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
        ;<  ~  bind:m  (reload:io data-rd)
        $
          ::
          ::  /actions/import.sig: bundle import — poke with octs to parse
          ::
          [[%actions ~] %'import.sig']
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
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  api=@t
          (crip "/grubbery/api/file{(spud path.here)}")
        ;<  cfg-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& / %'config.json'])
        ;<  *  bind:m  (keep:io /cfg cfg-rd `[/ %json])
        ;<  tree-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%| /data/tree])
        ;<  *  bind:m  (keep:io /tree tree-rd ~)
        ;<  status-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& /ui %'status.json'])
        ;<  *  bind:m  (keep:io /status status-rd `[/ %json])
        ;<  branches-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& /data/ui %'branches.json'])
        ;<  *  bind:m  (keep:io /branches branches-rd `[/ %json])
        ;<  commits-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& /data/ui %'commits.json'])
        ;<  *  bind:m  (keep:io /commits commits-rd `[/ %json])
        ;<  current-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& /data/ui %'current.json'])
        ;<  *  bind:m  (keep:io /current current-rd `[/ %json])
        |-
        ;<  cfg-v=view:nexus  bind:m  (peek:io cfg-rd `[/ %json])
        ;<  tree-v=view:nexus  bind:m  (peek:io tree-rd ~)
        ;<  status-v=view:nexus  bind:m  (peek:io status-rd `[/ %json])
        ;<  branches-v=view:nexus  bind:m  (peek:io branches-rd `[/ %json])
        ;<  commits-v=view:nexus  bind:m  (peek:io commits-rd `[/ %json])
        ;<  current-v=view:nexus  bind:m  (peek:io current-rd `[/ %json])
        =/  cfg=repo-config  (view-to-config cfg-v)
        =/  files=(list @t)  (view-to-files tree-v)
        =/  branches=(list @t)  (view-to-branches branches-v)
        =/  commits=json  (view-to-json commits-v)
        =/  current=json  (view-to-json current-v)
        =/  status=json   (view-to-json status-v)
        ;<  ~  bind:m  (replace:io (crip (en-xml:html (repo-page api repo.cfg ref.cfg branches files commits current status))))
        ;<  evt=page-event  bind:m  take-page-event
        ?:  ?=(%fell -.evt)  $
        $
          ::  /actions/checkout.sig: checkout a specific commit by hash
          ::
          [[%actions ~] %'checkout.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo checkout: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  hash-text=@t  (of-wain:format !<(wain q.sage))
        ::  block checkout if working tree is dirty
        ;<  status-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& /data/ui %'status.json'])
        ;<  status-view=view:nexus  bind:m  (peek:io status-rd `[/ %json])
        =/  is-clean=?
          =/  status-json=json  (view-to-json status-view)
          ?.  ?=(%o -.status-json)  %.y
          =/  cl  (~(get by p.status-json) 'clean')
          ?+  cl  %.n
            [~ %b %.y]  %.y
          ==
        ?.  is-clean
          ~&  >>>  "%git/repo: checkout blocked — working tree is dirty"
          ~&  >>>  "commit or reset your changes first"
          $
        ~&  >>  ["%git/repo: checkout poke" hash-text]
        ;<  ~  bind:m  (set-status 'syncing')
        ::  write new HEAD and reload repo
        ;<  ~  bind:m  (write-head hash-text)
        ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
        ;<  ~  bind:m  (reload:io data-rd)
        ;<  ~  bind:m  (set-status 'idle')
        $
          ::  /actions/switch.sig: switch branch locally
          ::
          ::  poke with branch name (text). Reads refs/heads/<branch>,
          ::  updates HEAD + ref, reloads data nexus for checkout.
          ::
          [[%actions ~] %'switch.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo switch: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  branch=@t  (text-from-sage sage)
        ?:  =('' branch)
          ~&  >>>  "%git/repo: switch requires a branch name"
          $
        ::  block if dirty
        ;<  status-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& /data/ui %'status.json'])
        ;<  status-view=view:nexus  bind:m  (peek:io status-rd `[/ %json])
        =/  is-clean=?
          =/  status-json=json  (view-to-json status-view)
          ?.  ?=(%o -.status-json)  %.y
          =/  cl  (~(get by p.status-json) 'clean')
          ?+  cl  %.n
            [~ %b %.y]  %.y
          ==
        ?.  is-clean
          ~&  >>>  "%git/repo: switch blocked — working tree is dirty"
          $
        ::  resolve branch ref
        ;<  ref-hash=@t  bind:m  (resolve-ref branch)
        ?:  =('' ref-hash)
          ~&  >>>  ["%git/repo: branch not found:" branch]
          $
        ~&  >>  ["%git/repo: switching to" branch]
        ;<  ~  bind:m  (set-status 'syncing')
        ;<  ~  bind:m  (write-head (crip "ref: refs/heads/{(trip branch)}"))
        ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
        ;<  ~  bind:m  (reload:io data-rd)
        ;<  ~  bind:m  (set-status 'idle')
        $
          ::  /actions/diff.sig: compute diff for a commit
          ::
          [[%actions ~] %'diff.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo diff: failed")
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
        ;<  commit-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%& /ui %'commit.json'])
        ;<  ~  bind:m  (over:io commit-rd [[/ %json] result])
        $
          ::  /actions/add.sig: stage files into index
          ::
          ::  poke with json: {"all": true} or {"paths": ["/path/one", ...]}
          ::  empty poke = add all
          ::
          [[%actions ~] %'add.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo add: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        ::  parse poke — json with paths/all, or empty sig = add all
        =/  req=json
          =/  j  (mole |.(!<(json q.sage)))
          ?~  j  (pairs:enjs:format ~[['all' b+%.y]])
          ?.  ?=(%o -.u.j)  (pairs:enjs:format ~[['all' b+%.y]])
          u.j
        ~&  >>  "%git/repo: staging files"
        ::  write add-request.json into data nexus
        ;<  req-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%& /data %'add-request.json'])
        ;<  ~  bind:m  (write-repo-file req-rd [[/ %json] req])
        ::  reload data to process add
        ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
        ;<  ~  bind:m  (reload:io data-rd)
        ~&  >>  "%git/repo: files staged"
        $
          ::  /actions/commit.sig: create a local git commit from current tree state
          ::
          [[%actions ~] %'commit.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo commit: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  message=@t  (of-wain:format !<(wain q.sage))
        ?:  =('' message)
          ~&  >>>  "%git/repo commit: empty message"
          $
        ~&  >>  ["%git/repo: committing:" message]
        ;<  cfg=repo-config  bind:m  read-config
        ::  build commit-request.json
        ;<  now=@da  bind:m  get-time:io
        =/  req=json
          %-  pairs:enjs:format
          :~  ['message' s+message]
              ['author_name' s+'grubbery']
              ['author_email' s+'grubbery@urbit.org']
              ['date' s+(scot %da now)]
          ==
        ::  write commit-request.json into data nexus
        ;<  req-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%& /data %'commit-request.json'])
        ;<  ~  bind:m  (write-repo-file req-rd [[/ %json] req])
        ::  reload data to trigger commit creation
        ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
        ;<  ~  bind:m  (reload:io data-rd)
        ~&  >>  "%git/repo: commit created"
        $
          ::  /actions/sync.sig: clone or re-checkout
          ::
          [[%actions ~] %'sync.sig']
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
        ::  discover remote refs
        ;<  disc=discovery:git-transport  bind:m
          (fetch-discovery repo.cfg)
        ~&  >>  ["%git/repo: found" (lent refs.disc) "refs"]
        =?  ref.cfg  =('' ref.cfg)
          (fall (default-branch:git-transport caps.disc) 'main')
        ;<  sync-cfg-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& / %'config.json'])
        ;<  ~  bind:m
          (over:io sync-cfg-rd [[/ %json] (pairs:enjs:format ~[['repo' s+repo.cfg] ['ref' s+ref.cfg] ['token' s+token.cfg]])])
        ::  check if we already have packs (incremental vs full clone)
        ;<  repo-result=(unit repository:git-repo)  bind:m  load-repo-maybe
        ?^  repo-result
          ::  === incremental fetch ===
          ~&  >>  "%git/repo: incremental fetch..."
          =/  repo=repository:git-repo  u.repo-result
          ::  collect all known hashes as haves
          =/  have-hashes=(list @ux)
            %+  roll  archive.object-store.repo
            |=  [=pack:git-pack acc=(list @ux)]
            (weld (turn (tap:pack-on:git-pack index.pack) head) acc)
          =/  have-set=(set @ux)  (silt have-hashes)
          ::  compute wants: remote ref hashes we don't have
          =/  want-hashes=(list @ux)
            %+  murn  refs.disc
            |=  r=git-ref:git-transport
            ?:  (~(has in have-set) hash.r)  ~
            `hash.r
          ?~  want-hashes
            ~&  >>  "%git/repo: already up to date"
            ;<  ~  bind:m  (set-status 'idle')
            ;<  *  bind:m  take-poke:io
            $
          ~&  >>  ["%git/repo: fetching" (lent want-hashes) "new objects"]
          ;<  pack-body=octs  bind:m
            (fetch-pack repo.cfg (build-want:git-transport want-hashes ~['side-band-64k' 'ofs-delta'] ~ have-hashes))
          ~&  >>  ["%git/repo: pack received" p.pack-body "bytes"]
          =/  new-pack-data=octs
            (extract-pack:git-transport pack-body %.y)
          ~&  >>  ["%git/repo: extracted" p.new-pack-data "bytes"]
          ?:  =(0 p.new-pack-data)
            ~&  >>  "%git/repo: empty pack, already up to date"
            ;<  ~  bind:m  (update-refs disc ref.cfg)
            ;<  sync-data-rd=road:tarball  bind:m
              (ancestor-road:io [/git %repo] [%| /data])
            ;<  ~  bind:m  (reload:io sync-data-rd)
            ;<  ~  bind:m  (set-status 'idle')
            ;<  *  bind:m  take-poke:io
            $
          ::  parse new pack to build its index
          =/  new-pack=pack:git-pack
            (read:git-pack (from-octs:bytestream new-pack-data))
          ~&  >>  ["%git/repo: unpacked" count.new-pack "new objects"]
          ::  build index text for new pack
          =/  new-entries=(list [key=hash:git-repo val=@ud])
            (tap:pack-on:git-pack index.new-pack)
          =/  idx-text=tape
            %-  zing
            %+  turn  new-entries
            |=  [key=hash:git-repo val=@ud]
            "{(print-hash-sha-1:git-transport key)} {(a-co:co val)}\0a"
          ::  next pack number = count of existing packs
          =/  pack-num=@ud  (lent archive.object-store.repo)
          ::  extract branch refs
          =/  branch-refs=(list [name=@t hash=hash:git-repo])
            %+  murn  refs.disc
            |=  r=git-ref:git-transport
            ?.  =(`(list @t)`~['refs' 'heads'] (scag 2 refname.r))  ~
            =/  branch-name=@t
              (crip (join:git-transport '/' (turn (slag 2 refname.r) trip)))
            `[branch-name hash.r]
          ::  resolve HEAD
          =/  active-ref=@t  ?:(=('' ref.cfg) 'main' ref.cfg)
          =/  head-hash=@ux
            =/  match=(unit hash:git-repo)
              %-  ~(rep by (malt branch-refs))
              |=  [[name=@t =hash:git-repo] found=(unit hash:git-repo)]
              ?^  found  found
              ?:  =(name active-ref)  `hash
              ~
            (fall match 0x0)
          =/  head-text=@t  (crip (print-hash-sha-1:git-transport head-hash))
          ~&  >>  ["%git/repo: saving as pack-" pack-num]
          ;<  ~  bind:m  (save-repo new-pack-data idx-text pack-num branch-refs head-text active-ref)
          ;<  sync-data-rd=road:tarball  bind:m
            (ancestor-road:io [/git %repo] [%| /data])
          ;<  ~  bind:m  (reload:io sync-data-rd)
          ~&  >>  "%git/repo: incremental fetch complete"
          ;<  ~  bind:m  (set-status 'idle')
          ;<  *  bind:m  take-poke:io
          $
        ::  === full clone ===
        ;<  ~  bind:m  (do-full-clone cfg disc)
        ;<  *  bind:m  take-poke:io
        $
          ::  /actions/push.sig: push files to GitHub via REST API
          ::
          [[%actions ~] %'push.sig']
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
        ;<  ~  bind:m  (set-status 'pushing')
        =/  branch=@t  ?:(=('' ref.cfg) 'main' ref.cfg)
        ::  load repo from namespace
        ;<  repo=repository:git-repo  bind:m  load-repo-from-ns
        =/  sto  store:~(. git-repo repo)
        ::  read local and remote refs
        ;<  local-ref=@t  bind:m  (resolve-ref ref.cfg)
        ;<  remote-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& /data/refs/remotes/origin (crip (trip branch))])
        ;<  remote-view=view:nexus  bind:m  (peek:io remote-rd `[/ %mime])
        =/  remote-ref=@t
          ?.  ?=([%file *] remote-view)  ''
          =/  mim=mime  !<(mime (need-vase:tarball sang.remote-view))
          (crip (trip q.q.mim))
        ?:  =(local-ref remote-ref)
          ~&  >>  "%git/repo push: nothing to push"
          ;<  ~  bind:m  (set-status 'idle')
          $
        ::  parse hashes
        =/  local-hash=(unit @ux)
          (rust (trip local-ref) parse-hash-sha-1:git-transport)
        ?~  local-hash
          ~&  >>>  "%git/repo push: invalid local ref"
          ;<  ~  bind:m  (set-status 'idle')
          $
        =/  remote-hash=@ux
          ?:  =('' remote-ref)  0x0
          (fall (rust (trip remote-ref) parse-hash-sha-1:git-transport) 0x0)
        ::  walk commits from local back to remote, collect chain
        =/  chain=(list hash:git-repo)
          =|  acc=(list hash:git-repo)
          =/  h=hash:git-repo  u.local-hash
          |-
          ?:  =(h remote-hash)  acc
          ?:  =(h 0x0)  acc
          =/  com=(unit commit:git-repo)  (get-commit:sto h)
          ?~  com  acc
          =/  new-acc=(list hash:git-repo)  [h acc]
          ?~  parents.u.com  new-acc
          $(h i.parents.u.com, acc new-acc)
        ?~  chain
          ~&  >>  "%git/repo push: no new commits"
          ;<  ~  bind:m  (set-status 'idle')
          $
        ~&  >>  ["%git/repo push:" (lent chain) "commits to push"]
        ::  push each commit via GitHub API
        =/  api=@t  'https://api.github.com'
        =/  headers=(list [key=@t value=@t])  (gh-headers token.cfg)
        =/  parent-sha=@t  remote-ref
        =/  get-tree=$-(@ux (unit tree-dir:git-repo))
          |=(h=@ux (get-tree:sto h))
        =/  get-blob=$-(@ux (unit octs))
          |=(h=@ux (get-blob:sto h))
        =/  remaining=(list hash:git-repo)  chain
        |-
        ?~  remaining
          ::  all commits pushed — update remote ref on GitHub
          =/  update-url=@t
            (cat 3 api (cat 3 '/repos/' (cat 3 repo.cfg (cat 3 '/git/refs/heads/' branch))))
          =/  update-body=json
            (pairs:enjs:format ~[['sha' s+parent-sha] ['force' b+%.n]])
          ;<  *  bind:m  (gh-patch update-url headers update-body)
          ~&  >>  ["%git/repo push: updated" branch "to" (crip (scag 7 (trip parent-sha)))]
          ::  update local remote tracking ref
          ;<  track-rd=road:tarball  bind:m
            (ancestor-road:io [/git %repo] [%& /data/refs/remotes/origin (crip (trip branch))])
          =/  track-octs=octs  (as-octt:bytestream (trip parent-sha))
          ;<  ~  bind:m  (write-repo-file track-rd [[/ %mime] [/text/plain track-octs]])
          ::  reload data to refresh UI
          ;<  data-rd=road:tarball  bind:m
            (ancestor-road:io [/git %repo] [%| /data])
          ;<  ~  bind:m  (reload:io data-rd)
          ;<  ~  bind:m  (set-status 'idle')
          ~&  >>  "%git/repo push: done"
          ^$
        ::  push current commit
        =/  commit-hash=hash:git-repo  i.remaining
        =/  com=(unit commit:git-repo)  (get-commit:sto commit-hash)
        ?~  com
          ~&  >>>  ["%git/repo push: commit not found" commit-hash]
          ;<  ~  bind:m  (set-status 'idle')
          ^$
        ~&  >>  ["%git/repo push: pushing" (crip (scag 7 (print-hash-sha-1:git-transport commit-hash)))]
        ::  get tree changes: diff parent tree vs this commit's tree
        =/  parent-tree=@ux
          ?~  parents.u.com  0x0
          =/  par=(unit commit:git-repo)  (get-commit:sto i.parents.u.com)
          ?~  par  0x0
          tree.u.par
        =/  changes=(list tree-change:git-transport)
          ?:  =(0x0 parent-tree)
            ::  first commit: all files are additions
            =/  top-tree=(unit tree-dir:git-repo)  (get-tree tree.u.com)
            ?~  top-tree  ~
            %+  turn  (all-blobs:git-transport get-tree / u.top-tree)
            |=([p=path h=@ux] `tree-change:git-transport`[%add p h])
          (diff-trees:git-transport get-tree parent-tree tree.u.com)
        ::  create blobs on GitHub for added/modified files
        =/  blob-url=@t
          (cat 3 api (cat 3 '/repos/' (cat 3 repo.cfg '/git/blobs')))
        =|  tree-entries=(list json)
        =/  changes-remaining=(list tree-change:git-transport)  changes
        |-
        ?~  changes-remaining
          ::  create tree on GitHub
          ::  get parent tree SHA — use GitHub's version
          ;<  parent-commit-resp=json  bind:m
            ?:  =('' parent-sha)
              =/  mj  (fiber:fiber:nexus ,json)
              (pure:mj *json)
            (gh-get (cat 3 api (cat 3 '/repos/' (cat 3 repo.cfg (cat 3 '/git/commits/' parent-sha)))) headers)
          =/  base-tree-sha=(unit @t)
            ?.  ?=(%o -.parent-commit-resp)  ~
            =/  tree  (~(get by p.parent-commit-resp) 'tree')
            ?.  ?=([~ %o *] tree)  ~
            =/  sha  (~(get by p.u.tree) 'sha')
            ?.  ?=([~ %s *] sha)  ~
            `p.u.sha
          =/  tree-pairs=(list [@t json])
            :~  ['tree' [%a (flop tree-entries)]]
            ==
          =/  tree-pairs=(list [@t json])
            ?~  base-tree-sha  tree-pairs
            [['base_tree' s+u.base-tree-sha] tree-pairs]
          =/  tree-body=json
            (pairs:enjs:format tree-pairs)
          =/  tree-url=@t
            (cat 3 api (cat 3 '/repos/' (cat 3 repo.cfg '/git/trees')))
          ;<  tree-resp=json  bind:m  (gh-post tree-url headers tree-body)
          ?.  ?=(%o -.tree-resp)
            ~|  "%git/repo push: tree create failed"  !!
          =/  new-tree-sha=@t  (get-sha tree-resp)
          ::  create commit on GitHub
          =/  commit-body=json
            %-  pairs:enjs:format
            :~  ['message' s+(crip message.u.com)]
                ['tree' s+new-tree-sha]
                ['parents' [%a ?:(=('' parent-sha) ~ ~[s+parent-sha])]]
                :-  'author'
                %-  pairs:enjs:format
                :~  ['name' s+(crip name.author.u.com)]
                    ['email' s+(crip email.author.u.com)]
                    ['date' s+(timestamp-iso date.author-time.u.com)]
                ==
                :-  'committer'
                %-  pairs:enjs:format
                :~  ['name' s+(crip name.committer.u.com)]
                    ['email' s+(crip email.committer.u.com)]
                    ['date' s+(timestamp-iso date.commit-time.u.com)]
                ==
            ==
          =/  commit-url=@t
            (cat 3 api (cat 3 '/repos/' (cat 3 repo.cfg '/git/commits')))
          ;<  commit-resp=json  bind:m  (gh-post commit-url headers commit-body)
          ?.  ?=(%o -.commit-resp)
            ~|  "%git/repo push: commit create failed"  !!
          =/  new-sha=@t  (get-sha commit-resp)
          ~&  >>  ["%git/repo push: created" (crip (scag 7 (trip new-sha)))]
          ^$(remaining t.remaining, parent-sha new-sha)
        ::  process current change
        =/  change=tree-change:git-transport  i.changes-remaining
        ?-    -.change
            %del
          ::  delete: add entry with sha null
          =/  entry=json
            %-  pairs:enjs:format
            :~  ['path' s+(path-to-github path.change)]
                ['mode' s+'100644']
                ['type' s+'blob']
                ['sha' ~]
            ==
          $(changes-remaining t.changes-remaining, tree-entries [entry tree-entries])
        ::
            %add
          =/  blob-data=(unit octs)  (get-blob hash.change)
          ?~  blob-data
            $(changes-remaining t.changes-remaining)
          =/  blob-body=json
            %-  pairs:enjs:format
            :~  ['content' s+(crip (trip q.u.blob-data))]
                ['encoding' s+'utf-8']
            ==
          ;<  blob-resp=json  bind:m  (gh-post blob-url headers blob-body)
          ?.  ?=(%o -.blob-resp)
            ~|  "%git/repo push: blob create failed"  !!
          =/  entry=json
            %-  pairs:enjs:format
            :~  ['path' s+(path-to-github path.change)]
                ['mode' s+'100644']
                ['type' s+'blob']
                ['sha' s+(get-sha blob-resp)]
            ==
          $(changes-remaining t.changes-remaining, tree-entries [entry tree-entries])
        ::
            %mod
          =/  blob-data=(unit octs)  (get-blob new.change)
          ?~  blob-data
            $(changes-remaining t.changes-remaining)
          =/  blob-body=json
            %-  pairs:enjs:format
            :~  ['content' s+(crip (trip q.u.blob-data))]
                ['encoding' s+'utf-8']
            ==
          ;<  blob-resp=json  bind:m  (gh-post blob-url headers blob-body)
          ?.  ?=(%o -.blob-resp)
            ~|  "%git/repo push: blob create failed"  !!
          =/  entry=json
            %-  pairs:enjs:format
            :~  ['path' s+(path-to-github path.change)]
                ['mode' s+'100644']
                ['type' s+'blob']
                ['sha' s+(get-sha blob-resp)]
            ==
          $(changes-remaining t.changes-remaining, tree-entries [entry tree-entries])
        ==
      ==
    --
::
|%
::
+$  repo-config
  $:  repo=@t
      ref=@t
      token=@t
  ==
::
++  read-config
  =/  m  (fiber:fiber:nexus ,repo-config)
  ^-  form:m
  ;<  road=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%& / %'config.json'])
  ;<  =view:nexus  bind:m  (peek:io road `[/ %json])
  ?.  ?=([%file *] view)
    (pure:m ['' 'main' ''])
  =/  cfg=json  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) *json)
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
  |=  [=road:tarball =bask:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    (over:io road bask)
  (make:io road |+[bask ~])
::
::  +do-full-clone: full clone from discovery
::
++  do-full-clone
  |=  [cfg=repo-config disc=discovery:git-transport]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ~&  >>  "%git/repo: full clone..."
  ~&  >>  "%git/repo: fetching pack..."
  =/  want-hashes=(list @ux)
    (turn refs.disc |=(r=git-ref:git-transport hash.r))
  ;<  pack-body=octs  bind:m
    (fetch-pack repo.cfg (build-want:git-transport want-hashes ~['side-band-64k' 'ofs-delta'] ~ ~))
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
  ::  extract branch refs
  =/  branch-refs=(list [name=@t hash=hash:git-repo])
    %+  murn  refs.disc
    |=  r=git-ref:git-transport
    ?.  =(`(list @t)`~['refs' 'heads'] (scag 2 refname.r))  ~
    =/  branch-name=@t
      (crip (join:git-transport '/' (turn (slag 2 refname.r) trip)))
    `[branch-name hash.r]
  ::  resolve HEAD hash
  =/  active-ref=@t  ?:(=('' ref.cfg) 'main' ref.cfg)
  =/  ref-hash=(unit @ux)
    =+  got=(get:refs:~(. git-repo repo) ~[active-ref])
    ?^  got  got
    (get:refs:~(. git-repo repo) ~['refs' 'heads' active-ref])
  =/  head-hash=@ux  (fall ref-hash 0x0)
  =/  head-text=@t  (crip (print-hash-sha-1:git-transport head-hash))
  ~&  >>  "%git/repo: saving to data nexus"
  ::  clear old packs before writing fresh clone
  ;<  packs-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data/packs])
  ;<  *  bind:m  (cull-soft:io packs-rd)
  ;<  ~  bind:m  (save-repo pack-data idx-text 0 branch-refs head-text active-ref)
  ;<  sync-data-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%| /data])
  ;<  ~  bind:m  (reload:io sync-data-rd)
  ~&  >>  "%git/repo: clone complete"
  (set-status 'idle')
::
::  +update-refs: write updated remote refs without touching pack
::
++  update-refs
  |=  [disc=discovery:git-transport active-ref=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  branch-refs=(list [name=@t hash=hash:git-repo])
    %+  murn  refs.disc
    |=  r=git-ref:git-transport
    ?.  =(`(list @t)`~['refs' 'heads'] (scag 2 refname.r))  ~
    =/  branch-name=@t
      (crip (join:git-transport '/' (turn (slag 2 refname.r) trip)))
    `[branch-name hash.r]
  |-
  ?~  branch-refs  (pure:m ~)
  =/  hash-text=tape  (print-hash-sha-1:git-transport hash.i.branch-refs)
  =/  hash-octs=octs  (as-octt:bytestream hash-text)
  =/  bname=@ta  (crip (trip name.i.branch-refs))
  ;<  remote-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data/refs/remotes/origin bname])
  ;<  ~  bind:m  (write-repo-file remote-rd [[/ %mime] [/text/plain hash-octs]])
  $(branch-refs t.branch-refs)
::
::  +save-repo: write pack + index + refs + HEAD into repo sub-nexus
::
::  pack-num is the pack slot to write (0 for full clone, N for incremental)
::
++  save-repo
  |=  $:  pack-data=octs
          idx-text=tape
          pack-num=@ud
          branch-refs=(list [name=@t hash=hash:git-repo])
          head-text=@t
          ref-name=@t
      ==
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  idx-octs=octs  (as-octt:bytestream idx-text)
  =/  pack-name=@ta  (crip "pack-{(a-co:co pack-num)}.pack")
  =/  idx-name=@ta  (crip "pack-{(a-co:co pack-num)}.idx")
  ::  HEAD = "ref: refs/heads/<branch>"
  =/  head-octs=octs  (as-octt:bytestream "ref: refs/heads/{(trip ref-name)}")
  ;<  rd1=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%& /data/packs pack-name])
  ;<  ~  bind:m  (write-repo-file rd1 [[/ %mime] [/application/octet-stream pack-data]])
  ;<  rd2=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%& /data/packs idx-name])
  ;<  ~  bind:m  (write-repo-file rd2 [[/ %mime] [/text/plain idx-octs]])
  ;<  rd4=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%& /data %'HEAD'])
  ;<  ~  bind:m  (write-repo-file rd4 [[/ %mime] [/text/plain head-octs]])
  ::  write individual ref files — both local and remote tracking
  |-
  ?~  branch-refs  (pure:m ~)
  =/  hash-text=tape  (print-hash-sha-1:git-transport hash.i.branch-refs)
  =/  hash-octs=octs  (as-octt:bytestream hash-text)
  =/  bname=@ta  (crip (trip name.i.branch-refs))
  ;<  head-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data/refs/heads bname])
  ;<  ~  bind:m  (write-repo-file head-rd [[/ %mime] [/text/plain hash-octs]])
  ;<  remote-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data/refs/remotes/origin bname])
  ;<  ~  bind:m  (write-repo-file remote-rd [[/ %mime] [/text/plain hash-octs]])
  $(branch-refs t.branch-refs)
::
::  +write-head: update HEAD in repo sub-nexus
::
::    For a branch: writes "ref: refs/heads/<branch>"
::    For detached: writes raw commit hash
::
++  write-head
  |=  value=@t
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  head-octs=octs  (as-octt:bytestream (trip value))
  ;<  rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%& /data %'HEAD'])
  (over:io rd [[/ %mime] [/text/plain head-octs]])
::
::  +resolve-head: read HEAD, follow ref if symbolic, return commit hash
::
++  resolve-head
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  head-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data %'HEAD'])
  ;<  head-view=view:nexus  bind:m  (peek:io head-rd `[/ %mime])
  ?.  ?=([%file *] head-view)
    (pure:m '')
  =/  head-mim=mime  !<(mime (need-vase:tarball sang.head-view))
  =/  head-text=tape  (trip q.q.head-mim)
  ?.  =("ref: " (scag 5 head-text))
    ::  raw hash (detached HEAD)
    (pure:m (crip head-text))
  ::  symbolic ref — extract branch and resolve
  =/  ref-path=tape  (slag 5 head-text)
  =/  branch=@t
    ?.  =("refs/heads/" (scag 11 ref-path))
      (crip ref-path)
    (crip (slag 11 ref-path))
  (resolve-ref branch)
::
::  +read-head-branch: return current branch name, or '' if detached
::
++  read-head-branch
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  head-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data %'HEAD'])
  ;<  head-view=view:nexus  bind:m  (peek:io head-rd `[/ %mime])
  ?.  ?=([%file *] head-view)
    (pure:m '')
  =/  head-mim=mime  !<(mime (need-vase:tarball sang.head-view))
  =/  head-text=tape  (trip q.q.head-mim)
  ?.  =("ref: " (scag 5 head-text))
    (pure:m '')
  =/  ref-path=tape  (slag 5 head-text)
  ?.  =("refs/heads/" (scag 11 ref-path))
    (pure:m (crip ref-path))
  (pure:m (crip (slag 11 ref-path)))
::
::  +resolve-ref: read ref hash from refs/heads/<branch>
::
++  resolve-ref
  |=  ref=@t
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  =/  active=@ta  ?:(=('' ref) 'main' (crip (trip ref)))
  ;<  road=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data/refs/heads active])
  ;<  =view:nexus  bind:m  (peek:io road `[/ %mime])
  ?.  ?=([%file *] view)
    ~&  >>>  ["%git/repo: ref not found:" active]
    (pure:m '')
  =/  mim=mime  !<(mime (need-vase:tarball sang.view))
  (pure:m (crip (trip q.q.mim)))
::
++  set-status
  |=  s=@t
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%& /ui %'status.json'])
  (over:io rd [[/ %json] (pairs:enjs:format ~[['status' s+s]])])
::
::  +load-repo-maybe: rebuild repository from ./data/ if packs exist
::
::  Returns ~ if no packs found (triggers full clone).
::
++  load-repo-maybe
  =/  m  (fiber:fiber:nexus ,(unit repository:git-repo))
  ^-  form:m
  ;<  packs-road=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data/packs])
  ;<  packs-view=view:nexus  bind:m  (peek:io packs-road ~)
  ?.  ?=([%ball *] packs-view)  (pure:m ~)
  =/  archive=(list pack:git-pack)
    (load-packs-from-ball ball.packs-view)
  ?~  archive  (pure:m ~)
  ;<  heads-road=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%| /data/refs/heads])
  ;<  heads-view=view:nexus  bind:m  (peek:io heads-road ~)
  =/  built-refs=(axal ref:git-repo)
    ?.  ?=([%ball *] heads-view)  [~ ~]
    (refs-from-ball ball.heads-view ~['refs' 'heads'])
  ;<  obj-road=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data/objects])
  ;<  obj-view=view:nexus  bind:m  (peek:io obj-road ~)
  =/  loose=(map hash:git-repo object:git-obj)
    ?.  ?=([%ball *] obj-view)  ~
    (read-loose-from-ball ball.obj-view)
  =/  repo=repository:git-repo
    [%sha-1 [loose archive] built-refs ~ ~]
  (pure:m `repo)
::
::  +load-repo-from-ns: rebuild git repository from ./data/ namespace files
::
++  load-repo-from-ns
  =/  m  (fiber:fiber:nexus ,repository:git-repo)
  ^-  form:m
  ;<  result=(unit repository:git-repo)  bind:m  load-repo-maybe
  ?~  result  ~|("%git/repo: no pack data" !!)
  (pure:m u.result)
::
::  +refs-from-ball: read ref files from a ball directory into axal
::
++  refs-from-ball
  |=  [=ball:tarball prefix=path]
  ^-  (axal ref:git-repo)
  ?~  fil.ball  [~ ~]
  %+  roll  ~(tap by contents.u.fil.ball)
  |=  [[name=@t =sang:tarball gain=? bang=(unit tang)] r=(axal ref:git-repo)]
  =/  m=mime  !<(mime (need-vase:tarball sang))
  ?:  =(0 p.q.m)  r
  =/  h=(unit @ux)
    (rust (trip q.q.m) parse-hash-sha-1:git-transport)
  ?~  h  r
  (~(put of r) [(weld prefix ~[name]) u.h])
::
++  read-loose-from-ball
  |=  =ball:tarball
  ^-  (map hash:git-repo object:git-obj)
  ?~  fil.ball  ~
  =/  entries=(list [name=@t =sang:tarball gain=? bang=(unit tang)])
    ~(tap by contents.u.fil.ball)
  %+  roll  entries
  |=  [[name=@t =sang:tarball gain=? bang=(unit tang)] acc=(map hash:git-repo object:git-obj)]
  =/  h=(unit hash:git-repo)
    (rust (trip name) parse-hash-sha-1:git-transport)
  ?~  h  acc
  =/  m=mime  !<(mime (need-vase:tarball sang))
  =/  raw=raw-object:git-obj  (raw-from-octs:git-obj q.m)
  =/  obj=object:git-obj  (parse-raw:git-obj %sha-1 raw)
  (~(put by acc) u.h obj)
::
::  +load-packs-from-ball: read all pack-N.pack + pack-N.idx pairs from a packs ball
::
++  load-packs-from-ball
  |=  =ball:tarball
  ^-  (list pack:git-pack)
  ?~  fil.ball  ~
  =/  all-files=(list @ta)  ~(tap in ~(key by contents.u.fil.ball))
  =/  pack-nums=(list @ud)
    %+  murn  all-files
    |=  name=@ta
    =/  t=tape  (trip name)
    ?.  =("pack-" (scag 5 t))  ~
    ?.  =(".pack" (slag (sub (lent t) 5) t))  ~
    =/  num-text=tape  (slag 5 (scag (sub (lent t) 5) t))
    (rust num-text dem)
  =/  sorted=(list @ud)  (sort pack-nums lth)
  %+  murn  sorted
  |=  n=@ud
  ^-  (unit pack:git-pack)
  =/  pack-name=@ta  (crip "pack-{(a-co:co n)}.pack")
  =/  idx-name=@ta  (crip "pack-{(a-co:co n)}.idx")
  =/  pack-content=(unit [=sang:tarball gain=? bang=(unit tang)])
    (~(get by contents.u.fil.ball) pack-name)
  =/  idx-content=(unit [=sang:tarball gain=? bang=(unit tang)])
    (~(get by contents.u.fil.ball) idx-name)
  ?~  pack-content  ~
  ?~  idx-content  ~
  =/  pack-mim=mime  !<(mime (need-vase:tarball sang.u.pack-content))
  ?:  =(0 p.q.pack-mim)  ~
  =/  idx-mim=mime  !<(mime (need-vase:tarball sang.u.idx-content))
  =/  idx-text=tape  (trip q.q.idx-mim)
  =/  idx=pack-index:git-pack
    (rebuild-index (split:git-transport idx-text `@t`10))
  =/  sea=bays:bytestream  (from-octs:bytestream q.pack-mim)
  =/  entries=(list [key=hash:git-repo val=@ud])
    (tap:pack-on:git-pack idx)
  `[%sha-1 (lent entries) idx p.q.pack-mim sea]
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
  ~&  >  ["%git/repo: HTTP" method.request url.request]
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.client-response)
    ~|  "%git/repo: request failed (not finished)"  !!
  =/  status  status-code.response-header.client-response
  ~&  >  ["%git/repo: HTTP response" status]
  ?:  ?|  =(status 301)
          =(status 302)
          =(status 307)
      ==
    =/  location=(unit @t)
      (~(get by (malt headers.response-header.client-response)) 'location')
    ?~  location
      ~|  "%git/repo: redirect without location header"  !!
    ~&  >  ["%git/repo: following redirect to" u.location]
    =/  redir=request:http
      [%'GET' u.location ~[['User-Agent' 'grubbery']] ~]
    ;<  ~  bind:m  (send-request:io redir)
    ;<  =client-response:iris  bind:m  take-client-response:io
    ?.  ?=(%finished -.client-response)
      ~|  "%git/repo: redirect failed"  !!
    ?.  =(200 status-code.response-header.client-response)
      ~&  >>>  ["%git/repo: redirect status" status-code.response-header.client-response]
      ~|  "%git/repo: non-200 after redirect"  !!
    ?~  full-file.client-response
      ~|  "%git/repo: empty response after redirect"  !!
    (pure:m data.u.full-file.client-response)
  ?.  =(200 status)
    ~&  >>>  ["%git/repo: HTTP failed" status method.request url.request]
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
::  +get-sha: extract 'sha' string from a GitHub API JSON object
::
++  get-sha
  |=  =json
  ^-  @t
  ?>  ?=(%o -.json)
  =/  sha  (~(get by p.json) 'sha')
  ?>  ?=([~ %s *] sha)
  p.u.sha
::  +timestamp-iso: convert @da to ISO 8601 string for GitHub API
::
++  timestamp-iso
  |=  d=@da
  ^-  @t
  =/  dt=date  (yore d)
  =/  y=@ud  y.dt
  =/  mo=@ud  m.dt
  =/  da=@ud  d.t.dt
  =/  h=@ud  h.t.dt
  =/  mi=@ud  m.t.dt
  =/  s=@ud  s.t.dt
  %-  crip
  "{(a-co:co y)}-{(pad mo)}-{(pad da)}T{(pad h)}:{(pad mi)}:{(pad s)}Z"
::  +pad: zero-pad a number to 2 digits
::
++  pad
  |=  n=@ud
  ^-  tape
  ?:((lth n 10) "0{(a-co:co n)}" (a-co:co n))
::  +path-to-github: convert urbit path to GitHub-style path string
::  /foo/bar/txt -> foo/bar/txt (strips leading /)
::
++  path-to-github
  |=  pax=path
  ^-  @t
  =/  t=tape  (trip (spat pax))
  ?~  t  ''
  ?:(=('/' i.t) (crip t.t) (crip t))
::
+$  page-event
  $%  [%news =wire =wave:nexus]
      [%fell =wire]
  ==
::
++  take-page-event
  =/  m  (fiber:fiber:nexus ,page-event)
  ^-  form:m
  |=  =input:fiber:nexus
  :+  ~  q.state.input
  ?+  in.input  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    [%done %news [wire wave]:u.in.input]
      [~ %fell *]
    [%done %fell wire.u.in.input]
  ==
::
++  view-to-config
  |=  =view:nexus
  ^-  repo-config
  ?.  ?=([%file *] view)  ['' 'main' '']
  =/  cfg=json  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) *json)
  ?.  ?=(%o -.cfg)  ['' 'main' '']
  =/  get
    |=  [key=@t default=@t]
    ^-  @t
    =/  v  (~(get by p.cfg) key)
    ?.  ?=([~ %s *] v)  default
    ?:(=('' p.u.v) default p.u.v)
  [(get 'repo' '') (get 'ref' '') (get 'token' '')]
::  +text-from-sage: extract text from a poke sage (wain or mime)
::
++  text-from-sage
  |=  =sage:tarball
  ^-  @t
  ?:  =([/ %mime] p.sage)
    q.q:!<(mime q.sage)
  (of-wain:format !<(wain q.sage))
::
++  view-to-branches
  |=  =view:nexus
  ^-  (list @t)
  ?.  ?=([%file *] view)  ~
  =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) *json)
  ?.  ?=(%a -.j)  ~
  (murn p.j |=(v=json ?.(?=(%s -.v) ~ `p.v)))
::
++  view-to-json
  |=  =view:nexus
  ^-  json
  ?.  ?=([%file *] view)  [%a ~]
  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) [%a ~])
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
      ".status-bar\{display:none;align-items:center;gap:6px;"
      "padding:4px 12px;border-bottom:1px solid #e0e0e0;"
      "background:#fffbeb;font-size:12px;flex-shrink:0;cursor:pointer}"
      ".status-bar:hover\{background:#fef3c7}"
      ".status-bar.dirty,.status-bar.sync\{display:flex}"
      ".status-bar .staged\{color:#1a7f37;font-weight:500}"
      ".status-bar .unstaged\{color:#9a6700;font-weight:500}"
      ".status-bar .untracked\{color:#656d76;font-weight:500}"
      ".status-bar .ahead-behind\{opacity:.6;font-size:11px}"
      ".status-bar .files\{opacity:.6;font-size:11px}"
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
      "fetch(A.replace('/file/','/over/')+'/config.json?blot=/json',"
      "\{method:'POST',headers:\{'Content-Type':'application/json'},"
      "body:JSON.stringify(\{repo:r,ref:f})})"
      ".then(function()\{"
      "return fetch(A.replace('/file/','/poke/')+'/actions/sync.sig',"
      "\{method:'POST',headers:\{'Content-Type':'text/plain'},body:'sync'})"
      "}).catch(function()\{"
      "if(btn)\{btn.disabled=false}"
      "})}"
      ::  branch switch: local only — just poke switch.sig
      "function doSwitch()\{"
      "var sel=document.getElementById('ref');"
      "var f=sel?(sel.value||''):(''||'');"
      "if(!f)\{return}"
      "if(sel)\{sel.disabled=true}"
      "fetch(A.replace('/file/','/poke/')+'/actions/switch.sig',"
      "\{method:'POST',headers:\{'Content-Type':'text/plain'},body:f})"
      ".catch(function()\{"
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
      "fetch(SK+'?blot=/json',\{headers:\{Accept:'text/event-stream'}})"
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
      "fetch(K+'?blot=/txt',\{headers:\{Accept:'text/event-stream'}})"
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
      "var CI=window._CURRENT||\{hash:'',branch:'',remote:''};"
      "var cur=CI.hash||window._COMMITS[0].hash;"
      "var curCommit=window._COMMITS.find(function(c)\{return c.hash===cur})||window._COMMITS[0];"
      "var hb=document.getElementById('head-bar');"
      "if(hb)\{"
      "var headRefs=(curCommit.refs||[]).filter(function(r)\{return r!=='HEAD'});"
      "var refTxt=headRefs.length?' <span style=\"font-size:10px;opacity:.5\">"
      "'+headRefs.map(function(r)\{return r.replace('refs/heads/','').replace('refs/remotes/','')}).join(', ')+'</span>':'';"
      "hb.innerHTML='<span class=\"badge\">HEAD</span>"
      "<span class=\"hash\">'+curCommit.short+'</span>"
      "<span class=\"msg\">'+curCommit.message+'</span>'+refTxt;"
      "hb.onclick=function()\{showCommitPopup(curCommit)}}"
      "function refBadges(refs)\{"
      "if(!refs||!refs.length)return '';"
      "return refs.filter(function(r)\{return r!=='HEAD'}).map(function(r)\{"
      "var label=r.replace('refs/heads/','').replace('refs/remotes/','');"
      "var bg=r.indexOf('remotes')>=0?'#0969da':'#6e40c9';"
      "return '<span style=\"background:'+bg+';color:#fff;font-size:9px;"
      "padding:0 3px;border-radius:2px;margin-left:4px\">'+label+'</span>'"
      "}).join('')}"
      "window._COMMITS.forEach(function(c,i)\{"
      "var d=document.createElement('div');"
      "var isHead=(c.refs||[]).indexOf('HEAD')>=0;"
      "d.className='commit-entry'+(isHead?' head':'');"
      "d.innerHTML='<span class=\"hash\">'+c.short+'</span>'"
      "+refBadges(c.refs)+"
      "'<span class=\"msg\">'+c.message+'</span>"
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
      "fetch(A.replace('/file/','/poke/')+'/actions/checkout.sig?blot=/txt',"
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
      ::  status bar + popup
      "function renderStatus()\{"
      "var sb=document.getElementById('status-bar');"
      "if(!sb||!window._STATUS)return;"
      "var s=window._STATUS;"
      "if(s.clean&&!s.ahead&&!s.behind)\{sb.className='status-bar';sb.innerHTML='';return}"
      "sb.className=s.clean?'status-bar sync':'status-bar dirty';"
      "var ns=s.staged?s.staged.length:0;"
      "var nu=s.unstaged?s.unstaged.length:0;"
      "var nt=s.untracked?s.untracked.length:0;"
      "var parts=[];"
      "if(ns)parts.push('<span class=\"staged\">'+ns+' staged</span>');"
      "if(nu)parts.push('<span class=\"unstaged\">'+nu+' modified</span>');"
      "if(nt)parts.push('<span class=\"untracked\">'+nt+' untracked</span>');"
      "var h=parts.join(' | ');"
      "if(s.ahead||s.behind)\{"
      "h+='<span class=\"ahead-behind\">';"
      "if(s.ahead)h+=' \\u2191'+s.ahead;"
      "if(s.behind)h+=' \\u2193'+s.behind;"
      "h+='</span>'}"
      "sb.innerHTML=h;sb.onclick=showStatusPopup}"
      "function showStatusPopup()\{"
      "var s=window._STATUS;if(!s)return;"
      "var CI=window._CURRENT||\{hash:'',branch:'',remote:''};"
      "var bg=document.createElement('div');"
      "bg.className='commit-popup';"
      "var h='<div class=\"card\">';"
      "h+='<button class=\"close\">&times;</button>';"
      "h+='<h3>status</h3>';"
      "h+='<table class=\"meta\">';"
      "h+='<tr><td>branch</td><td><b>'+CI.branch+'</b></td></tr>';"
      "if(CI.remote)\{"
      "h+='<tr><td>remote</td><td><code>'+CI.remote.slice(0,7)+'</code>';"
      "if(s.ahead)h+=' \\u2191'+s.ahead;"
      "if(s.behind)h+=' \\u2193'+s.behind;"
      "h+='</td></tr>'}"
      "h+='</table>';"
      ::  staged files
      "if(s.staged&&s.staged.length)\{"
      "h+='<div style=\"margin:.75rem 0 .25rem;font-size:12px;font-weight:600;"
      "color:#1a7f37\">Staged ('+s.staged.length+')</div>';"
      "h+='<div style=\"font-size:12px;font-family:monospace\">';"
      "s.staged.forEach(function(f)\{"
      "var bc=f.status==='new'?'badge-add':f.status==='deleted'?'badge-del':'badge-mod';"
      "h+='<div style=\"padding:2px 0\"><span class=\"badge '+bc+"
      "'\" style=\"font-size:10px;padding:0 4px;border-radius:3px;"
      "color:#fff;margin-right:6px\">'+f.status+'</span>'+f.path+'</div>'});"
      "h+='</div>'}"
      ::  unstaged files
      "if(s.unstaged&&s.unstaged.length)\{"
      "h+='<div style=\"margin:.75rem 0 .25rem;font-size:12px;font-weight:600;"
      "color:#9a6700\">Unstaged ('+s.unstaged.length+')</div>';"
      "h+='<div style=\"font-size:12px;font-family:monospace\">';"
      "s.unstaged.forEach(function(f)\{"
      "var bc=f.status==='new'?'badge-add':f.status==='deleted'?'badge-del':'badge-mod';"
      "h+='<div style=\"padding:2px 0\"><span class=\"badge '+bc+"
      "'\" style=\"font-size:10px;padding:0 4px;border-radius:3px;"
      "color:#fff;margin-right:6px\">'+f.status+'</span>'+f.path+'</div>'});"
      "h+='</div>'}"
      ::  untracked files
      "if(s.untracked&&s.untracked.length)\{"
      "h+='<div style=\"margin:.75rem 0 .25rem;font-size:12px;font-weight:600;"
      "color:#656d76\">Untracked ('+s.untracked.length+')</div>';"
      "h+='<div style=\"font-size:12px;font-family:monospace\">';"
      "s.untracked.forEach(function(f)\{"
      "h+='<div style=\"padding:2px 0\"><span class=\"badge badge-add\""
      " style=\"font-size:10px;padding:0 4px;border-radius:3px;"
      "color:#fff;margin-right:6px\">new</span>'+f.path+'</div>'});"
      "h+='</div>'}"
      ::  clean state
      "if(s.clean)h+='<div style=\"padding:1rem;opacity:.4;text-align:center\">"
      "working tree clean</div>';"
      "h+='</div>';"
      "bg.innerHTML=h;"
      "bg.querySelector('.close').onclick=function()\{bg.remove()};"
      "bg.onclick=function(e)\{if(e.target===bg)bg.remove()};"
      "document.body.appendChild(bg)}"
      "renderStatus();"
      ::  diff view: poke commit.sig, watch commit.json, render
      "function viewCommitDiff(hash)\{"
      "document.querySelectorAll('.file.active').forEach("
      "function(e)\{e.classList.remove('active')});"
      "var pane=document.getElementById('content');"
      "pane.innerHTML='<div class=\"placeholder\">"
      "<span class=\"spinner\"></span> computing diff...</div>';"
      "fetch(A.replace('/file/','/poke/')+'/actions/diff.sig?blot=/txt',"
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
      "fetch(CK+'?blot=/json',\{headers:\{Accept:'text/event-stream'}})"
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
  |=  [api=@t repo=@t ref=@t branches=(list @t) files=(list @t) commits=json current=json status=json]
  =/  cur-branch=@t
    ?.  ?=(%o -.current)  ref
    =/  v=(unit json)  (~(get by p.current) 'branch')
    ?.  ?=([~ %s *] v)  ref
    ?:(=('' p.u.v) ref p.u.v)
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
                          ?:  =(b cur-branch)
                            ;option(value "{(trip b)}", selected ""): {(trip b)}
                          ;option(value "{(trip b)}"): {(trip b)}
                    ==
                    ;button.btn(id "fetch-btn", title "Fetch from remote"): ↻
                    ;span.info: {(scow %ud (lent files))} files
                  ==
                  ;div.head-bar(id "head-bar");
                  ;div.status-bar(id "status-bar");
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
        ;+  ;/  (status-json status)
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
++  clean-status
  ^-  json
  (pairs:enjs:format ~[['clean' b+%.y] ['staged' [%a ~]] ['unstaged' [%a ~]]])
::
++  status-json
  |=  j=json
  ^-  tape
  =/  raw=tape  (trip (en:json:html j))
  "window._STATUS={raw};"
::
++  current-json
  |=  j=json
  ^-  tape
  ?.  ?=(%o -.j)  "window._CURRENT=\{hash:'',branch:'',remote:''};"
  =/  get
    |=  key=@t
    =/  v=(unit json)  (~(get by p.j) key)
    ?.  ?=([~ %s *] v)  ""
    (trip p.u.v)
  =/  h=tape  (get 'hash')
  =/  b=tape  (get 'branch')
  =/  r=tape  (get 'remote')
  "window._CURRENT=\{hash:'{h}',branch:'{b}',remote:'{r}'};"
  ::
--
