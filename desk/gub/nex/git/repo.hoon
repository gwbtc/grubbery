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
::  Git actions (pull, checkout, branch, stash, commit, ...) run through
::  the serial command lane at /run.git-action — poke it a {command} string.
::
/<  git-obj  /lib/git/object.hoon
/<  git-pack  /lib/git/pack.hoon
/<  git-repo  /lib/git/repository.hoon
/<  git-transport  /lib/git/transport.hoon
/<  git-act  /lib/git/action.hoon
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
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'config.json'] [[/ %json] default-config]]
          ::  the serial command lane: one stateful grub (run.git-action) at
          ::  root — the single entry point for every git action. Runs commands
          ::  one at a time: a repo has one working tree / index / HEAD, so
          ::  operations must not interleave. Poke it a {command} string; read
          ::  it for queue/active/log. Named with its mark visible, git-convention.
          [%fall %& [/ %'run.git-action'] [[/ %git-action] *action-state:git-act]]
          ::  poll.json: self-configuring sync daemon. Holds {minutes: N}
          ::  (0 = off) and its on-file arm IS the poller. Sync cadence is
          ::  kept separate from repo identity (config.json).
          [%fall %& [/ %'poll.json'] [[/ %json] (pairs:enjs:format ~[['minutes' n+'0']])]]
          [%fall %| /data [`[`[/git %data] ~ %.n ~] ~]]
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
          ::
          ::  /run.git-action: the serial command lane. Poke a {command}; it
          ::  parses (lib/git/action), marks the job `active`, runs it to
          ::  completion, then appends the outcome to `log`. One command at a
          ::  time — the working tree / index / HEAD are single, so git
          ::  operations must not interleave.
          ::
          [~ %'run.git-action']
        ;<  ~  bind:m  (rise-lane prod)
        |-
        ;<  poke-sage=sage:tarball  bind:m  take-poke:io
        =/  jon=json  (fall (mole |.(!<(json q.poke-sage))) *json)
        =/  raw=@t  (fall (jget jon 'command') '')
        =/  parsed=(unit git-command:git-act)  (parse-command:git-act raw)
        ;<  st=action-state:git-act  bind:m  (get-state-as:io ,action-state:git-act)
        ?~  parsed
          ::  unparseable — log it and wait for the next command
          ;<  now=@da  bind:m  get-time:io
          =/  bad=done:git-act  [next-id.st [%invalid raw] raw [%error 'unrecognized command'] now]
          ;<  ~  bind:m  (replace:io st(log [bad log.st], next-id +(next-id.st)))
          $
        ::  mark the job active, run it, log the outcome
        =/  =job:git-act  [next-id.st u.parsed raw %start ~]
        ;<  ~  bind:m  (replace:io st(active `job, next-id +(next-id.st)))
        ;<  =outcome:git-act  bind:m  (run-command u.parsed)
        ;<  end=@da  bind:m  get-time:io
        ;<  st2=action-state:git-act  bind:m  (get-state-as:io ,action-state:git-act)
        =/  entry=done:git-act  [id.job u.parsed raw outcome end]
        ;<  ~  bind:m  (replace:io st2(active ~, log [entry log.st2]))
        $
          ::  /poll.json: the sync daemon. Boot-pull once, then poke the lane's
          ::  `pull` on poll.json's own `minutes` interval, watching itself for
          ::  changes. 0 = off (park until the interval is set).
          ::
          [~ %'poll.json']
        ;<  ~  bind:m  (rise-wait:io prod "%git/repo poll: failed")
        ::  pull once here, before the poll loop: a freshly-seeded repo
        ::  checks out immediately instead of waiting a full poll interval.
        ;<  boot-run-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& / %'run.git-action'])
        ;<  ~  bind:m
          (poke:io boot-run-rd [[/ %json] (pairs:enjs:format ~[['command' s+'pull']])])
        ::  watch our own grub for the interval — editing poll.json's
        ::  `minutes` wakes this loop to pick up the new cadence.
        ;<  poll-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& / %'poll.json'])
        ;<  *  bind:m  (keep:io /poll poll-rd `[/ %json])
        |-
        ;<  =view:nexus  bind:m  (peek:io poll-rd `[/ %json])
        =/  poll=@ud
          ?.  ?=([%file *] view)  0
          =/  j=(unit json)  (mole |.(!<(json (need-vase:tarball sang.view))))
          ?.  &(?=(^ j) ?=([%o *] u.j))  0
          =/  v  (~(get by p.u.j) 'minutes')
          ?:  ?=([~ %n *] v)  (fall (rush p.u.v dem) 0)
          ?:  ?=([~ %s *] v)  (fall (rush p.u.v dem) 0)
          0
        ?:  =(0 poll)
          ;<  *  bind:m  (take-news:io /poll)
          $
        ~&  >  [%git-repo-poll-sleeping poll %minutes]
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m  (set-timer:io /timer (add now (mul ~m1 poll)))
        ;<  *  bind:m  (take-news-or-wake:io /poll)
        ;<  run-rd=road:tarball  bind:m
          (ancestor-road:io [/git %repo] [%& / %'run.git-action'])
        ;<  ~  bind:m
          (poke:io run-rd [[/ %json] (pairs:enjs:format ~[['command' s+'pull']])])
        $
      ==
    --
::
|%
::
+$  repo-config
  $:  repo=@t
      ref=@t
      account=@t
      author-name=@t
      author-email=@t
  ==
::
::  +run-command: execute one parsed git command in the serial lane,
::  yielding its outcome. Verbs are wired incrementally; unwired ones
::  report an error rather than silently no-op.
::
++  run-command
  |=  cmd=git-command:git-act
  =/  m  (fiber:fiber:nexus ,outcome:git-act)
  ^-  form:m
  ?-  -.cmd
    %stash          op-stash
    %stash-pop      op-stash-pop
    %checkout       (op-checkout branch.cmd)
    %branch         (op-branch branch.cmd)
    %branch-delete  (op-branch-delete branch.cmd)
    %add            (op-add paths.cmd)
    %commit         (op-commit message.cmd)
    %push           (op-push where.cmd)
    %pull           op-pull
    %invalid        (pure:m [%error 'unrecognized command'])
    %stash-list     op-stash-list
  ==
::  +op-stash: stash the dirty index and reset the tree to HEAD. Writes
::  stash-request.sig into the data ball and reloads (the data nexus does
::  the git work). Same logic the /actions/stash.sig arm ran.
::
++  op-stash
  =/  m  (fiber:fiber:nexus ,outcome:git-act)
  ^-  form:m
  ;<  req-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data %'stash-request.sig'])
  ;<  ~  bind:m  (write-repo-file req-rd [[/ %sig] ~])
  ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
  ;<  ~  bind:m  (reload:io data-rd)
  (pure:m [%ok 'stashed'])
::  +op-stash-pop: pop the most recent stash onto the working tree.
::
++  op-stash-pop
  =/  m  (fiber:fiber:nexus ,outcome:git-act)
  ^-  form:m
  ;<  req-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data %'stash-pop-request.sig'])
  ;<  ~  bind:m  (write-repo-file req-rd [[/ %sig] ~])
  ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
  ;<  ~  bind:m  (reload:io data-rd)
  (pure:m [%ok 'stash popped'])
::  +op-stash-list: report the stash stack (from data/ui/stash.json, which
::  the data nexus builds from the reflog) as a one-line lane summary.
::
++  op-stash-list
  =/  m  (fiber:fiber:nexus ,outcome:git-act)
  ^-  form:m
  ;<  road=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data/ui %'stash.json'])
  ;<  =view:nexus  bind:m  (peek:io road `[/ %json])
  =/  jon=json  (view-to-json view)
  =/  items=(list json)  ?:(?=(%a -.jon) p.jon ~)
  ?~  items  (pure:m [%ok 'no stashes'])
  =/  parts=(list tape)
    %+  turn  items
    |=  j=json  ^-  tape
    ?.  ?=(%o -.j)  ""
    =/  sh=@t  =/(v (~(get by p.j) 'short') ?:(?=([~ %s *] v) p.u.v ''))
    =/  ix=@t  =/(v (~(get by p.j) 'index') ?:(?=([~ %n *] v) p.u.v '?'))
    "stash@{(trip ix)}: {(trip sh)}"
  =/  joined=tape
    ?~  parts  ""
    |-  ^-  tape
    ?~  t.parts  i.parts
    "{i.parts}, {$(parts t.parts)}"
  (pure:m [%ok (crip "{(a-co:co (lent items))} stash(es): {joined}")])
::  +working-tree-clean: read data/ui/status.json and report whether the
::  tree is clean (checkout/switch refuse to run on a dirty tree).
::
++  working-tree-clean
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  status-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data/ui %'status.json'])
  ;<  status-view=view:nexus  bind:m  (peek:io status-rd `[/ %json])
  =/  status-json=json  (view-to-json status-view)
  ?.  ?=(%o -.status-json)  (pure:m %.y)
  =/  cl  (~(get by p.status-json) 'clean')
  ?+  cl  (pure:m %.n)
    [~ %b %.y]  (pure:m %.y)
  ==
::  +op-branch: create refs/heads/<name> at the current HEAD.
::
++  op-branch
  |=  name=branch:git-act
  =/  m  (fiber:fiber:nexus ,outcome:git-act)
  ^-  form:m
  ?:  =('' name)  (pure:m [%error 'branch name required'])
  ;<  head-hash=@t  bind:m  resolve-head
  ?:  =('' head-hash)  (pure:m [%error 'no HEAD to branch from'])
  ;<  ref-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data/refs/heads (crip (trip name))])
  ;<  exists=?  bind:m  (peek-exists:io ref-rd)
  ?:  exists  (pure:m [%error (crip "branch already exists: {(trip name)}")])
  =/  ref-octs=octs  (as-octt:bytestream (trip head-hash))
  ;<  ~  bind:m  (over:io ref-rd [[/ %mime] [/text/plain ref-octs]])
  ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
  ;<  ~  bind:m  (reload:io data-rd)
  (pure:m [%ok (crip "created branch {(trip name)} at {(trip head-hash)}")])
::  +op-branch-delete: delete refs/heads/<name> (never the current branch).
::
++  op-branch-delete
  |=  name=branch:git-act
  =/  m  (fiber:fiber:nexus ,outcome:git-act)
  ^-  form:m
  ?:  =('' name)  (pure:m [%error 'branch name required'])
  ;<  current=@t  bind:m  read-head-branch
  ?:  =(name current)  (pure:m [%error 'cannot delete the current branch'])
  ;<  del-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data/refs/heads (crip (trip name))])
  ;<  exists=?  bind:m  (peek-exists:io del-rd)
  ?.  exists  (pure:m [%error (crip "branch not found: {(trip name)}")])
  ;<  ~  bind:m  (drop:io /delete-branch del-rd)
  ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
  ;<  ~  bind:m  (reload:io data-rd)
  (pure:m [%ok (crip "deleted branch {(trip name)}")])
::  +op-checkout: git checkout <ref>. A branch name → attached HEAD
::  (ref: refs/heads/<name>); a commit hash → detached HEAD (raw hash).
::  Refuses on a dirty tree; updates HEAD and reloads the data nexus.
::
++  op-checkout
  |=  name=branch:git-act
  =/  m  (fiber:fiber:nexus ,outcome:git-act)
  ^-  form:m
  ?:  =('' name)  (pure:m [%error 'branch or commit required'])
  ;<  clean=?  bind:m  working-tree-clean
  ?.  clean  (pure:m [%error 'working tree is dirty — commit or stash first'])
  ;<  ref-hash=@t  bind:m  (resolve-ref name)
  ::  a matching branch → attached checkout
  ?.  =('' ref-hash)
    ;<  ~  bind:m  (do-checkout (crip "ref: refs/heads/{(trip name)}"))
    (pure:m [%ok (crip "switched to {(trip name)}")])
  ::  not a branch → try the arg as a full commit hash (detached HEAD)
  =/  parsed=(unit @ux)  (rust (trip name) parse-hash-sha-1:git-transport)
  ?~  parsed  (pure:m [%error (crip "not a branch or commit: {(trip name)}")])
  ;<  repo=repository:git-repo  bind:m  load-repo-from-ns
  =/  sto  store:~(. git-repo repo)
  ?~  (get-commit:sto u.parsed)
    (pure:m [%error (crip "commit not found: {(scag 7 (trip name))}")])
  ;<  ~  bind:m  (do-checkout name)
  (pure:m [%ok (crip "checked out {(scag 7 (trip name))} (detached)")])
::  +do-checkout: write HEAD to a value and reload the data nexus.
::
++  do-checkout
  |=  value=@t
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m  (write-head value)
  ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
  (reload:io data-rd)
::  +rise-lane: the lane fiber restarting after a crash. A command that
::  crashed mid-run (a GitHub API error in +gh-request, a bad path in the
::  data nexus) never reached the log, and `active` still names it, so the
::  UI shows a job that runs forever. Close it out as an %error with the
::  crash tang, then wait for the restart poke like any other fiber.
::
++  rise-lane
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  prod  (pure:m ~)
  ;<  st=action-state:git-act  bind:m  (get-state-as:io ,action-state:git-act)
  ;<  ~  bind:m
    ?~  active.st  (pure:m ~)
    ;<  now=@da  bind:m  get-time:io
    =/  job  u.active.st
    =/  msg=@t  (crip "crashed: {(trip (render-tang:build u.prod))}")
    =/  entry=done:git-act  [id.job git-command.job raw.job [%error msg] now]
    (replace:io st(active ~, log [entry log.st]))
  (rise-wait:io prod "%git/repo run: failed")
::  +op-add: stage changes. Empty paths = add all; else selective. Writes
::  add-request.json into the data ball and reloads.
::
++  op-add
  |=  paths=(list @t)
  =/  m  (fiber:fiber:nexus ,outcome:git-act)
  ^-  form:m
  =/  req=json
    ?~  paths  (pairs:enjs:format ~[['all' b+%.y]])
    (pairs:enjs:format ~[['paths' a+(turn paths |=(p=@t s+p))]])
  ;<  req-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data %'add-request.json'])
  ;<  ~  bind:m  (write-repo-file req-rd [[/ %json] req])
  ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
  ;<  ~  bind:m  (reload:io data-rd)
  =/  msg=@t
    ?~  paths  'staged all changes'
    (crip "staged {(scow %ud (lent paths))} path(s)")
  (pure:m [%ok msg])
::  +op-commit: create a local commit from the staged tree.
::
++  op-commit
  |=  message=@t
  =/  m  (fiber:fiber:nexus ,outcome:git-act)
  ^-  form:m
  ?:  =('' message)  (pure:m [%error 'commit message required'])
  ;<  cfg=repo-config  bind:m  read-config
  ::  git refuses to commit without an identity; so do we (no silent
  ::  'grubbery' author). Set name + email in the repo's settings.
  ?:  =('' author-name.cfg)
    (pure:m [%error 'no author name set — configure your identity in settings'])
  ?:  =('' author-email.cfg)
    (pure:m [%error 'no author email set — configure your identity in settings'])
  ;<  now=@da  bind:m  get-time:io
  =/  req=json
    %-  pairs:enjs:format
    :~  ['message' s+message]
        ['author_name' s+author-name.cfg]
        ['author_email' s+author-email.cfg]
        ['date' s+(scot %da now)]
    ==
  ;<  req-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data %'commit-request.json'])
  ;<  ~  bind:m  (write-repo-file req-rd [[/ %json] req])
  ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
  ;<  ~  bind:m  (reload:io data-rd)
  (pure:m [%ok (crip "committed: {(trip message)}")])
::  +op-pull: fetch from the remote and check out the tracked ref — the full
::  transport logic (formerly /actions/sync.sig), now inline in the lane:
::  discovery, resolve+pin the default ref, then an incremental fetch or a
::  full clone. Reports the real outcome.
::
++  op-pull
  =/  m  (fiber:fiber:nexus ,outcome:git-act)
  ^-  form:m
  ;<  cfg=repo-config  bind:m  read-config
  ?:  =('' repo.cfg)  (pure:m [%error 'no repo configured'])
  ;<  disc-res=(each discovery:git-transport tang)  bind:m  (fetch-discovery repo.cfg)
  ?:  ?=(%| -.disc-res)
    =/  msg=tape  (zing (turn (scag 1 p.disc-res) |=(=tank ~(ram re tank))))
    (pure:m [%error (crip "fetch failed: {msg}")])
  =/  disc=discovery:git-transport  p.disc-res
  ::  empty ref = the default branch: resolve and pin it in config.json
  =/  resolve-ref=?  =('' ref.cfg)
  =?  ref.cfg  resolve-ref
    (fall (default-branch:git-transport caps.disc) 'main')
  ;<  ~  bind:m
    =/  m  (fiber:fiber:nexus ,~)
    ?.  resolve-ref  (pure:m ~)
    ;<  cfg-rd=road:tarball  bind:m
      (ancestor-road:io [/git %repo] [%& / %'config.json'])
    ;<  cv=view:nexus  bind:m  (peek:io cfg-rd `[/ %json])
    =/  obj=(map @t json)
      ?.  ?=([%file *] cv)  ~
      =/  j=(unit json)  (mole |.(!<(json (need-vase:tarball sang.cv))))
      ?:  &(?=(^ j) ?=([%o *] u.j))  p.u.j
      ~
    (over:io cfg-rd [[/ %json] o+(~(put by obj) 'ref' s+ref.cfg)])
  ;<  repo-result=(unit repository:git-repo)  bind:m  load-repo-maybe
  ?^  repo-result
    ::  === incremental fetch ===
    =/  repo=repository:git-repo  u.repo-result
    =/  have-hashes=(list @ux)
      %+  roll  archive.object-store.repo
      |=  [=pack:git-pack acc=(list @ux)]
      (weld (turn (tap:pack-on:git-pack index.pack) head) acc)
    =/  have-set=(set @ux)  (silt have-hashes)
    =/  want-hashes=(list @ux)
      %+  murn  refs.disc
      |=  r=git-ref:git-transport
      ?:  (~(has in have-set) hash.r)  ~
      `hash.r
    ?~  want-hashes
      (pure:m [%ok 'already up to date'])
    ;<  pack-res=(each octs tang)  bind:m
      (fetch-pack repo.cfg (build-want:git-transport want-hashes ~['side-band-64k' 'ofs-delta'] ~ have-hashes))
    ?:  ?=(%| -.pack-res)
      =/  msg=tape  (zing (turn (scag 1 p.pack-res) |=(=tank ~(ram re tank))))
      (pure:m [%error (crip "fetch-pack failed: {msg}")])
    =/  pack-body=octs  p.pack-res
    =/  new-pack-data=octs  (extract-pack:git-transport pack-body %.y)
    ?:  =(0 p.new-pack-data)
      ;<  ~  bind:m  (update-refs disc ref.cfg)
      ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
      ;<  ~  bind:m  (reload:io data-rd)
      (pure:m [%ok 'already up to date'])
    =/  new-pack=pack:git-pack  (read:git-pack (from-octs:bytestream new-pack-data))
    =/  new-entries=(list [key=hash:git-repo val=@ud])  (tap:pack-on:git-pack index.new-pack)
    =/  idx-text=tape
      %-  zing
      %+  turn  new-entries
      |=  [key=hash:git-repo val=@ud]
      "{(print-hash-sha-1:git-transport key)} {(a-co:co val)}\0a"
    =/  pack-num=@ud  (lent archive.object-store.repo)
    =/  branch-refs=(list [name=@t hash=hash:git-repo])
      %+  murn  refs.disc
      |=  r=git-ref:git-transport
      ?.  =(`(list @t)`~['refs' 'heads'] (scag 2 refname.r))  ~
      =/  branch-name=@t  (crip (join:git-transport '/' (turn (slag 2 refname.r) trip)))
      `[branch-name hash.r]
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
    ;<  ~  bind:m  (save-repo new-pack-data idx-text pack-num branch-refs head-text active-ref)
    ;<  data-rd=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%| /data])
    ;<  ~  bind:m  (reload:io data-rd)
    (pure:m [%ok (crip "fetched {(scow %ud (lent want-hashes))} new objects")])
  ::  === full clone ===
  ;<  clone-err=(unit @t)  bind:m  (do-full-clone cfg disc)
  ?^  clone-err  (pure:m [%error u.clone-err])
  (pure:m [%ok 'cloned'])
::  +op-push: push local commits to the remote over git's own protocol.
::  Walks the commit chain from the local ref back to the remote tracking
::  ref, packs every object the remote can't reach, and POSTs it to
::  git-receive-pack with a compare-and-set on the ref; the remote ends up
::  holding our exact commits, same hashes. `where` pushes local HEAD to
::  that named remote branch; ~ pushes the current one.
::
++  op-push
  |=  where=(unit branch:git-act)
  =/  m  (fiber:fiber:nexus ,outcome:git-act)
  ^-  form:m
  ;<  gh-nexus=path  bind:m  gh-root
  ;<  cfg=repo-config  bind:m  read-config
  ?:  =('' repo.cfg)  (pure:m [%error 'no repo configured'])
  ;<  ghc=(unit json)  bind:m
    (peek-as:io [%& %& gh-nexus %'config.json'] ,json)
  =/  gh-auth=?
    ?~  ghc  %.n
    ?.  ?=(%o -.u.ghc)  %.n
    =/  acc  (~(get by p.u.ghc) 'accounts')
    ?:  &(?=([~ %o *] acc) !=(~ p.u.acc))  %.y
    =/  tok  (~(get by p.u.ghc) 'token')
    &(?=([~ %s *] tok) !=('' p.u.tok))
  ?.  gh-auth  (pure:m [%error 'no github account connected'])
  ::  genuine none: an empty account no longer silently borrows the first
  ::  connected one — you must pick which account pushes.
  ?:  =('' account.cfg)
    (pure:m [%error 'no account set for this repo — choose one in settings'])
  =/  cur=@t  ?:(=('' ref.cfg) 'main' ref.cfg)
  =/  target=@t  ?~(where '' u.where)
  =/  branch=@t  ?:(=('' target) cur target)
  ;<  repo=repository:git-repo  bind:m  load-repo-from-ns
  =/  sto  store:~(. git-repo repo)
  ;<  local-ref=@t  bind:m  (resolve-ref ref.cfg)
  ;<  remote-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data/refs/remotes/origin (crip (trip branch))])
  ;<  remote-view=view:nexus  bind:m  (peek:io remote-rd `[/ %mime])
  =/  remote-ref=@t
    ?.  ?=([%file *] remote-view)  ''
    =/  mim=mime  !<(mime (need-vase:tarball sang.remote-view))
    (crip (trip q.q.mim))
  ?:  =(local-ref remote-ref)
    (pure:m [%ok 'nothing to push'])
  =/  new-ref=?  =('' remote-ref)
  ;<  cur-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data/refs/remotes/origin (crip (trip cur))])
  ;<  cur-view=view:nexus  bind:m  (peek:io cur-rd `[/ %mime])
  =/  cur-remote=@t
    ?.  ?=([%file *] cur-view)  ''
    =/  mim=mime  !<(mime (need-vase:tarball sang.cur-view))
    (crip (trip q.q.mim))
  =/  chain-base=@t
    ?:(&(new-ref !=(branch cur)) cur-remote remote-ref)
  =/  local-hash=(unit @ux)
    (rust (trip local-ref) parse-hash-sha-1:git-transport)
  ?~  local-hash
    (pure:m [%error 'invalid local ref'])
  =/  remote-hash=@ux
    ?:  =('' chain-base)  0x0
    (fall (rust (trip chain-base) parse-hash-sha-1:git-transport) 0x0)
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
    (pure:m [%ok 'nothing to push'])
  ::  the receiving side's tip for the branch. A push is a compare-and-set
  ::  against it, so it must be what our tracking ref says, or someone
  ::  else pushed and we pull first.
  ;<  disc-res=(each discovery:git-transport tang)  bind:m
    (fetch-push-discovery repo.cfg)
  ?:  ?=(%| -.disc-res)
    =/  msg=tape  (zing (turn (scag 1 p.disc-res) |=(=tank ~(ram re tank))))
    (pure:m [%error (crip "push discovery failed: {msg}")])
  =/  target-rn=(list @t)
    (weld `(list @t)`~['refs' 'heads'] (turn (split:git-transport (trip branch) '/') crip))
  =/  remote-tip=@ux
    =/  f  (skim refs.p.disc-res |=(r=git-ref:git-transport =(refname.r target-rn)))
    ?~  f  0x0
    hash.i.f
  ?.  =(remote-tip remote-hash)
    =/  short=tape  (scag 7 (print-hash-sha-1:git-transport remote-tip))
    (pure:m [%error (crip "remote {(trip branch)} has moved ({short}): pull first")])
  ::  every object reachable from the chain's commits that the remote
  ::  tip can't already reach: the commits, their trees, their blobs
  =/  get-tree=$-(@ux (unit tree-dir:git-repo))
    |=(h=@ux (get-tree:sto h))
  =/  tree-objects
    |=  [tree-hash=@ux acc=(set @ux)]
    ^-  (set @ux)
    =/  dir=(unit tree-dir:git-repo)  (get-tree tree-hash)
    ?~  dir  acc
    =.  acc  (~(put in acc) tree-hash)
    =/  ents=tree-dir:git-repo  u.dir
    |-  ^-  (set @ux)
    ?~  ents  acc
    ?:  (is-dir:git-obj i.ents)
      $(ents t.ents, acc ^$(tree-hash hash.i.ents, acc acc))
    ?:  (is-gitlink:git-obj i.ents)  $(ents t.ents)
    $(ents t.ents, acc (~(put in acc) hash.i.ents))
  =/  have=(set @ux)
    ?:  =(0x0 remote-hash)  ~
    =/  rcom=(unit commit:git-repo)  (get-commit:sto remote-hash)
    ?~  rcom  ~
    (~(put in (tree-objects tree.u.rcom ~)) remote-hash)
  =/  send=(set @ux)
    %+  roll  `(list hash:git-repo)`chain
    |=  [h=hash:git-repo acc=(set @ux)]
    =/  com=(unit commit:git-repo)  (get-commit:sto h)
    ?~  com  acc
    (~(put in (tree-objects tree.u.com acc)) h)
  =/  raws=(list raw-object:git-obj)
    %+  murn  ~(tap in (~(dif in send) have))
    |=(h=@ux (get-raw:sto h))
  =/  pack=octs  (write-pack:git-transport raws)
  =/  body=octs
    %-  build-push-request:git-transport
    :*  remote-tip  u.local-hash  "refs/heads/{(trip branch)}"
        ~['report-status' 'agent=grubbery']  pack
    ==
  ;<  res=(each octs tang)  bind:m  (send-pack repo.cfg body)
  ?:  ?=(%| -.res)
    =/  msg=tape  (zing (turn (scag 1 p.res) |=(=tank ~(ram re tank))))
    (pure:m [%error (crip "push failed: {msg}")])
  =/  report=(unit tape)  (parse-push-response:git-transport p.res)
  ?^  report
    (pure:m [%error (crip "push refused: {u.report}")])
  ::  the remote now holds our exact commit: track it
  ;<  track-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%& /data/refs/remotes/origin (crip (trip branch))])
  =/  track-octs=octs  (as-octt:bytestream (trip local-ref))
  ;<  ~  bind:m  (write-repo-file track-rd [[/ %mime] [/text/plain track-octs]])
  ;<  data-rd=road:tarball  bind:m
    (ancestor-road:io [/git %repo] [%| /data])
  ;<  ~  bind:m  (reload:io data-rd)
  =/  n=@ud  (lent chain)
  (pure:m [%ok (crip "pushed {(scow %ud n)} commit(s), {(scow %ud (lent raws))} object(s) to {(trip branch)}")])
::
++  jget
  |=  [j=json k=@t]
  ^-  (unit @t)
  ?.  ?=(%o -.j)  ~
  =/  v  (~(get by p.j) k)
  ?.(?=([~ %s *] v) ~ `p.u.v)
::
++  read-config
  =/  m  (fiber:fiber:nexus ,repo-config)
  ^-  form:m
  ;<  road=road:tarball  bind:m  (ancestor-road:io [/git %repo] [%& / %'config.json'])
  ;<  =view:nexus  bind:m  (peek:io road `[/ %json])
  ?.  ?=([%file *] view)
    (pure:m ['' 'main' '' '' ''])
  =/  cfg=json  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) *json)
  ?.  ?=(%o -.cfg)
    (pure:m ['' 'main' '' '' ''])
  =/  get
    |=  [key=@t default=@t]
    ^-  @t
    =/  v  (~(get by p.cfg) key)
    ?.  ?=([~ %s *] v)  default
    ?:(=('' p.u.v) default p.u.v)
  %-  pure:m
  :*  (get 'repo' '')  (get 'ref' '')  (get 'account' '')
      (get 'author_name' '')  (get 'author_email' '')
  ==
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
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ~&  >>  "%git/repo: full clone..."
  ~&  >>  "%git/repo: fetching pack..."
  =/  want-hashes=(list @ux)
    (turn refs.disc |=(r=git-ref:git-transport hash.r))
  ;<  pack-res=(each octs tang)  bind:m
    (fetch-pack repo.cfg (build-want:git-transport want-hashes ~['side-band-64k' 'ofs-delta'] ~ ~))
  ?:  ?=(%| -.pack-res)
    =/  msg=tape  (zing (turn (scag 1 p.pack-res) |=(=tank ~(ram re tank))))
    (pure:m `(crip "clone fetch failed: {msg}"))
  =/  pack-body=octs  p.pack-res
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
  ~&  >>  "%git/repo: clone complete"
  ;<  ~  bind:m  (reload:io sync-data-rd)
  (pure:m ~)
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
::  GitHub traffic rides the /apps/github.github proxy (issue #45):
::  the ship's one token lives there, auth and redirects are handled
::  there, and this nexus needs no HTTP reach of its own. Lifecycle
::  per call: keep the lifecycle grub's road, poke main.sig, read the
::  outcome on news, cull — consumer-culls is the contract.
::
::  +gh-root: the github proxy, found by NAME through /sys/link so a
::  move of the proxy changes nothing here. Fails the fiber when the
::  name has no claimant, as a refused road would.
::
++  gh-root
  =/  m  (fiber:fiber:nexus ,path)
  ^-  form:m
  ;<  gh=(unit lane:tarball)  bind:m  (resolve-link:io '@github')
  ?.  ?=([~ %| *] gh)
    |=(input:fiber:nexus [~ q.state %fail ~[leaf+"github proxy is not in /sys/link"]])
  (pure:m p.u.gh)
++  gh-call-id
  =/  m  (fiber:fiber:nexus ,@ta)
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy:io
  (pure:m (crip ((x-co:co 16) (end 6 eny))))
::  +github-xfer: one git smart-HTTP exchange through the proxy
::
++  github-xfer
  |=  $=  req
      $%  [%discovery repo=@t]
          [%pack repo=@t body=octs]
          [%push-discovery repo=@t]
          [%push repo=@t body=octs]
      ==
  =/  m  (fiber:fiber:nexus ,(each octs tang))
  ^-  form:m
  ;<  gh-nexus=path  bind:m  gh-root
  ::  the repo's configured account rides along; '' = first connected
  ;<  cfg=repo-config  bind:m  read-config
  =/  xr
    ?-  -.req
      %discovery       [%discovery account.cfg repo.req]
      %pack            [%pack account.cfg repo.req body.req]
      %push-discovery  [%push-discovery account.cfg repo.req]
      %push            [%push account.cfg repo.req body.req]
    ==
  ;<  id=@ta  bind:m  gh-call-id
  =/  grub=road:tarball  [%& %& (weld gh-nexus /xfer) id]
  ;<  *  bind:m  (keep:io /ghx grub ~)
  ;<  ~  bind:m  (poke:io [%& %& gh-nexus %'main.sig'] [[/ %noun] [%xfer id xr]])
  ::  A DEADLINE. This wait used to be unbounded, and an unbounded wait here
  ::  stops the ship's whole install path.
  ::
  ::  +take-news blocks until the xfer grub changes. If the github app never
  ::  writes a terminal %done or %fail — it died, its request vanished, the
  ::  grub was never created — nothing ever wakes this loop. +run-command then
  ::  never returns, so the run.git-action serial lane keeps active=pull
  ::  step=start permanently, and every command queued behind it is waiting on
  ::  a fetch that is never coming. Observed: a repo provisioned with no desk
  ::  for half an hour and not one line of error, because a blocked fiber has
  ::  not failed — it is still waiting.
  ::
  ::  So arm a timer beside the watch and take whichever arrives first. A
  ::  timeout is reported as an ordinary [%| tang], which every caller already
  ::  handles: +op-pull turns it into "fetch failed" in the lane log, the job
  ::  completes, and the lane moves on.
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (set-timer:io /ghx-deadline (add now xfer-deadline))
  |-
  ;<  res=news-or-wake:io  bind:m  (take-news-or-wake-on:io /ghx /ghx-deadline)
  ?:  ?=(%wake -.res)
    ;<  ~  bind:m  (drop:io /ghx grub)
    ;<  *  bind:m  (cull-soft:io grub)
    %-  pure:m
    :-  %|
    ~[leaf+"github xfer: no answer within {<`@dr`xfer-deadline>}"]
  ;<  v=view:nexus  bind:m  (peek:io grub ~)
  ?.  ?=([%file *] v)  $
  =/  life=(unit $%([%pending *] [%done =octs] [%fail =tang]))
    (mole |.(;;($%([%pending *] [%done =octs] [%fail =tang]) (sang-noun:tarball sang.v))))
  ?~  life  $
  ?:  ?=(%pending -.u.life)  $
  ;<  ~  bind:m  (cancel-timer:io /ghx-deadline)
  ;<  ~  bind:m  (drop:io /ghx grub)
  ;<  *  bind:m  (cull-soft:io grub)
  ?:  ?=(%fail -.u.life)
    (pure:m [%| tang.u.life])
  (pure:m [%& octs.u.life])
::  +xfer-deadline: how long one git smart-HTTP exchange may take before it is
::  called a failure. Generous — a cold clone of a large repo is a real
::  several-minute fetch — but finite, which is the whole point.
::
++  xfer-deadline  ~m10
::
::  +fetch-discovery: GET /info/refs for a repo
::
++  fetch-discovery
  |=  repo=@t
  =/  m  (fiber:fiber:nexus ,(each discovery:git-transport tang))
  ^-  form:m
  ;<  res=(each octs tang)  bind:m  (github-xfer %discovery repo)
  ?:  ?=(%| -.res)  (pure:m [%| p.res])
  (pure:m [%& (parse-discovery:git-transport p.res)])
::
::  +fetch-push-discovery: GET /info/refs?service=git-receive-pack, the
::  remote's tips as the receiving side reports them
::
++  fetch-push-discovery
  |=  repo=@t
  =/  m  (fiber:fiber:nexus ,(each discovery:git-transport tang))
  ^-  form:m
  ;<  res=(each octs tang)  bind:m  (github-xfer %push-discovery repo)
  ?:  ?=(%| -.res)  (pure:m [%| p.res])
  (pure:m [%& (parse-discovery:git-transport p.res)])
::
::  +send-pack: POST /git-receive-pack with a command line and a pack
::
++  send-pack
  |=  [repo=@t body=octs]
  =/  m  (fiber:fiber:nexus ,(each octs tang))
  ^-  form:m
  (github-xfer %push repo body)
::
::  +fetch-pack: POST /git-upload-pack for a repo
::
++  fetch-pack
  |=  [repo=@t want-body=octs]
  =/  m  (fiber:fiber:nexus ,(each octs tang))
  ^-  form:m
  (github-xfer %pack repo want-body)
::
++  view-to-json
  |=  =view:nexus
  ^-  json
  ?.  ?=([%file *] view)  [%a ~]
  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) [%a ~])
::
--
