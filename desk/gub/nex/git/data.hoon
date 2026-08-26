::  git/data nexus: git object store + atomic checkout + local commits
::
::  Reload-driven state machine. Its whole behavior is on-load: given the
::  git objects (packs + loose) + HEAD + refs, plus at most one pending
::  request file, it (1) applies the request (stash / pop / add / commit),
::  (2) checks out the tree at HEAD into tree/, and (3) rebuilds the derived
::  ui/ views. Ball in -> ball out, recomputed from source on every reload —
::  so a reboot at any point yields a consistent tree + views with no stale
::  cache and no separate "refresh the UI" step to race. Mutations arrive as
::  request files: the parent nexus writes one and reloads us. This on-load
::  is the single place git state is ever changed.
::
::  Git-format boundary: interop with real git happens at the WIRE — the
::  packs, refs, and object formats that cross to/from GitHub are all real
::  git. The on-disk /data layout, by contrast, is internal: nothing outside
::  the ship ever reads it with a real `git` binary. So some encodings below
::  are Hoon-side conveniences, not git's own formats — marked NON-STD. They
::  work because they never leave the ship; move them toward git convention
::  over time (rewriting them into git's real formats buys interop we don't
::  currently need).
::
::  Ball layout (inputs — written by parent):
::    packs/pack-N.pack     raw pack bytes (mime), N = 0, 1, 2, ...   [real git]
::    packs/pack-N.idx      NON-STD pack index: "hex-hash offset\n" per line
::                          (git's real .idx is a binary fanout table)
::    HEAD                  "ref: refs/heads/<branch>" or raw hash (detached)
::    refs/heads/<branch>   local branch ref (mime, hash text)        [real git]
::    refs/remotes/origin/<branch>  remote tracking ref (mime, hash text)
::    refs/stash            most recent stash commit hash
::    logs/                 NON-STD stash reflog (custom append format;
::                          git uses logs/refs/... in its own line format)
::    commit-request.json   if present, create commit from current tree/
::    stash-request.sig     if present, stash dirty tree and reset
::    stash-pop-request.sig if present, pop stash onto working tree
::    objects/              loose git objects (persisted across reloads) [real git]
::    INDEX                 NON-STD index: "mode hash\tpath\n" per entry
::                          (git's real index is a binary format)
::
::  Ball layout (outputs — cached porcelain: derived views, never
::  authoritative, rebuilt from git state every reload by +write-ui-outputs.
::  These correspond to git commands that compute on demand — git stores no
::  such files itself):
::    tree/               checked out files
::    ui/commits.json     commit log from branch tip (50 max)   = `git log`
::    ui/branches.json    branch name list                      = `git branch`
::    ui/current.json     {"hash","branch","remote"}            = resolved HEAD
::    ui/status.json      {staged,unstaged,untracked,clean,...} = `git status`
::
/<  git-obj  /lib/git/object.hoon
/<  git-pack  /lib/git/pack.hoon
/<  git-repo  /lib/git/repository.hoon
/<  git-transport  /lib/git/transport.hoon
/&  man  ../../man/git/data/readme.md
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      %-  ball-to-bole:tarball
      =.  ball  (~(put ba:tarball ball) [/ %'README.md'] [[/ %mime] %& !>(man)])
      ::  load all packs from packs/ directory
      =/  archive=(list pack:git-pack)  (load-packs ball)
      ?~  archive  ball
      ::  check for HEAD
      =/  parsed-head=(unit [branch=(unit @t) hash=@ux])
        (parse-head ball)
      ?~  parsed-head  ball
      =/  commit-hash=@ux  hash.u.parsed-head
      ::  read refs from refs/ namespace
      =/  built-refs=(axal ref:git-repo)
        (read-refs-from-ns ball)
      ::  read loose objects from objects/ dir
      =/  loose=(map hash:git-repo object:git-obj)
        (read-loose-from-ball ball)
      =/  repo=repository:git-repo
        [%sha-1 [loose archive] built-refs ~ ~]
      =/  sto  store:~(. git-repo repo)
      ::
      ::  === stash request handling ===
      ::  create a commit from index, write refs/stash + reflog, reset tree
      ::
      =/  stash-req=(unit sang:tarball)
        (~(get ba:tarball ball) [/ %'stash-request.sig'])
      ?^  stash-req
        ~&  >>  "%git/data: stash request"
        ::  capture the FULL working tree (staged + unstaged, per git
        ::  convention) — not just the index. Stage everything into a
        ::  throwaway index first so the stash commit holds every uncommitted
        ::  change; otherwise unstaged edits are lost on the reset below.
        =/  current-tree=ball:tarball  (fall (~(get by dir.ball) 'tree') [~ ~])
        =/  old-idx=(map path [hash:git-repo mtime=@t])  (read-index ball)
        =/  work=[idx=(map path [hash:git-repo mtime=@t]) new-loose=(map hash:git-repo object:git-obj)]
          (git-add current-tree old-idx)
        =.  ball  (write-loose-to-ball ball new-loose.work)
        =/  idx=(map path hash:git-repo)  (idx-hashes idx.work)
        =/  parent-com=(unit commit:git-repo)  (get-commit:sto commit-hash)
        =/  parent-tree-hash=hash:git-repo
          ?~(parent-com 0x0 tree.u.parent-com)
        ::  build tree + commit from the full working tree
        =/  stash-result
          (git-commit idx parent-tree-hash commit-hash (pairs:enjs:format ~[['message' s+'stash']]))
        ?~  stash-result
          ~&  >>  "%git/data: nothing to stash (clean)"
          =.  ball  (~(del ba:tarball ball) / %'stash-request.sig')
          ball
        ::  merge loose objects
        =.  ball  (write-loose-to-ball ball new-loose.u.stash-result)
        ::  write refs/stash
        =/  stash-hex=tape  (print-hash-sha-1:git-transport new-hash.u.stash-result)
        =/  stash-octs=octs  (as-octt:bytestream stash-hex)
        =.  ball
          %+  ~(put ba:tarball ball)  [/refs %'stash']
          [[/ %mime] %& !>([/text/plain stash-octs])]
        ::  append stash reflog
        =/  old-stash-hex=tape
          =/  old=(unit hash:git-repo)  (read-ref-file ball /refs 'stash')
          ?~  old  (reap 40 '0')
          (print-hash-sha-1:git-transport u.old)
        =.  ball  (append-stash-reflog ball old-stash-hex stash-hex "stash")
        ::  clear request
        =.  ball  (~(del ba:tarball ball) / %'stash-request.sig')
        ::  full checkout from HEAD — reset tree + index + UI
        =/  get-tree=$-(@ux (unit tree-dir:git-repo))
          |=(h=@ux (get-tree:sto h))
        =/  get-blob=$-(@ux (unit octs))
          |=(h=@ux (get-blob:sto h))
        =/  head-idx=(map path [hash:git-repo mtime=@t])
          (build-index-from-tree get-tree parent-tree-hash)
        =.  ball  (write-index ball head-idx)
        =/  files=(list [path octs])
          (checkout:git-transport get-tree get-blob parent-tree-hash)
        =/  tree-ball=ball:tarball  (files-to-ball files)
        =.  ball  ball(dir (~(put by dir.ball) 'tree' tree-ball))
        =.  ball  (write-tree-head ball (print-hash-sha-1:git-transport commit-hash))
        =.  ball  (write-ui-outputs ball sto commit-hash parsed-head head-idx parent-tree-hash)
        ~&  >>  ["%git/data: stashed at" (scag 7 stash-hex)]
        ball
      ::
      ::  === stash pop request handling ===
      ::  read refs/stash commit, apply its tree to index, drop stash
      ::
      =/  pop-req=(unit sang:tarball)
        (~(get ba:tarball ball) [/ %'stash-pop-request.sig'])
      ?^  pop-req
        ~&  >>  "%git/data: stash pop request"
        =/  stash-hash=(unit hash:git-repo)
          (read-ref-file ball /refs 'stash')
        ?~  stash-hash
          ~&  >>>  "%git/data: no stash to pop"
          =.  ball  (~(del ba:tarball ball) / %'stash-pop-request.sig')
          ball
        =/  stash-com=(unit commit:git-repo)  (get-commit:sto u.stash-hash)
        ?~  stash-com
          ~&  >>>  "%git/data: stash commit not found in store"
          =.  ball  (~(del ba:tarball ball) / %'stash-pop-request.sig')
          ball
        ::  get HEAD commit tree for status comparison
        =/  head-com=(unit commit:git-repo)  (get-commit:sto commit-hash)
        =/  head-tree-hash=hash:git-repo
          ?~(head-com 0x0 tree.u.head-com)
        =/  get-tree=$-(@ux (unit tree-dir:git-repo))
          |=(h=@ux (get-tree:sto h))
        =/  get-blob=$-(@ux (unit octs))
          |=(h=@ux (get-blob:sto h))
        ::  index stays at HEAD; the stash tree goes into the working tree.
        ::  so the restored changes show as UNSTAGED — git's default pop.
        =/  head-idx=(map path [hash:git-repo mtime=@t])
          (build-index-from-tree get-tree head-tree-hash)
        =.  ball  (write-index ball head-idx)
        ::  checkout stash tree into tree/
        =/  files=(list [path octs])
          (checkout:git-transport get-tree get-blob tree.u.stash-com)
        =.  ball  ball(dir (~(put by dir.ball) 'tree' (files-to-ball files)))
        ::  the restored tree is a dirty working tree over the same
        ::  HEAD — stamp the marker so reloads preserve it
        =.  ball  (write-tree-head ball (print-hash-sha-1:git-transport commit-hash))
        ::  pop reflog — drop last entry, get previous stash hash
        =/  pop-result=[prev=(unit hash:git-repo) =ball:tarball]
          (pop-stash-reflog ball)
        =.  ball  ball.pop-result
        ::  update refs/stash: point to previous stash or delete if empty
        =.  ball
          ?~  prev.pop-result
            (~(del ba:tarball ball) /refs %'stash')
          =/  prev-hex=tape  (print-hash-sha-1:git-transport u.prev.pop-result)
          =/  prev-octs=octs  (as-octt:bytestream prev-hex)
          %+  ~(put ba:tarball ball)  [/refs %'stash']
          [[/ %mime] %& !>([/text/plain prev-octs])]
        ::  clear request
        =.  ball  (~(del ba:tarball ball) / %'stash-pop-request.sig')
        ::  build UI outputs — status will show stash diff against HEAD
        =.  ball  (write-ui-outputs ball sto commit-hash parsed-head head-idx head-tree-hash)
        ~&  >>  ["%git/data: popped stash" (scag 7 (print-hash-sha-1:git-transport u.stash-hash))]
        ball
      ::
      ::  === add request handling ===
      ::  if add-request.json exists, stage files into INDEX
      ::
      =/  add-req=(unit json)  (read-add-request ball)
      ?^  add-req
        ~&  >>  "%git/data: add request found"
        ?>  ?=(%o -.u.add-req)
        =/  req-map=(map @t json)  p.u.add-req
        =/  current-tree=ball:tarball
          (fall (~(get by dir.ball) 'tree') [~ ~])
        =/  old-idx=(map path [hash:git-repo mtime=@t])  (read-index ball)
        ::  determine which files to stage
        =/  add-paths=(unit (set path))
          =/  p  (~(get by req-map) 'paths')
          ?.  ?=([~ %a *] p)  ~
          :-  ~
          %-  silt
          %+  turn  p.u.p
          |=  j=json
          ?.  ?=(%s -.j)  /
          (stab (crip (weld "/" (trip p.j))))
        =/  add-result=[idx=(map path [hash:git-repo mtime=@t]) new-loose=(map hash:git-repo object:git-obj)]
          ?~  add-paths
            ::  add all
            (git-add current-tree old-idx)
          ::  add specific paths only
          (git-add-paths current-tree old-idx u.add-paths)
        ::  write only new loose objects (existing ones already in ball)
        =.  ball  (write-loose-to-ball ball new-loose.add-result)
        =.  ball  (write-index ball idx.add-result)
        =.  ball  (~(del ba:tarball ball) / %'add-request.json')
        ::  rebuild status after staging
        =/  get-tree=$-(@ux (unit tree-dir:git-repo))
          |=(h=@ux (get-tree:sto h))
        =/  parent-com=(unit commit:git-repo)  (get-commit:sto commit-hash)
        =/  head-tree-idx=(map path hash:git-repo)
          ?~  parent-com  ~
          (idx-hashes (build-index-from-tree get-tree tree.u.parent-com))
        =/  status=json  (build-status ball idx.add-result head-tree-idx)
        =.  ball
          (~(put ba:tarball ball) [/ui %'status.json'] [[/ %json] %& !>(status)])
        ~&  >>  "%git/data: staged files"
        ball
      ::
      ::  === commit request handling ===
      ::  if commit-request.json exists, create a local commit
      ::  from the current tree/ state (don't overwrite it)
      ::
      =/  commit-req=(unit json)  (read-commit-request ball)
      ?^  commit-req
        ~&  >>  "%git/data: commit request found"
        ::  read index as-is (staging is done by add-request)
        =/  full-idx=(map path [hash:git-repo mtime=@t])  (read-index ball)
        =/  idx=(map path hash:git-repo)  (idx-hashes full-idx)
        =/  parent-com=(unit commit:git-repo)  (get-commit:sto commit-hash)
        =/  parent-tree-hash=hash:git-repo
          ?~(parent-com 0x0 tree.u.parent-com)
        =/  commit-result
          (git-commit idx parent-tree-hash commit-hash u.commit-req)
        ?~  commit-result
          ~&  >>  "%git/data: no changes, skipping commit"
          =.  ball  (~(del ba:tarball ball) / %'commit-request.json')
          ball
        ::  merge new loose objects
        =/  all-loose=(map hash:git-repo object:git-obj)
          (~(uni by loose) new-loose.u.commit-result)
        =.  repo  repo(loose.object-store all-loose)
        =.  sto  store:~(. git-repo repo)
        ::  advance HEAD (branch ref or detached)
        =/  new-head-text=tape  (print-hash-sha-1:git-transport new-hash.u.commit-result)
        =/  hash-octs=octs  (as-octt:bytestream new-head-text)
        =/  branch-name=@t  (fall branch.u.parsed-head '')
        ::  on a branch — update refs/heads/<branch>, HEAD stays symbolic
        =?  ball  ?=(^ branch.u.parsed-head)
          %+  ~(put ba:tarball ball)  [/refs/heads (crip (trip u.branch.u.parsed-head))]
          [[/ %mime] %& !>([/text/plain hash-octs])]
        ::  detached HEAD — update HEAD hash directly
        =?  ball  ?=(~ branch.u.parsed-head)
          %+  ~(put ba:tarball ball)  [/ %'HEAD']
          [[/ %mime] %& !>([/text/plain hash-octs])]
        ::  append reflog if on a branch
        =?  ball  ?=(^ branch.u.parsed-head)
          =/  old-hex=tape  (print-hash-sha-1:git-transport commit-hash)
          =/  msg=tape
            ?.  ?=(%o -.u.commit-req)  "commit"
            =/  m  (~(get by p.u.commit-req) 'message')
            ?.  ?=([~ %s *] m)  "commit"
            "commit: {(take-first-line (trip p.u.m))}"
          (append-reflog ball (crip (trip u.branch.u.parsed-head)) old-hex new-head-text msg)
        ::  persist only new loose objects (existing ones already in ball)
        =.  ball  (write-loose-to-ball ball new-loose.u.commit-result)
        ::  tree/ already holds the committed content — move the marker
        ::  with HEAD so the next reload preserves rather than resets
        =.  ball  (write-tree-head ball new-head-text)
        ::  clear commit request
        =.  ball  (~(del ba:tarball ball) / %'commit-request.json')
        ::  rebuild outputs with new HEAD
        =/  ref-labels=(map hash:git-repo (list @t))  (build-ref-labels ball)
        =/  new-commits=json  (build-commit-log sto new-hash.u.commit-result 50 ref-labels)
        =/  branches=json  (build-branch-list ball)
        =/  new-hex=@t  (crip new-head-text)
        =/  new-current=json  (build-current ball new-hex branch-name)
        ::  after commit, HEAD tree = index, so staged is clean
        =/  new-status=json  (build-status ball full-idx idx)
        =.  ball
          (~(put ba:tarball ball) [/ui %'commits.json'] [[/ %json] %& !>(new-commits)])
        =.  ball
          (~(put ba:tarball ball) [/ui %'branches.json'] [[/ %json] %& !>(branches)])
        =.  ball
          (~(put ba:tarball ball) [/ui %'current.json'] [[/ %json] %& !>(new-current)])
        =.  ball
          (~(put ba:tarball ball) [/ui %'status.json'] [[/ %json] %& !>(new-status)])
        ball
      ::
      ::  === normal checkout ===
      ::
      =/  com-maybe=(unit commit:git-repo)  (get-commit:sto commit-hash)
      ?~  com-maybe
        ::  HEAD points to unreachable commit (stale loose objects?)
        ::  clear objects/ and bail — next sync will restore
        ~&  >>>  "%git/data: HEAD not found in store, clearing stale objects"
        =.  ball  ball(dir (~(del by dir.ball) 'objects'))
        ball
      =/  com=commit:git-repo  u.com-maybe
      =/  head-text=tape  (print-hash-sha-1:git-transport commit-hash)
      ::  tree/ already materialized from this HEAD: it may carry
      ::  working edits and a staged index — preserve both, refresh
      ::  only the derived ui. Checkout happens exactly when HEAD
      ::  moved (switch, checkout, clone), where overwriting is the
      ::  point.
      ?:  ?&  (~(has by dir.ball) 'tree')
              =(`head-text (read-tree-head ball))
          ==
        =/  idx=(map path [hash:git-repo mtime=@t])  (read-index ball)
        =.  ball  (write-ui-outputs ball sto commit-hash parsed-head idx tree.com)
        ball
      ~&  >>  ["%git/data: checkout" (scag 7 head-text)]
      =/  get-tree=$-(@ux (unit tree-dir:git-repo))
        |=(h=@ux (get-tree:sto h))
      =/  get-blob=$-(@ux (unit octs))
        |=(h=@ux (get-blob:sto h))
      ::  checkout tree
      =/  files=(list [path octs])
        (checkout:git-transport get-tree get-blob tree.com)
      ~&  >>  ["%git/data: checked out" (lent files) "files"]
      =/  tree-ball=ball:tarball  (files-to-ball files)
      ::  build index from commit tree (path -> blob-hash flat map)
      =/  idx=(map path [hash:git-repo mtime=@t])
        (build-index-from-tree get-tree tree.com)
      =.  ball  (write-index ball idx)
      ::  write tree into ball BEFORE computing status
      =.  ball  ball(dir (~(put by dir.ball) 'tree' tree-ball))
      =.  ball  (write-tree-head ball head-text)
      =.  ball  (write-ui-outputs ball sto commit-hash parsed-head idx tree.com)
      ball
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      stay:m
    --
::
|%
::  +read-tree-head: which commit tree/ was last materialized from.
::  ~ means never recorded — treat as needing checkout.
::
++  read-tree-head
  |=  =ball:tarball
  ^-  (unit tape)
  =/  got=(unit sang:tarball)  (~(get ba:tarball ball) [/ %'TREE-HEAD'])
  ?~  got  ~
  =/  res  (mule |.(!<(mime (need-vase:tarball u.got))))
  ?:  ?=(%| -.res)  ~
  `(trip `@t`q.q.p.res)
::
++  write-tree-head
  |=  [=ball:tarball hex=tape]
  ^-  ball:tarball
  %+  ~(put ba:tarball ball)  [/ %'TREE-HEAD']
  [[/ %mime] %& !>(`mime`[/text/plain (as-octt:bytestream hex)])]
::  +append-reflog: append an entry to the reflog for a branch
::
::    NON-STD format: "old-hash new-hash message\n" per entry (git's real
::    reflog line carries committer identity + timestamp too). Internal-only;
::    move toward git convention over time. Stored at logs/heads/<branch> as mime.
::
++  append-reflog
  |=  [=ball:tarball branch=@ta old-hex=tape new-hex=tape msg=tape]
  ^-  ball:tarball
  =/  entry=tape  "{old-hex} {new-hex} {msg}\0a"
  =/  log-path=path  /logs/heads
  =/  existing=(unit sang:tarball)
    (~(get ba:tarball ball) [log-path branch])
  =/  old-text=tape
    ?~  existing  ""
    =/  m=mime  !<(mime (need-vase:tarball u.existing))
    (trip q.q.m)
  =/  new-text=tape  (weld old-text entry)
  =/  new-octs=octs  (as-octt:bytestream new-text)
  %+  ~(put ba:tarball ball)  [log-path branch]
  [[/ %mime] %& !>([/text/plain new-octs])]
::
++  append-stash-reflog
  |=  [=ball:tarball old-hex=tape new-hex=tape msg=tape]
  ^-  ball:tarball
  =/  entry=tape  "{old-hex} {new-hex} {msg}\0a"
  =/  existing=(unit sang:tarball)
    (~(get ba:tarball ball) [/logs %'stash'])
  =/  old-text=tape
    ?~  existing  ""
    =/  m=mime  !<(mime (need-vase:tarball u.existing))
    (trip q.q.m)
  =/  new-text=tape  (weld old-text entry)
  =/  new-octs=octs  (as-octt:bytestream new-text)
  %+  ~(put ba:tarball ball)  [/logs %'stash']
  [[/ %mime] %& !>([/text/plain new-octs])]
::
++  pop-stash-reflog
  |=  =ball:tarball
  ^-  [prev=(unit hash:git-repo) ball:tarball]
  =/  existing=(unit sang:tarball)
    (~(get ba:tarball ball) [/logs %'stash'])
  ?~  existing  [~ ball]
  =/  text=tape  (trip q.q:!<(mime (need-vase:tarball u.existing)))
  ::  split on newlines, drop empty, drop last entry
  =/  lines=(list @t)
    %+  skip  (to-wain:format (crip text))
    |=(t=@t =('' t))
  =/  count=@ud  (lent lines)
  ?:  (lte count 1)
    [~ (~(del ba:tarball ball) /logs %'stash')]
  =/  kept=(list @t)  (scag (dec count) lines)
  ::  extract previous stash hash from last remaining entry
  ::  format: "old-hash new-hash message" — new-hash starts at char 41
  =/  last-line=tape  (trip (snag (dec (lent kept)) kept))
  =/  prev-hash=(unit hash:git-repo)
    ?.  (gte (lent last-line) 81)  ~
    (rust (scag 40 (slag 41 last-line)) parse-hash-sha-1:git-transport)
  =/  new-text=tape
    %+  roll  kept
    |=([line=@t acc=tape] (weld acc (weld (trip line) "\0a")))
  =/  new-octs=octs  (as-octt:bytestream new-text)
  :-  prev-hash
  %+  ~(put ba:tarball ball)  [/logs %'stash']
  [[/ %mime] %& !>([/text/plain new-octs])]
::
::  +parse-head: read HEAD file and return branch or detached hash
::
::    HEAD contains either "ref: refs/heads/<branch>" (on a branch)
::    or a raw hex hash (detached HEAD). Returns the branch name
::    and resolved hash, or just the hash if detached.
::
++  parse-head
  |=  =ball:tarball
  ^-  (unit [branch=(unit @t) hash=@ux])
  =/  head-content=(unit sang:tarball)
    (~(get ba:tarball ball) [/ %'HEAD'])
  ?~  head-content  ~
  =/  head-mim=mime  !<(mime (need-vase:tarball u.head-content))
  =/  head-text=tape  (trip q.q.head-mim)
  ?:  =("ref: " (scag 5 head-text))
    ::  symbolic ref — extract branch name and resolve
    =/  ref-path=tape  (slag 5 head-text)
    =/  branch=@t
      ?.  =("refs/heads/" (scag 11 ref-path))
        (crip ref-path)
      (crip (slag 11 ref-path))
    =/  hash=(unit hash:git-repo)
      (read-ref-file ball /refs/heads (crip (trip branch)))
    ?~  hash  ~
    `[`branch u.hash]
  ::  raw hash — detached HEAD
  =/  hash=(unit @ux)
    (rust head-text parse-hash-sha-1:git-transport)
  ?~  hash  ~
  `[~ u.hash]
::
::  +read-add-request: check for add-request.json
::
++  read-add-request
  |=  =ball:tarball
  ^-  (unit json)
  =/  req=(unit sang:tarball)
    (~(get ba:tarball ball) [/ %'add-request.json'])
  ?~  req  ~
  =/  j=json  (fall (mole |.(!<(json (need-vase:tarball u.req)))) *json)
  ?.  ?=(%o -.j)  ~
  `j
::
::  +read-commit-request: check for commit-request.json
::
++  read-commit-request
  |=  =ball:tarball
  ^-  (unit json)
  =/  req=(unit sang:tarball)
    (~(get ba:tarball ball) [/ %'commit-request.json'])
  ?~  req  ~
  =/  j=json  (fall (mole |.(!<(json (need-vase:tarball u.req)))) *json)
  ?.  ?=(%o -.j)  ~
  ?:  =(~ p.j)  ~
  `j
::
::  +read-loose-from-ball: load persisted loose objects from objects/ dir
::
++  read-loose-from-ball
  |=  =ball:tarball
  ^-  (map hash:git-repo object:git-obj)
  =/  obj-dir=(unit ball:tarball)
    (~(get by dir.ball) 'objects')
  ?~  obj-dir  ~
  ?~  fil.u.obj-dir  ~
  =/  entries=(list [name=@t =sang:tarball gain=? bang=(unit tang)])
    ~(tap by contents.u.fil.u.obj-dir)
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
::  +write-loose-to-ball: persist loose objects as files in objects/ dir
::
++  write-loose-to-ball
  |=  [=ball:tarball loose=(map hash:git-repo object:git-obj)]
  ^-  ball:tarball
  =/  entries=(list [=hash:git-repo obj=object:git-obj])
    ~(tap by loose)
  |-
  ?~  entries  ball
  =/  name=@t  (crip (print-hash-sha-1:git-transport hash.i.entries))
  =/  raw=raw-object:git-obj  (obj-to-raw:git-obj %sha-1 obj.i.entries)
  =/  raw-octs=octs  (raw-to-octs:git-obj raw)
  =/  =sang:tarball  [[/ %mime] %& !>([/application/octet-stream raw-octs])]
  $(entries t.entries, ball (~(put ba:tarball ball) [/objects name] sang))
::
::  +build-index-from-tree: walk commit tree, return flat path->blob-hash
::
::    Populates the git index on checkout. Walks tree recursively,
::    records each blob's path and hash. Skips gitlinks.
::
++  build-index-from-tree
  |=  [get-tree=$-(hash:git-repo (unit tree-dir:git-repo)) tree-hash=hash:git-repo]
  ^-  (map path [hash:git-repo mtime=@t])
  =/  tree=(unit tree-dir:git-repo)  (get-tree tree-hash)
  ?~  tree  ~
  (walk-tree-for-index get-tree / u.tree)
::
++  walk-tree-for-index
  |=  [get-tree=$-(hash:git-repo (unit tree-dir:git-repo)) here=path dir=tree-dir:git-repo]
  ^-  (map path [hash:git-repo mtime=@t])
  %+  roll  dir
  |=  [ent=tree-entry:git-obj acc=(map path [hash:git-repo mtime=@t])]
  ?:  (is-gitlink:git-obj ent)  acc
  ?:  (is-dir:git-obj ent)
    =/  sub=(unit tree-dir:git-repo)  (get-tree hash.ent)
    ?~  sub  acc
    (~(uni by acc) (walk-tree-for-index get-tree (snoc here name.ent) u.sub))
  (~(put by acc) (snoc here name.ent) [hash.ent ''])
::
::  +write-index: serialize index as flat file into ball
::
::    NON-STD format: "mode hash mtime\tpath\n" per entry (git's real index
::    is a binary format). Internal-only; move toward git convention over time.
::    mtime is optional — missing means no cached mtime.
::    Stored as INDEX mime file.
::
++  write-index
  |=  [=ball:tarball idx=(map path [hash:git-repo mtime=@t])]
  ^-  ball:tarball
  =/  lines=tape
    %-  zing
    %+  turn  ~(tap by idx)
    |=  [=path h=hash:git-repo mtime=@t]
    =/  hex=tape  (print-hash-sha-1:git-transport h)
    =/  pax=tape  (zing (join "/" (turn path trip)))
    =/  mt=tape  (trip mtime)
    "100644 {hex} {mt}\09{pax}\0a"
  =/  idx-octs=octs  (as-octt:bytestream lines)
  %+  ~(put ba:tarball ball)  [/ %'INDEX']
  [[/ %mime] %& !>([/application/octet-stream idx-octs])]
::
::  +read-index: parse INDEX file back to path->[hash mtime] map
::
++  read-index
  |=  =ball:tarball
  ^-  (map path [hash:git-repo mtime=@t])
  =/  idx-content=(unit sang:tarball)
    (~(get ba:tarball ball) [/ %'INDEX'])
  ?~  idx-content  ~
  =/  m=mime  !<(mime (need-vase:tarball u.idx-content))
  ?:  =(0 p.q.m)  ~
  =/  lines=(list tape)
    (split:git-transport (trip q.q.m) `@t`10)
  %+  roll  lines
  |=  [line=tape acc=(map path [hash:git-repo mtime=@t])]
  ?:  =(~ line)  acc
  ::  parse: "mode hash mtime\tpath"
  =/  tab=(unit @ud)  (find "\09" line)
  ?~  tab  acc
  =/  pax=path
    (turn (split:git-transport (slag +(u.tab) line) '/') crip)
  ::  hash is chars 7-46 (after "100644 ")
  =/  hex=tape  (swag [7 40] line)
  =/  h=(unit @ux)  (rust hex parse-hash-sha-1:git-transport)
  ?~  h  acc
  ::  mtime is chars 48 to tab (after "100644 " + 40-char hash + " ")
  =/  mt=@t  (crip (swag [48 (sub u.tab 48)] line))
  (~(put by acc) pax [u.h mt])
::
::  +idx-hashes: extract just path->hash from index (drop mtime)
::
++  idx-hashes
  |=  idx=(map path [hash:git-repo mtime=@t])
  ^-  (map path hash:git-repo)
  %-  ~(run by idx)
  |=([h=hash:git-repo m=@t] h)
::
::  +git-add: walk working tree, hash blobs, update index
::
::    For each file in tree/: check mtime against index cache.
::    If mtime matches, skip (unchanged). If different or new,
::    hash as git blob, create loose object, update index.
::    Returns updated index + new loose objects.
::
++  git-add
  |=  [tree-ball=ball:tarball old-idx=(map path [hash:git-repo mtime=@t])]
  ^-  [idx=(map path [hash:git-repo mtime=@t]) new-loose=(map hash:git-repo object:git-obj)]
  =|  new-loose=(map hash:git-repo object:git-obj)
  =/  new-idx=(map path [hash:git-repo mtime=@t])  old-idx
  =/  working=(list [=path data=octs mtime=@t])
    (ball-to-files-mt tree-ball /)
  ::  prune deleted files: remove index entries not in working tree
  =/  working-paths=(set path)
    (silt (turn working |=([=path *] path)))
  =.  new-idx
    %-  ~(rep by new-idx)
    |=  [[p=path h=hash:git-repo m=@t] acc=(map path [hash:git-repo mtime=@t])]
    ?.  (~(has in working-paths) p)  acc
    (~(put by acc) p [h m])
  ::  add/update files
  |-
  ?~  working  [new-idx new-loose]
  =/  file-mtime=@t  mtime.i.working
  ::  fast path: if mtime matches index, skip hashing
  =/  old-entry=(unit [hash:git-repo mtime=@t])  (~(get by new-idx) path.i.working)
  ?:  &(?=(^ old-entry) !=('' +.u.old-entry) =(+.u.old-entry file-mtime))
    $(working t.working)
  ::  mtime changed or new file — hash the blob
  =/  data=octs  data.i.working
  =/  blob=object:git-obj  [%blob p.data data]
  =/  blob-hash=hash:git-repo  (hash-obj:git-obj %sha-1 blob)
  ?:  &(?=(^ old-entry) =(-.u.old-entry blob-hash))
    ::  hash same despite mtime change — update mtime only
    $(working t.working, new-idx (~(put by new-idx) path.i.working [blob-hash file-mtime]))
  ::  new or changed — store blob, update index
  %=  $
    new-loose  (~(put by new-loose) blob-hash blob)
    new-idx    (~(put by new-idx) path.i.working [blob-hash file-mtime])
    working    t.working
  ==
::
::  +git-add-paths: stage specific paths from working tree into index
::
::    Only touches files whose paths are in the given set.
::    Adds/updates them if present in tree/, removes from index if not.
::
++  git-add-paths
  |=  [tree-ball=ball:tarball old-idx=(map path [hash:git-repo mtime=@t]) paths=(set path)]
  ^-  [idx=(map path [hash:git-repo mtime=@t]) new-loose=(map hash:git-repo object:git-obj)]
  =|  new-loose=(map hash:git-repo object:git-obj)
  =/  new-idx=(map path [hash:git-repo mtime=@t])  old-idx
  =/  working=(list [=path data=octs mtime=@t])
    (ball-to-files-mt tree-ball /)
  =/  working-map=(map path [octs @t])
    (malt (turn working |=([=path data=octs mtime=@t] [path data mtime])))
  =/  todo=(list path)  ~(tap in paths)
  |-
  ?~  todo  [new-idx new-loose]
  =/  pax=path  i.todo
  =/  file-data=(unit [octs @t])  (~(get by working-map) pax)
  ?~  file-data
    ::  file not in working tree — remove from index
    $(todo t.todo, new-idx (~(del by new-idx) pax))
  ::  file exists — hash and stage
  =/  data=octs  -.u.file-data
  =/  file-mtime=@t  +.u.file-data
  =/  blob=object:git-obj  [%blob p.data data]
  =/  blob-hash=hash:git-repo  (hash-obj:git-obj %sha-1 blob)
  =/  old-entry=(unit [hash:git-repo mtime=@t])  (~(get by new-idx) pax)
  ?:  &(?=(^ old-entry) =(-.u.old-entry blob-hash))
    ::  unchanged hash — update mtime
    $(todo t.todo, new-idx (~(put by new-idx) pax [blob-hash file-mtime]))
  %=  $
    new-loose  (~(put by new-loose) blob-hash blob)
    new-idx    (~(put by new-idx) pax [blob-hash file-mtime])
    todo       t.todo
  ==
::
::  +ball-to-files: flatten ball tree to list of [path octs]
::
++  ball-to-files
  |=  [=ball:tarball here=path]
  ^-  (list [=path data=octs])
  =/  files=(list [=path data=octs])
    ?~  fil.ball  ~
    %+  turn  ~(tap by contents.u.fil.ball)
    |=  [name=@t =sang:tarball gain=? bang=(unit tang)]
    =/  m=mime  !<(mime (need-vase:tarball sang))
    [(snoc here name) q.m]
  =/  sub-files=(list [=path data=octs])
    %-  zing
    %+  turn  ~(tap by dir.ball)
    |=  [name=@t sub=ball:tarball]
    (ball-to-files sub (snoc here name))
  (weld files sub-files)
::
::  +ball-to-files-mt: flatten ball tree with mtime from metadata
::
++  ball-to-files-mt
  |=  [=ball:tarball here=path]
  ^-  (list [=path data=octs mtime=@t])
  =/  files=(list [=path data=octs mtime=@t])
    ?~  fil.ball  ~
    %+  turn  ~(tap by contents.u.fil.ball)
    |=  [name=@t =sang:tarball gain=? bang=(unit tang)]
    =/  m=mime  !<(mime (need-vase:tarball sang))
    [(snoc here name) q.m '']
  =/  sub-files=(list [=path data=octs mtime=@t])
    %-  zing
    %+  turn  ~(tap by dir.ball)
    |=  [name=@t sub=ball:tarball]
    (ball-to-files-mt sub (snoc here name))
  (weld files sub-files)
::
::  +git-commit: build trees from index, create commit object
::
::    Reads the index (path -> blob-hash), groups entries by directory,
::    builds tree objects bottom-up. Compares root tree hash to parent.
::    Returns ~ if nothing changed. Never touches tree/.
::
++  git-commit
  |=  $:  idx=(map path hash:git-repo)
          parent-tree-hash=hash:git-repo
          parent=hash:git-repo
          req=json
      ==
  ^-  (unit [new-hash=hash:git-repo new-loose=(map hash:git-repo object:git-obj)])
  ?.  ?=(%o -.req)  !!
  =/  get-str
    |=  [key=@t default=@t]
    ^-  @t
    =/  v  (~(get by p.req) key)
    ?.  ?=([~ %s *] v)  default
    p.u.v
  =/  message=tape    (trip (get-str 'message' 'commit'))
  =/  author-name=tape    (trip (get-str 'author_name' 'grubbery'))
  =/  author-email=tape   (trip (get-str 'author_email' 'grubbery@urbit.org'))
  =/  date=@da
    =/  d  (~(get by p.req) 'date')
    ?.  ?=([~ %s *] d)  *@da
    (fall (slaw %da p.u.d) *@da)
  ::  build tree objects from index entries
  =|  new-loose=(map hash:git-repo object:git-obj)
  =^  root-hash=hash:git-repo  new-loose
    (build-trees-from-index idx new-loose)
  ::  bail if root tree matches parent — nothing changed
  ?:  =(root-hash parent-tree-hash)  ~
  ::  create commit object
  =/  com=commit:git-obj
    :_  message
    :*  root-hash
        ~[parent]
        [author-name author-email]
        [date [%.y ~h0]]
        [author-name author-email]
        [date [%.y ~h0]]
        ~
    ==
  =/  com-obj=object:git-obj  [%commit 0 com]
  =/  raw=raw-object:git-obj  (obj-to-raw:git-obj %sha-1 com-obj)
  =.  size.com-obj  size.raw
  =/  com-hash=hash:git-repo  (hash-raw:git-obj %sha-1 raw)
  =.  new-loose  (~(put by new-loose) com-hash com-obj)
  `[com-hash new-loose]
::
::  +build-trees-from-index: group index entries by directory, build trees
::
::    Takes the flat index (path -> blob-hash) and reconstructs the
::    git tree hierarchy. Each directory becomes a tree object.
::    Returns root tree hash + all tree objects as loose.
::
++  build-trees-from-index
  |=  [idx=(map path hash:git-repo) loose=(map hash:git-repo object:git-obj)]
  ^-  [hash:git-repo (map hash:git-repo object:git-obj)]
  ::  group entries by first path segment
  =/  entries=(list [=path h=hash:git-repo])  ~(tap by idx)
  (build-tree-at / entries loose)
::
++  build-tree-at
  |=  [here=path entries=(list [=path h=hash:git-repo]) loose=(map hash:git-repo object:git-obj)]
  ^-  [hash:git-repo (map hash:git-repo object:git-obj)]
  ::  separate blobs (files in this dir) from subtrees (files in subdirs)
  =/  depth=@ud  (lent here)
  =|  tree-entries=(list tree-entry:git-obj)
  =|  subdirs=(map @ta (list [=path h=hash:git-repo]))
  =/  todo=_entries  entries
  |-
  ?^  todo
    =/  rel=path  (slag depth path.i.todo)
    ?~  rel  $(todo t.todo)
    ?~  t.rel
      ::  file directly in this directory
      %=  $
        tree-entries  [[i.rel 0x81a4 h.i.todo] tree-entries]
        todo  t.todo
      ==
    ::  file in a subdirectory — group by first segment
    =/  dir-name=@ta  i.rel
    =/  existing=(list [=path h=hash:git-repo])
      (fall (~(get by subdirs) dir-name) ~)
    %=  $
      subdirs  (~(put by subdirs) dir-name [i.todo existing])
      todo  t.todo
    ==
  ::  recursively build each subdirectory tree
  =/  sub-list=(list [@ta (list [=path h=hash:git-repo])])
    ~(tap by subdirs)
  |-
  ?^  sub-list
    =^  sub-hash=hash:git-repo  loose
      (build-tree-at (snoc here -.i.sub-list) +.i.sub-list loose)
    %=  $
      tree-entries  [[-.i.sub-list 0x4000 sub-hash] tree-entries]
      sub-list  t.sub-list
    ==
  ::  sort entries (git byte-string comparison)
  =.  tree-entries  (sort tree-entries git-entry-lth)
  ::  create tree object
  =/  tree=object:git-obj  [%tree 0 tree-entries]
  =/  raw=raw-object:git-obj  (obj-to-raw:git-obj %sha-1 tree)
  =.  size.tree  size.raw
  =/  tree-hash=hash:git-repo  (hash-raw:git-obj %sha-1 raw)
  =.  loose  (~(put by loose) tree-hash tree)
  [tree-hash loose]
::
::
::  +read-ref-file: read a single ref hash from refs/<subdir>/<name>
::
++  read-ref-file
  |=  [=ball:tarball dir=path name=@ta]
  ^-  (unit hash:git-repo)
  =/  content=(unit sang:tarball)
    (~(get ba:tarball ball) [dir name])
  ?~  content  ~
  =/  m=mime  !<(mime (need-vase:tarball u.content))
  ?:  =(0 p.q.m)  ~
  (rust (trip q.q.m) parse-hash-sha-1:git-transport)
::
::  +read-hash-from-content: extract a hash from a mime content entry
::
++  read-hash-from-content
  |=  =sang:tarball
  ^-  (unit hash:git-repo)
  =/  m=mime  !<(mime (need-vase:tarball sang))
  ?:  =(0 p.q.m)  ~
  (rust (trip q.q.m) parse-hash-sha-1:git-transport)
::
::  +get-sub-ball: walk into a ball by path
::
++  get-sub-ball
  |=  [=ball:tarball =path]
  ^-  ball:tarball
  ?~  path  ball
  =/  sub=(unit ball:tarball)  (~(get by dir.ball) i.path)
  ?~  sub  [~ ~]
  $(ball u.sub, path t.path)
::
::  +read-refs-from-ns: read all refs from refs/ namespace
::
++  read-refs-from-ns
  |=  =ball:tarball
  ^-  (axal ref:git-repo)
  =/  result=(axal ref:git-repo)  [~ ~]
  =/  heads-sub=ball:tarball  (get-sub-ball ball /refs/heads)
  =.  result
    ?~  fil.heads-sub  result
    %+  roll  ~(tap by contents.u.fil.heads-sub)
    |=  [[name=@t =sang:tarball gain=? bang=(unit tang)] r=(axal ref:git-repo)]
    =/  h=(unit @ux)  (read-hash-from-content sang)
    ?~  h  r
    (~(put of r) [~['refs' 'heads' name] u.h])
  =/  remote-sub=ball:tarball  (get-sub-ball ball /refs/remotes/origin)
  ?~  fil.remote-sub  result
  %+  roll  ~(tap by contents.u.fil.remote-sub)
  |=  [[name=@t =sang:tarball gain=? bang=(unit tang)] r=(axal ref:git-repo)]
  =/  h=(unit @ux)  (read-hash-from-content sang)
  ?~  h  r
  (~(put of r) [~['refs' 'remotes' 'origin' name] u.h])
::
::  +load-packs: read all pack-N.pack + pack-N.idx pairs from packs/ directory
::
::  Returns packs in order (pack-0 first). Empty list if no packs found.
::
++  load-packs
  |=  =ball:tarball
  ^-  (list pack:git-pack)
  ::  get packs/ subdirectory from ball
  =/  packs-ball=(unit ball:tarball)
    (~(get by dir.ball) 'packs')
  ?~  packs-ball  ~
  ::  find all .pack files — extract N from "pack-N.pack"
  =/  packs-dir=ball:tarball  u.packs-ball
  ?~  fil.packs-dir  ~
  =/  all-files=(list @ta)  ~(tap in ~(key by contents.u.fil.packs-dir))
  =/  pack-nums=(list @ud)
    %+  murn  all-files
    |=  name=@ta
    =/  t=tape  (trip name)
    ?.  =("pack-" (scag 5 t))  ~
    ?.  =(".pack" (slag (sub (lent t) 5) t))  ~
    =/  num-text=tape  (slag 5 (scag (sub (lent t) 5) t))
    (rust num-text dem)
  =/  sorted=(list @ud)  (sort pack-nums lth)
  ::  load each pack+idx pair
  %+  murn  sorted
  |=  n=@ud
  ^-  (unit pack:git-pack)
  =/  pack-name=@ta  (crip "pack-{(a-co:co n)}.pack")
  =/  idx-name=@ta  (crip "pack-{(a-co:co n)}.idx")
  =/  pack-content=(unit sang:tarball)
    (~(get ba:tarball packs-dir) [/ pack-name])
  =/  idx-content=(unit sang:tarball)
    (~(get ba:tarball packs-dir) [/ idx-name])
  ?~  pack-content  ~
  ?~  idx-content  ~
  =/  pack-mim=mime  !<(mime (need-vase:tarball u.pack-content))
  ?:  =(0 p.q.pack-mim)  ~
  =/  idx-mim=mime  !<(mime (need-vase:tarball u.idx-content))
  =/  idx-text=tape  (trip q.q.idx-mim)
  =/  idx=pack-index:git-pack
    (rebuild-index (split:git-transport idx-text `@t`10))
  =/  sea=bays:bytestream  (from-octs:bytestream q.pack-mim)
  =/  entries=(list [key=hash:git-repo val=@ud])
    (tap:pack-on:git-pack idx)
  `[%sha-1 (lent entries) idx p.q.pack-mim sea]
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
::  +build-commit-log: walk parent chain, return JSON array
::
++  build-commit-log
  |=  $:  sto=_store:~(. git-repo *repository:git-repo)
          start=hash:git-repo
          max=@ud
          labels=(map hash:git-repo (list @t))
      ==
  ^-  json
  =|  acc=(list json)
  =|  count=@ud
  =/  h=hash:git-repo  start
  |-
  ?:  (gte count max)  [%a (flop acc)]
  =/  com=(unit commit:git-repo)  (get-commit:sto h)
  ?~  com  [%a (flop acc)]
  =/  hex=@t  (crip (print-hash-sha-1:git-transport h))
  =/  short=@t  (crip (scag 7 (print-hash-sha-1:git-transport h)))
  =/  msg=@t  (crip (scag 72 (take-first-line message.u.com)))
  =/  full-msg=@t  (crip message.u.com)
  =/  author-name=@t  (crip name.author.u.com)
  =/  author-email=@t  (crip email.author.u.com)
  =/  committer-name=@t  (crip name.committer.u.com)
  =/  committer-email=@t  (crip email.committer.u.com)
  =/  tree-hex=@t  (crip (print-hash-sha-1:git-transport tree.u.com))
  =/  parent-hashes=(list json)
    (turn parents.u.com |=(p=@ux s+(crip (print-hash-sha-1:git-transport p))))
  =/  refs-json=(list json)
    (turn (fall (~(get by labels) h) ~) |=(r=@t s+r))
  =/  entry=json
    %-  pairs:enjs:format
    :~  ['hash' s+hex]
        ['short' s+short]
        ['message' s+msg]
        ['body' s+full-msg]
        ['author' s+author-name]
        ['authorEmail' s+author-email]
        ['date' (time:enjs:format date.author-time.u.com)]
        ['committer' s+committer-name]
        ['committerEmail' s+committer-email]
        ['commitDate' (time:enjs:format date.commit-time.u.com)]
        ['tree' s+tree-hex]
        ['parents' [%a parent-hashes]]
        ['refs' [%a refs-json]]
    ==
  ?~  parents.u.com  [%a (flop [entry acc])]
  $(h i.parents.u.com, count +(count), acc [entry acc])
::
++  take-first-line
  |=  t=tape
  ^-  tape
  =/  idx=(unit @ud)  (find "\0a" t)
  ?~  idx  t
  (scag u.idx t)
::
::  +build-branch-list: list branch names from refs/heads/
::
::  +build-ref-labels: build hash -> label list map from all refs
::
++  build-ref-labels
  |=  =ball:tarball
  ^-  (map hash:git-repo (list @t))
  =|  result=(map hash:git-repo (list @t))
  ::  helper: add a label to the map for a given hash
  =*  add-label
    |=  [r=(map hash:git-repo (list @t)) h=hash:git-repo label=@t]
    (~(put by r) h (snoc (fall (~(get by r) h) ~) label))
  ::  add HEAD
  =/  head-content=(unit sang:tarball)
    (~(get ba:tarball ball) [/ %'HEAD'])
  =?  result  ?=(^ head-content)
    =/  h=(unit @ux)
      (rust (trip q.q:!<(mime (need-vase:tarball u.head-content))) parse-hash-sha-1:git-transport)
    ?~  h  result
    (add-label result u.h 'HEAD')
  ::  add local branches (refs/heads/*)
  =/  heads=ball:tarball  (get-sub-ball ball /refs/heads)
  =?  result  ?=(^ fil.heads)
    =/  entries=(list [@t [=sang:tarball gain=? bang=(unit tang)]])  ~(tap by contents.u.fil.heads)
    |-
    ?~  entries  result
    =/  h=(unit @ux)  (read-hash-from-content sang.+.i.entries)
    =?  result  ?=(^ h)
      (add-label result u.h (crip "refs/heads/{(trip -.i.entries)}"))
    $(entries t.entries)
  ::  add remote tracking (refs/remotes/origin/*)
  =/  remotes=ball:tarball  (get-sub-ball ball /refs/remotes/origin)
  =?  result  ?=(^ fil.remotes)
    =/  entries=(list [@t [=sang:tarball gain=? bang=(unit tang)]])  ~(tap by contents.u.fil.remotes)
    |-
    ?~  entries  result
    =/  h=(unit @ux)  (read-hash-from-content sang.+.i.entries)
    =?  result  ?=(^ h)
      (add-label result u.h (crip "refs/remotes/origin/{(trip -.i.entries)}"))
    $(entries t.entries)
  result
::
::  +write-ui-outputs: rebuild the derived ui/ views (commits, branches,
::  current, status) from git state and write them to the ball.
::
::    This is the projection/cache step, not git logic: it recomputes the
::    porcelain views git normally produces on demand (log / branch / status).
::    It runs as the tail of on-load, where the object store is already loaded
::    and tree/ freshly checked out, so the rebuild is nearly free and the
::    views are always consistent with the tree on disk. The args are just the
::    on-load locals it needs — status is the three-way compare of working
::    tree vs `idx` (index) vs HEAD tree, so callers pass whichever index/tree
::    their mutation produced. (Name kept for now; it's a view rebuild, not UI.)
::
::    Expects tree/ to already be set in ball before calling.
::    idx is the current index (may differ from HEAD for staged changes).
::
++  write-ui-outputs
  |=  $:  =ball:tarball
          sto=_store:~(. git-repo *repository:git-repo)
          head-hash=hash:git-repo
          parsed-head=(unit [branch=(unit @t) hash=@ux])
          idx=(map path [hash:git-repo mtime=@t])
          head-tree-hash=hash:git-repo
      ==
  ^-  ball:tarball
  =/  branch-name=@t  (fall ?~(parsed-head ~ branch.u.parsed-head) '')
  =/  log-start=hash:git-repo
    ?~  parsed-head  head-hash
    ?~  branch.u.parsed-head  head-hash
    (fall (read-ref-file ball /refs/heads (crip (trip u.branch.u.parsed-head))) head-hash)
  =/  ref-labels=(map hash:git-repo (list @t))  (build-ref-labels ball)
  =/  commits=json  (build-commit-log sto log-start 50 ref-labels)
  =/  branches=json  (build-branch-list ball)
  =/  hex=@t  (crip (print-hash-sha-1:git-transport head-hash))
  =/  current=json  (build-current ball hex branch-name)
  ::  build status: compare current index against HEAD commit tree
  =/  get-tree=$-(@ux (unit tree-dir:git-repo))
    |=(h=@ux (get-tree:sto h))
  =/  head-tree-idx=(map path hash:git-repo)
    (idx-hashes (build-index-from-tree get-tree head-tree-hash))
  =/  status=json  (build-status ball idx head-tree-idx)
  =.  ball
    (~(put ba:tarball ball) [/ui %'commits.json'] [[/ %json] %& !>(commits)])
  =.  ball
    (~(put ba:tarball ball) [/ui %'branches.json'] [[/ %json] %& !>(branches)])
  =.  ball
    (~(put ba:tarball ball) [/ui %'current.json'] [[/ %json] %& !>(current)])
  =.  ball
    (~(put ba:tarball ball) [/ui %'status.json'] [[/ %json] %& !>(status)])
  ball
::
::  +build-current: build current.json with HEAD, branch, and remote tracking info
::
++  build-current
  |=  [=ball:tarball head-hex=@t branch=@t]
  ^-  json
  =/  remote-hash=(unit hash:git-repo)
    ?:  =('' branch)  ~
    (read-ref-file ball /refs/remotes/origin (crip (trip branch)))
  =/  remote-hex=@t
    ?~  remote-hash  ''
    (crip (print-hash-sha-1:git-transport u.remote-hash))
  %-  pairs:enjs:format
  :~  ['hash' s+head-hex]
      ['branch' s+branch]
      ['remote' s+remote-hex]
  ==
::
::  +build-branch-list: list branch names from refs/heads/
::
++  build-branch-list
  |=  =ball:tarball
  ^-  json
  =/  heads=ball:tarball  (get-sub-ball ball /refs/heads)
  ?~  fil.heads  [%a ~]
  [%a (turn ~(tap in ~(key by contents.u.fil.heads)) |=(n=@t s+n))]
::
::  +build-status: compare working tree vs index vs HEAD tree
::
::    Staged = files in INDEX that differ from HEAD tree.
::    Unstaged = files in working tree that differ from INDEX (tracked).
::    Untracked = files in working tree not in INDEX at all.
::
++  build-status
  |=  $:  =ball:tarball
          idx=(map path [hash:git-repo mtime=@t])
          head-tree-idx=(map path hash:git-repo)
      ==
  ^-  json
  ::  staged: INDEX vs HEAD tree
  =/  idx-h=(map path hash:git-repo)  (idx-hashes idx)
  =/  staged=(list json)
    =/  all-paths=(set path)
      (~(uni in ~(key by idx-h)) ~(key by head-tree-idx))
    %+  murn  ~(tap in all-paths)
    |=  =path
    ^-  (unit json)
    =/  in-idx=(unit hash:git-repo)  (~(get by idx-h) path)
    =/  in-head=(unit hash:git-repo)  (~(get by head-tree-idx) path)
    ?:  =(in-idx in-head)  ~
    =/  status=@t
      ?~  in-head  'new'
      ?~  in-idx   'deleted'
      'modified'
    :-  ~
    %-  pairs:enjs:format
    :~  ['path' s+(crip (zing (join "/" (turn path trip))))]
        ['status' s+status]
    ==
  ::  working tree comparison
  =/  tree-ball=ball:tarball
    (fall (~(get by dir.ball) 'tree') [~ ~])
  =/  working=(list [=path data=octs mtime=@t])
    (ball-to-files-mt tree-ball /)
  =/  working-hashes=(map path hash:git-repo)
    %-  malt
    %+  turn  working
    |=  [=path data=octs mtime=@t]
    =/  blob=object:git-obj  [%blob p.data data]
    [path (hash-obj:git-obj %sha-1 blob)]
  ::  unstaged: in INDEX and working tree, but different
  ::  untracked: in working tree but not in INDEX
  =/  all-work-paths=(set path)
    (~(uni in ~(key by working-hashes)) ~(key by idx-h))
  =|  unstaged=(list json)
  =|  untracked=(list json)
  =/  todo=(list path)  ~(tap in all-work-paths)
  |-
  ?^  todo
    =/  =path  i.todo
    =/  in-work=(unit hash:git-repo)  (~(get by working-hashes) path)
    =/  in-idx=(unit hash:git-repo)  (~(get by idx-h) path)
    ?:  =(in-work in-idx)  $(todo t.todo)
    =/  pax=@t  (crip (zing (join "/" (turn path trip))))
    ?~  in-idx
      ::  not in INDEX — untracked
      %=  $
        todo  t.todo
        untracked  :_(untracked (pairs:enjs:format ~[['path' s+pax] ['status' s+'new']]))
      ==
    =/  status=@t
      ?~  in-work  'deleted'
      'modified'
    %=  $
      todo  t.todo
      unstaged  :_(unstaged (pairs:enjs:format ~[['path' s+pax] ['status' s+status]]))
    ==
  ::  ahead/behind: count commits between local and remote
  =/  phead=(unit [branch=(unit @t) hash=@ux])  (parse-head ball)
  =/  branch=@t  (fall ?~(phead ~ branch.u.phead) '')
  =/  local-hash=(unit hash:git-repo)
    ?~(phead ~ `hash.u.phead)
  =/  remote-hash=(unit hash:git-repo)
    ?:  =('' branch)  ~
    (read-ref-file ball /refs/remotes/origin (crip (trip branch)))
  =/  ahead=@ud
    ?~  local-hash   0
    ?~  remote-hash  0
    (count-ahead ball u.local-hash u.remote-hash)
  =/  behind=@ud
    ?~  local-hash   0
    ?~  remote-hash  0
    (count-ahead ball u.remote-hash u.local-hash)
  %-  pairs:enjs:format
  :~  ['staged' [%a staged]]
      ['unstaged' [%a unstaged]]
      ['untracked' [%a untracked]]
      ['ahead' (numb:enjs:format ahead)]
      ['behind' (numb:enjs:format behind)]
      ['clean' b+&(=(~ staged) =(~ unstaged) =(~ untracked))]
  ==
::
::  +count-ahead: count commits reachable from A but not from B
::
::    Walk parent chain from A, stop when we hit B or run out.
::    Simple linear walk — doesn't handle merge commits fully,
::    but correct for linear histories.
::
++  count-ahead
  |=  [=ball:tarball from=hash:git-repo to=hash:git-repo]
  ^-  @ud
  =/  loose=(map hash:git-repo object:git-obj)
    (read-loose-from-ball ball)
  =|  count=@ud
  =/  h=hash:git-repo  from
  |-
  ?:  =(h to)   count
  ?:  =(h 0x0)  count
  =/  obj=(unit object:git-obj)  (~(get by loose) h)
  ?~  obj  count
  ?.  ?=(%commit -.u.obj)  count
  =.  count  +(count)
  ?~  parents.commit.u.obj  count
  $(h i.parents.commit.u.obj)
::
::  +files-to-ball: convert checkout output to ball tree
::
++  files-to-ball
  |=  files=(list [=path data=octs])
  ^-  ball:tarball
  =|  tree=ball:tarball
  |-
  ?~  files  tree
  =/  file-path=path  path.i.files
  ?~  file-path  $(files t.files)
  =/  name=@ta  (rear file-path)
  =/  dir=path  (snip `path`file-path)
  =/  content-type=path  (guess-mime name)
  =/  =mime  [content-type data.i.files]
  =/  =sang:tarball  [[/ %mime] %& !>(mime)]
  =/  segs=(list @t)
    ?~  dir  ~[name]
    (weld dir ~[name])
  =.  tree  (insert-file tree segs sang)
  $(files t.files)
::
++  insert-file
  |=  [tree=ball:tarball segs=(list @ta) =sang:tarball]
  ^-  ball:tarball
  ?~  segs  tree
  ?~  t.segs
    =/  =lump:tarball
      (fall fil.tree [~ ~ %.n ~ ~])
    =.  contents.lump  (~(put by contents.lump) i.segs [sang %.n ~])
    tree(fil `lump)
  =/  kid=ball:tarball
    (fall (~(get by dir.tree) i.segs) [~ ~])
  =.  kid  $(tree kid, segs t.segs)
  tree(dir (~(put by dir.tree) i.segs kid))
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
    %ts    /text/plain
    %py    /text/plain
    %rs    /text/plain
    %c     /text/plain
    %h     /text/plain
    %go    /text/plain
    %toml  /text/plain
    %yaml  /text/plain
    %yml   /text/plain
    %xml   /text/xml
    %svg   /image/'svg+xml'
    %sh    /text/plain
    %nix   /text/plain
  ==
::
::  +git-entry-lth: git tree entry sort comparator
::
::    Git sorts entries by name bytes, appending "/" for directories.
::
++  git-entry-lth
  |=  [a=tree-entry:git-obj b=tree-entry:git-obj]
  ^-  ?
  =/  an=tape  (weld (trip name.a) ?:(=(mode.a 0x4000) "/" ""))
  =/  bn=tape  (weld (trip name.b) ?:(=(mode.b 0x4000) "/" ""))
  (tape-lth an bn)
::
++  tape-lth
  |=  [a=tape b=tape]
  ^-  ?
  ?~  a  ?=(^ b)
  ?~  b  %.n
  ?:  =(i.a i.b)  $(a t.a, b t.b)
  (lth `@`i.a `@`i.b)
--
