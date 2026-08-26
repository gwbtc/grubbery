::  lib/git/action: types for the serial git command lane.
::
::    Defines the parsed +git-command a repo accepts, and the stateful
::    +action-state its action grub holds — a queue of pending commands, the
::    one active job (with its intermediate state, so a multi-step op can
::    resume after a restart), and a log of completed commands. The verb
::    grammars (built on /lib/git/cmd) and the dispatch to git operations get
::    layered on top of these types later.
::
/<  cmd  /lib/git/cmd.hoon
|%
+$  branch  @t
::  +git-command: a parsed git verb + its parameters. One serial lane runs
::  these one at a time — a repo has a single working tree/index/HEAD, so
::  git operations must not interleave.
::
+$  git-command
  $%  [%add paths=(list @t)]              ::  paths=~ means add all
      [%commit message=@t]
      [%push where=(unit branch)]         ::  ~ = current branch
      [%pull ~]                           ::  fetch + check out the tracked ref
      [%checkout =branch]
      [%branch =branch]                   ::  create at HEAD
      [%branch-delete =branch]
      [%stash ~]
      [%stash-pop ~]
      [%stash-list ~]
      [%invalid raw=@t]                    ::  didn't parse — for the log only
  ==
::  +job: a queued or running command. `raw` is the string as typed (for the
::  log and UI). `step`/`data` carry a running command's intermediate state
::  so a slow, multi-step op (fetch, push) survives a restart.
::
+$  job
  $:  id=@ud
      =git-command
      raw=@t
      step=@tas
      data=json
  ==
::  +outcome: how a finished command ended.
::
+$  outcome  $%([%ok msg=@t] [%error msg=@t])
+$  done  [id=@ud =git-command raw=@t =outcome at=@da]
::  +action-state: the whole lane. queue is submission-ordered; log is
::  newest-first; next-id hands out monotonic job ids.
::
+$  action-state
  $:  queue=(list job)
      active=(unit job)
      log=(list done)
      next-id=@ud
  ==
::
::  ── json (for the UI / MCP to read the lane's state) ──
::
++  command-to-json
  |=  c=git-command
  ^-  json
  =/  pair  |=([k=@t v=json] [k v])
  %-  pairs:enjs:format
  ?-  -.c
    %add            ~[(pair 'verb' s+'add') (pair 'paths' a+(turn paths.c |=(p=@t s+p)))]
    %commit         ~[(pair 'verb' s+'commit') (pair 'message' s+message.c)]
    %push           ~[(pair 'verb' s+'push') (pair 'branch' ?~(where.c ~ s+u.where.c))]
    %pull           ~[(pair 'verb' s+'pull')]
    %checkout       ~[(pair 'verb' s+'checkout') (pair 'branch' s+branch.c)]
    %branch         ~[(pair 'verb' s+'branch') (pair 'branch' s+branch.c)]
    %branch-delete  ~[(pair 'verb' s+'branch-delete') (pair 'branch' s+branch.c)]
    %stash          ~[(pair 'verb' s+'stash')]
    %stash-pop      ~[(pair 'verb' s+'stash-pop')]
    %stash-list     ~[(pair 'verb' s+'stash-list')]
    %invalid        ~[(pair 'verb' s+'invalid') (pair 'raw' s+raw.c)]
  ==
++  job-to-json
  |=  j=job
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' (numb:enjs:format id.j)]
      ['command' (command-to-json git-command.j)]
      ['raw' s+raw.j]
      ['step' s+step.j]
      ['data' data.j]
  ==
++  done-to-json
  |=  d=done
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' (numb:enjs:format id.d)]
      ['command' (command-to-json git-command.d)]
      ['raw' s+raw.d]
      ['ok' b+?=(%ok -.outcome.d)]
      ['message' s+msg.outcome.d]
      ['at' s+(scot %da at.d)]
  ==
++  state-to-json
  |=  s=action-state
  ^-  json
  %-  pairs:enjs:format
  :~  ['queue' a+(turn queue.s job-to-json)]
      ['active' ?~(active.s ~ (job-to-json u.active.s))]
      ['log' a+(turn log.s done-to-json)]
  ==
::
::  ── command parsing (string → git-command) ──
::
::    Verb grammars built on /lib/git/cmd's combinators. rush requires the
::    whole string to parse, so compound verbs (stash pop) are posed before
::    their prefixes (stash), and the most-specific option form first.
::
++  parse-command
  |=  txt=@t
  ^-  (unit git-command)
  =/  tok      (cook crip (plus ;~(less ace prn)))   ::  a non-space token
  =/  txt-val  val-t:parse:cmd                        ::  'quoted' or bare text
  %+  rush  txt
  ;~  pose
    ::  stash — compound forms first so "stash" doesn't shadow them
    (cold [%stash-pop ~] ;~(plug (jest 'stash') (plus ace) (jest 'pop')))
    (cold [%stash-list ~] ;~(plug (jest 'stash') (plus ace) (jest 'list')))
    (cold [%stash ~] (jest 'stash'))
    (cold [%pull ~] (jest 'pull'))
    ::  commit -m "msg" | --message "msg"
    %+  cook  |=(m=@t [%commit m])
    ;~  pfix  (jest 'commit')  (plus ace)
      ;~  pose
        ;~(pfix ;~(plug hep (just 'm') (plus ace)) txt-val)
        ;~(pfix (jest '--message') ;~(pose ;~(pfix tis txt-val) ;~(pfix (plus ace) txt-val)))
      ==
    ==
    ::  add [path ...]  (no paths = add all)
    %+  cook  |=(ps=(list @t) [%add ps])
    ;~  pfix  (jest 'add')
      ;~(pose ;~(pfix (plus ace) (most (plus ace) tok)) (easy ~))
    ==
    ::  push [branch]
    %+  cook  |=(w=(unit @t) [%push w])
    ;~  pfix  (jest 'push')
      ;~(pose ;~(pfix (plus ace) (cook some tok)) (easy ~))
    ==
    ::  checkout <branch>
    %+  cook  |=(b=@t [%checkout b])
    ;~(pfix (jest 'checkout') (plus ace) tok)
    ::  branch <name> | branch -d <name>
    ;~  pfix  (jest 'branch')  (plus ace)
      ;~  pose
        %+  cook  |=(b=@t [%branch-delete b])
        ;~(pfix ;~(plug hep (just 'd') (plus ace)) tok)
        (cook |=(b=@t [%branch b]) tok)
      ==
    ==
  ==
--
