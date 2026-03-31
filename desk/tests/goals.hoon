/+  *test, *goals
|%
::  helpers
::
++  now  ~2025.1.1
++  jan  ~2025.1.1
++  feb  ~2025.2.1
++  mar  ~2025.3.1
++  apr  ~2025.4.1
++  jun  ~2025.6.1
++  sep  ~2025.9.1
++  dec  ~2025.12.1
::
++  fresh-store  (create-store now)
::
++  id-a  `goal-id`'a'
++  id-b  `goal-id`'b'
++  id-c  `goal-id`'c'
++  id-d  `goal-id`'d'
++  id-e  `goal-id`'e'
++  id-f  `goal-id`'f'
::
::  create a child under root, return [store child-id]
++  add-child
  |=  [store=goal-store id=goal-id data=(map @t json)]
  ^-  [goal-store goal-id]
  =/  [s=goal-store mid=(unit goal-id)]
    (apply store [%create id root-id data] now)
  ?>  ?=(^ mid)
  [s u.mid]
::
::  create a child under any parent
++  add-child-to
  |=  [store=goal-store id=goal-id parent=goal-id data=(map @t json)]
  ^-  [goal-store goal-id]
  =/  [s=goal-store mid=(unit goal-id)]
    (apply store [%create id parent data] now)
  ?>  ?=(^ mid)
  [s u.mid]
::
::  =========================================
::  store creation
::  =========================================
::
++  test-create-store
  =/  store  fresh-store
  =/  root  (~(got by store) root-id)
  ;:  weld
    %+  expect-eq  !>(root-id)  !>(id.root)
    %+  expect-eq  !>(~)  !>(parent.root)
    (expect !>((validate store)))
  ==
::
::  =========================================
::  create goal
::  =========================================
::
++  test-create-goal
  =/  [store=goal-store cid=goal-id]  (add-child fresh-store id-a ~)
  =/  child  (~(got by store) cid)
  =/  root   (~(got by store) root-id)
  ;:  weld
    %+  expect-eq  !>(`root-id)  !>(parent.child)
    (expect !>((lien children.root |=(c=goal-id =(c cid)))))
    (expect !>((validate store)))
  ==
::
++  test-create-nested-children
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child-to store id-b a ~)
  =/  ga  (~(got by store) a)
  =/  gb  (~(got by store) b)
  ;:  weld
    (expect !>((lien children.ga |=(c=goal-id =(c b)))))
    %+  expect-eq  !>(`a)  !>(parent.gb)
    (expect !>((validate store)))
  ==
::
++  test-create-three-levels
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child-to store id-b a ~)
  =/  [store=goal-store c=goal-id]  (add-child-to store id-c b ~)
  ;:  weld
    %+  expect-eq  !>(`a)  !>(parent:(~(got by store) b))
    %+  expect-eq  !>(`b)  !>(parent:(~(got by store) c))
    (expect !>((validate store)))
  ==
::
++  test-duplicate-id-fails
  =/  [store=goal-store *]  (add-child fresh-store id-a ~)
  %-  expect-fail
  |.((apply store [%create id-a root-id ~] now))
::
::  =========================================
::  delete goal
::  =========================================
::
++  test-delete-leaf
  =/  [store=goal-store cid=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]  (apply store [%delete cid] now)
  =/  root  (~(got by store) root-id)
  ;:  weld
    %+  expect-eq  !>(~)  !>((~(get by store) cid))
    %+  expect-eq  !>(~)  !>(children.root)
    (expect !>((validate store)))
  ==
::
++  test-delete-root-fails
  %-  expect-fail
  |.((apply fresh-store [%delete root-id] now))
::
++  test-delete-with-children-fails
  =/  [store=goal-store cid=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store gcid=goal-id]  (add-child-to store id-b cid ~)
  %-  expect-fail
  |.((apply store [%delete cid] now))
::
::  =========================================
::  move goal
::  =========================================
::
++  test-move-goal
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  ::  move b under a
  =/  [store=goal-store *]  (apply store [%move b a] now)
  =/  ga  (~(got by store) a)
  =/  gb  (~(got by store) b)
  ;:  weld
    %+  expect-eq  !>(`a)  !>(parent.gb)
    (expect !>((lien children.ga |=(c=goal-id =(c b)))))
    ::  root should no longer list b
    %+  expect-eq
      !>(%.n)
      !>((lien children:(~(got by store) root-id) |=(c=goal-id =(c b))))
    (expect !>((validate store)))
  ==
::
++  test-move-same-parent-noop
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]  (apply store [%move a root-id] now)
  ;:  weld
    %+  expect-eq  !>(`root-id)  !>(parent:(~(got by store) a))
    (expect !>((validate store)))
  ==
::
++  test-move-root-fails
  =/  [store=goal-store cid=goal-id]  (add-child fresh-store id-a ~)
  %-  expect-fail
  |.((apply store [%move root-id cid] now))
::
::  =========================================
::  link / unlink
::  =========================================
::
++  test-link-precedence
  ::  a's end -> b's start (precedence: a must finish before b starts)
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store *]
    (apply store [%link [a %end] [b %start]] now)
  =/  ga  (~(got by store) a)
  =/  gb  (~(got by store) b)
  ;:  weld
    (expect !>((has-nid outflow.end.ga [b %start])))
    (expect !>((has-nid inflow.start.gb [a %end])))
    (expect !>((validate store)))
  ==
::
++  test-unlink
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store *]
    (apply store [%link [a %end] [b %start]] now)
  =/  [store=goal-store *]
    (apply store [%unlink [a %end] [b %start]] now)
  =/  ga  (~(got by store) a)
  ;:  weld
    %+  expect-eq
      !>(%.n)
      !>((has-nid outflow.end.ga [b %start]))
    (expect !>((validate store)))
  ==
::
++  test-link-cycle-fails
  ::  create two goals, link them in a cycle
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  ::  a.end -> b.start and b.end -> a.start creates a cycle
  =/  [store=goal-store *]
    (apply store [%link [a %end] [b %start]] now)
  %-  expect-fail
  |.((apply store [%link [b %end] [a %start]] now))
::
++  test-cycle-three-goals
  ::  a -> b -> c -> a cycle
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store c=goal-id]  (add-child store id-c ~)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  =/  [store=goal-store *]  (apply store [%link [b %end] [c %start]] now)
  %-  expect-fail
  |.((apply store [%link [c %end] [a %start]] now))
::
++  test-diamond-dag-no-cycle
  ::  a -> b, a -> c, b -> d, c -> d  (diamond, not a cycle)
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store c=goal-id]  (add-child store id-c ~)
  =/  [store=goal-store d=goal-id]  (add-child store id-d ~)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  =/  [store=goal-store *]  (apply store [%link [a %end] [c %start]] now)
  =/  [store=goal-store *]  (apply store [%link [b %end] [d %start]] now)
  =/  [store=goal-store *]  (apply store [%link [c %end] [d %start]] now)
  (expect !>((validate store)))
::
::  =========================================
::  done / undone
::  =========================================
::
++  test-done-marks-node
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]  (apply store [%done [a %start]] feb)
  =/  ga  (~(got by store) a)
  ;:  weld
    (expect !>(done.i.status.start.ga))
    ::  history preserved: init entry + done entry = 2
    %+  expect-eq  !>(2)  !>((lent status.start.ga))
  ==
::
++  test-undone-pushes-history
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]  (apply store [%done [a %start]] feb)
  =/  [store=goal-store *]  (apply store [%undone [a %start]] mar)
  =/  ga  (~(got by store) a)
  ;:  weld
    %+  expect-eq  !>(%.n)  !>(done.i.status.start.ga)
    ::  3 entries: init, done, undone
    %+  expect-eq  !>(3)  !>((lent status.start.ga))
  ==
::
++  test-done-undone-end
  =/  [store=goal-store cid=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]
    (apply store [%done [cid %end]] feb)
  =/  child  (~(got by store) cid)
  =/  top-status  i.status.end.child
  ;:  weld
    (expect !>(done.top-status))
    %+  expect-eq  !>(feb)  !>(at.top-status)
    ::  undone it
    =/  [store2=goal-store *]  (apply store [%undone [cid %end]] mar)
    =/  child2  (~(got by store2) cid)
    %+  expect-eq  !>(%.n)  !>(done.i.status.end.child2)
  ==
::
++  test-done-parent-end-while-child-undone-fails
  ::  can't mark root.end done while child.end is still undone
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]  (apply store [%done [root-id %start]] feb)
  %-  expect-fail
  |.((apply store [%done [root-id %end]] mar))
::
::  =========================================
::  update data
::  =========================================
::
++  test-update-data
  =/  [store=goal-store cid=goal-id]
    (add-child fresh-store id-a (my ~[['name' s+'first']]))
  =/  [store=goal-store *]
    (apply store [%update cid (my ~[['desc' s+'hello']])] now)
  =/  child  (~(got by store) cid)
  ;:  weld
    %+  expect-eq  !>(``json`s+'first')  !>((~(get by data.child) 'name'))
    %+  expect-eq  !>(``json`s+'hello')  !>((~(get by data.child) 'desc'))
  ==
::
++  test-update-overwrites-existing-key
  =/  [store=goal-store cid=goal-id]
    (add-child fresh-store id-a (my ~[['name' s+'first']]))
  =/  [store=goal-store *]
    (apply store [%update cid (my ~[['name' s+'updated']])] now)
  =/  child  (~(got by store) cid)
  %+  expect-eq  !>(``json`s+'updated')  !>((~(get by data.child) 'name'))
::
::  =========================================
::  actionable
::  =========================================
::
++  test-set-actionable
  =/  [store=goal-store cid=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]
    (apply store [%set-actionable cid %.y] now)
  =/  child  (~(got by store) cid)
  (expect !>(actionable.child))
::
++  test-actionable-with-children-fails
  ::  can't be actionable if you have end nodes in your end's inflow
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child-to store id-b a ~)
  ::  a has a child so it has end inflow from b.end
  %-  expect-fail
  |.((apply store [%set-actionable a %.y] now))
::
::  =========================================
::  set-moment
::  =========================================
::
++  test-set-moment
  =/  [store=goal-store cid=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]
    (apply store [%set-moment [cid %end] `feb] now)
  =/  child  (~(got by store) cid)
  %+  expect-eq  !>(`feb)  !>(moment.end.child)
::
++  test-clear-moment
  =/  [store=goal-store cid=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]
    (apply store [%set-moment [cid %start] `feb] now)
  =/  [store=goal-store *]
    (apply store [%set-moment [cid %start] ~] now)
  =/  child  (~(got by store) cid)
  %+  expect-eq  !>(~)  !>(moment.start.child)
::
::  =========================================
::  moment ordering
::  =========================================
::
++  test-moment-ordering-valid
  ::  correctly ordered: parent contains child's moments
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]  (apply store [%set-moment [root-id %start] `jan] now)
  =/  [store=goal-store *]  (apply store [%set-moment [root-id %end] `dec] now)
  =/  [store=goal-store *]  (apply store [%set-moment [a %start] `mar] now)
  =/  [store=goal-store *]  (apply store [%set-moment [a %end] `jun] now)
  (expect !>((validate store)))
::
++  test-moment-ordering-partial-ok
  ::  only some moments set — should be fine
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]  (apply store [%set-moment [a %start] `mar] now)
  (expect !>((validate store)))
::
++  test-moment-child-start-before-parent-fails
  ::  child start before parent start
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]  (apply store [%set-moment [root-id %start] `jun] now)
  %-  expect-fail
  |.((apply store [%set-moment [a %start] `jan] now))
::
++  test-moment-precedence-violation
  ::  if a.end -> b.start, a's end moment can't be after b's start moment
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  =/  [store=goal-store *]  (apply store [%set-moment [b %start] `feb] now)
  %-  expect-fail
  |.((apply store [%set-moment [a %end] `mar] now))
::
++  test-moment-precedence-valid
  ::  a.end -> b.start, moments correctly ordered
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  =/  [store=goal-store *]  (apply store [%set-moment [a %start] `jan] now)
  =/  [store=goal-store *]  (apply store [%set-moment [a %end] `mar] now)
  =/  [store=goal-store *]  (apply store [%set-moment [b %start] `apr] now)
  =/  [store=goal-store *]  (apply store [%set-moment [b %end] `jun] now)
  (expect !>((validate store)))
::
++  test-moment-transitive-through-no-moment
  ::  root -> a -> b -> c (tree), a.start=Jun, c.start=Mar
  ::  even though b has no moment, bound propagates through b
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child-to store id-b a ~)
  =/  [store=goal-store c=goal-id]  (add-child-to store id-c b ~)
  =/  [store=goal-store *]  (apply store [%set-moment [a %start] `jun] now)
  %-  expect-fail
  |.((apply store [%set-moment [c %start] `mar] now))
::
++  test-moment-diamond-violation
  ::  a -> b, a -> c, b -> d, c -> d (diamond via precedence)
  ::  b.end = Sep, c.end = Mar, d.start = Jun
  ::  path through b says d.start must be >= Sep — violation
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store c=goal-id]  (add-child store id-c ~)
  =/  [store=goal-store d=goal-id]  (add-child store id-d ~)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  =/  [store=goal-store *]  (apply store [%link [a %end] [c %start]] now)
  =/  [store=goal-store *]  (apply store [%link [b %end] [d %start]] now)
  =/  [store=goal-store *]  (apply store [%link [c %end] [d %start]] now)
  =/  [store=goal-store *]  (apply store [%set-moment [b %end] `sep] now)
  =/  [store=goal-store *]  (apply store [%set-moment [c %end] `mar] now)
  %-  expect-fail
  |.((apply store [%set-moment [d %start] `jun] now))
::
++  test-moment-diamond-valid
  ::  same diamond, but d.start after both paths
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store c=goal-id]  (add-child store id-c ~)
  =/  [store=goal-store d=goal-id]  (add-child store id-d ~)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  =/  [store=goal-store *]  (apply store [%link [a %end] [c %start]] now)
  =/  [store=goal-store *]  (apply store [%link [b %end] [d %start]] now)
  =/  [store=goal-store *]  (apply store [%link [c %end] [d %start]] now)
  =/  [store=goal-store *]  (apply store [%set-moment [b %end] `jun] now)
  =/  [store=goal-store *]  (apply store [%set-moment [c %end] `mar] now)
  =/  [store=goal-store *]  (apply store [%set-moment [d %start] `sep] now)
  (expect !>((validate store)))
::
++  test-moment-cross-cutting-precedence
  ::  root -> A -> A1, A2; root -> B -> B1, B2
  ::  A2.end -> B1.start (cross-cutting precedence)
  ::  A2.end = Sep, B1.start = Mar → violation
  =/  [store=goal-store a=goal-id]   (add-child fresh-store 'A' ~)
  =/  [store=goal-store b=goal-id]   (add-child store 'B' ~)
  =/  [store=goal-store a1=goal-id]  (add-child-to store 'A1' a ~)
  =/  [store=goal-store a2=goal-id]  (add-child-to store 'A2' a ~)
  =/  [store=goal-store b1=goal-id]  (add-child-to store 'B1' b ~)
  =/  [store=goal-store b2=goal-id]  (add-child-to store 'B2' b ~)
  =/  [store=goal-store *]  (apply store [%link [a2 %end] [b1 %start]] now)
  =/  [store=goal-store *]  (apply store [%set-moment [a2 %end] `sep] now)
  %-  expect-fail
  |.((apply store [%set-moment [b1 %start] `mar] now))
::
::  =========================================
::  completion consistency
::  =========================================
::
++  test-completion-all-incomplete-ok
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  (expect !>((validate store)))
::
++  test-completion-leaf-done-parent-not-ok
  ::  child done, parent still incomplete — that's fine
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]  (apply store [%done [a %start]] feb)
  =/  [store=goal-store *]  (apply store [%done [a %end]] mar)
  (expect !>((validate store)))
::
++  test-completion-parent-done-child-not-fails
  ::  parent.end done while child.end still undone — violation
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  ::  try to mark b.end done while a.end is still undone
  %-  expect-fail
  |.((apply store [%done [b %end]] feb))
::
++  test-completion-precedence-valid
  ::  a done then b done — fine
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  =/  [store=goal-store *]  (apply store [%done [a %start]] jan)
  =/  [store=goal-store *]  (apply store [%done [a %end]] feb)
  =/  [store=goal-store *]  (apply store [%done [b %start]] mar)
  =/  [store=goal-store *]  (apply store [%done [b %end]] apr)
  (expect !>((validate store)))
::
++  test-completion-transitive-chain
  ::  a.end -> b.start, b.end -> c.start (chain)
  ::  b and c done, a not → violation (b.start done requires a.end done)
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store c=goal-id]  (add-child store id-c ~)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  =/  [store=goal-store *]  (apply store [%link [b %end] [c %start]] now)
  ::  mark a done first so we can mark b
  =/  [store=goal-store *]  (apply store [%done [a %start]] jan)
  =/  [store=goal-store *]  (apply store [%done [a %end]] feb)
  =/  [store=goal-store *]  (apply store [%done [b %start]] mar)
  =/  [store=goal-store *]  (apply store [%done [b %end]] apr)
  ::  now undone a, creating violation (b.start done but a.end no longer done)
  %-  expect-fail
  |.((apply store [%undone [a %end]] jun))
::
++  test-completion-partial-ok
  ::  a.end -> b.start: a done, b not yet started — fine
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  =/  [store=goal-store *]  (apply store [%done [a %start]] jan)
  =/  [store=goal-store *]  (apply store [%done [a %end]] feb)
  (expect !>((validate store)))
::
::  =========================================
::  containment
::  =========================================
::
++  test-containment-enforced
  ::  after create, parent.start -> child.start and child.end -> parent.end
  =/  [store=goal-store cid=goal-id]  (add-child fresh-store id-a ~)
  =/  root  (~(got by store) root-id)
  =/  child  (~(got by store) cid)
  ;:  weld
    (expect !>((has-nid outflow.start.root [cid %start])))
    (expect !>((has-nid outflow.end.child [root-id %end])))
  ==
::
++  test-containment-nested
  ::  containment edges at each level of nesting
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child-to store id-b a ~)
  =/  ga  (~(got by store) a)
  =/  gb  (~(got by store) b)
  ;:  weld
    ::  a.start -> b.start
    (expect !>((has-nid outflow.start.ga [b %start])))
    ::  b.end -> a.end
    (expect !>((has-nid outflow.end.gb [a %end])))
    (expect !>((validate store)))
  ==
::
::  =========================================
::  queries: frontier
::  =========================================
::
++  test-frontier-two-actionable
  ::  "what can I do under root?" — two independent actionable goals
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store *]  (apply store [%set-actionable a %.y] now)
  =/  [store=goal-store *]  (apply store [%set-actionable b %.y] now)
  =/  front  (frontier store root-id)
  %+  expect-eq  !>(2)  !>((lent front))
::
++  test-frontier-precedence-blocks
  ::  a.end -> b.start (a must finish before b starts)
  ::  "what can I do?" — only a, because b is blocked by a
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store *]  (apply store [%set-actionable a %.y] now)
  =/  [store=goal-store *]  (apply store [%set-actionable b %.y] now)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  =/  front  (frontier store root-id)
  %+  expect-eq  !>(1)  !>((lent front))
::
++  test-frontier-done-excluded
  ::  completed goal shouldn't show up — nothing to do there
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]  (apply store [%set-actionable a %.y] now)
  =/  [store=goal-store *]  (apply store [%done [a %end]] feb)
  =/  front  (frontier store root-id)
  %+  expect-eq  !>(0)  !>((lent front))
::
++  test-frontier-scoped-to-goal
  ::  a has child b (actionable). ask "frontier of a" → {b}
  ::  c is also actionable under root but not under a
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child-to store id-b a ~)
  =/  [store=goal-store c=goal-id]  (add-child store id-c ~)
  =/  [store=goal-store *]  (apply store [%set-actionable b %.y] now)
  =/  [store=goal-store *]  (apply store [%set-actionable c %.y] now)
  ;:  weld
    ::  frontier of a only includes b, not c
    %+  expect-eq  !>(1)  !>((lent (frontier store a)))
    ::  frontier of root includes both b and c
    %+  expect-eq  !>(2)  !>((lent (frontier store root-id)))
  ==
::
++  test-frontier-chain-only-first
  ::  a -> b -> c precedence chain, all actionable
  ::  "what do I need to do first?" — only a
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store c=goal-id]  (add-child store id-c ~)
  =/  [store=goal-store *]  (apply store [%set-actionable a %.y] now)
  =/  [store=goal-store *]  (apply store [%set-actionable b %.y] now)
  =/  [store=goal-store *]  (apply store [%set-actionable c %.y] now)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  =/  [store=goal-store *]  (apply store [%link [b %end] [c %start]] now)
  =/  front  (frontier store root-id)
  %+  expect-eq  !>(1)  !>((lent front))
::
++  test-frontier-all-done-empty
  ::  everything under a goal is done → nothing to do
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]  (apply store [%set-actionable a %.y] now)
  =/  [store=goal-store *]  (apply store [%done [a %end]] feb)
  =/  front  (frontier store root-id)
  %+  expect-eq  !>(0)  !>((lent front))
::
::
::  =========================================
::  queries: lineage
::  =========================================
::
++  test-lineage
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child-to store id-b a ~)
  =/  lin  (lineage store b)
  %+  expect-eq  !>(~[a root-id])  !>(lin)
::
++  test-lineage-root
  ::  root's lineage is empty
  =/  lin  (lineage fresh-store root-id)
  %+  expect-eq  !>(~)  !>(lin)
::
++  test-lineage-deep
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child-to store id-b a ~)
  =/  [store=goal-store c=goal-id]  (add-child-to store id-c b ~)
  =/  lin  (lineage store c)
  %+  expect-eq  !>(~[b a root-id])  !>(lin)
::
::  =========================================
::  immutability
::  =========================================
::
++  test-apply-returns-new-store
  =/  store  fresh-store
  =/  [new-store=goal-store *]  (apply store [%create id-a root-id ~] now)
  ::  original store should still have just root
  %+  expect-eq  !>(1)  !>(~(wyt by store))
::
::  =========================================
::  complex traversal scenarios
::  =========================================
::
++  test-double-diamond-moments
  ::     b
  ::   /   \
  :: a       d -> e
  ::   \   /      |
  ::     c    f <-+
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store c=goal-id]  (add-child store id-c ~)
  =/  [store=goal-store d=goal-id]  (add-child store id-d ~)
  =/  [store=goal-store e=goal-id]  (add-child store id-e ~)
  =/  [store=goal-store f=goal-id]  (add-child store id-f ~)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  =/  [store=goal-store *]  (apply store [%link [a %end] [c %start]] now)
  =/  [store=goal-store *]  (apply store [%link [b %end] [d %start]] now)
  =/  [store=goal-store *]  (apply store [%link [c %end] [d %start]] now)
  =/  [store=goal-store *]  (apply store [%link [d %end] [e %start]] now)
  =/  [store=goal-store *]  (apply store [%link [e %end] [f %start]] now)
  ::  all valid moments, increasing left to right
  =/  [store=goal-store *]  (apply store [%set-moment [a %start] `jan] now)
  =/  [store=goal-store *]  (apply store [%set-moment [a %end] `~2025.1.15] now)
  =/  [store=goal-store *]  (apply store [%set-moment [b %start] `feb] now)
  =/  [store=goal-store *]  (apply store [%set-moment [b %end] `~2025.2.15] now)
  =/  [store=goal-store *]  (apply store [%set-moment [c %start] `mar] now)
  =/  [store=goal-store *]  (apply store [%set-moment [c %end] `~2025.3.15] now)
  =/  [store=goal-store *]  (apply store [%set-moment [d %start] `apr] now)
  =/  [store=goal-store *]  (apply store [%set-moment [d %end] `~2025.4.15] now)
  =/  [store=goal-store *]  (apply store [%set-moment [e %start] `~2025.5.1] now)
  =/  [store=goal-store *]  (apply store [%set-moment [e %end] `~2025.5.15] now)
  =/  [store=goal-store *]  (apply store [%set-moment [f %start] `jun] now)
  =/  [store=goal-store *]  (apply store [%set-moment [f %end] `~2025.6.15] now)
  (expect !>((validate store)))
::
++  test-memoization-second-path-violation
  ::  diamond: a -> b, a -> c, b -> d, c -> d
  ::  b.end = Mar, c.end = Sep, d.start = Jun
  ::  path through b: bound=Mar, d.start=Jun >= Mar ✓
  ::  path through c: bound=Sep, d.start=Jun < Sep ✗
  ::  meld takes max(Mar,Sep)=Sep, so d.start=Jun < Sep → violation
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store c=goal-id]  (add-child store id-c ~)
  =/  [store=goal-store d=goal-id]  (add-child store id-d ~)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  =/  [store=goal-store *]  (apply store [%link [a %end] [c %start]] now)
  =/  [store=goal-store *]  (apply store [%link [b %end] [d %start]] now)
  =/  [store=goal-store *]  (apply store [%link [c %end] [d %start]] now)
  =/  [store=goal-store *]  (apply store [%set-moment [b %end] `mar] now)
  =/  [store=goal-store *]  (apply store [%set-moment [c %end] `sep] now)
  %-  expect-fail
  |.((apply store [%set-moment [d %start] `jun] now))
::
::  =========================================
::  missing from TS: create
::  =========================================
::
++  test-create-nonexistent-parent-fails
  %-  expect-fail
  |.((apply fresh-store [%create id-a 'fake' ~] now))
::
::  =========================================
::  missing from TS: move with containment edge verification
::  =========================================
::
++  test-move-rewires-containment
  ::  move b from root to a — old containment edges removed, new ones added
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store *]  (apply store [%move b a] now)
  =/  root  (~(got by store) root-id)
  =/  ga  (~(got by store) a)
  =/  gb  (~(got by store) b)
  ;:  weld
    ::  old containment gone: root.start should NOT -> b.start
    %+  expect-eq  !>(%.n)  !>((has-nid outflow.start.root [b %start]))
    ::  old containment gone: b.end should NOT -> root.end
    %+  expect-eq  !>(%.n)  !>((has-nid outflow.end.gb [root-id %end]))
    ::  new containment: a.start -> b.start
    (expect !>((has-nid outflow.start.ga [b %start])))
    ::  new containment: b.end -> a.end
    (expect !>((has-nid outflow.end.gb [a %end])))
    (expect !>((validate store)))
  ==
::
::  =========================================
::  missing from TS: moment ordering — child end after parent end
::  =========================================
::
++  test-moment-child-end-after-parent-end-fails
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]  (apply store [%set-moment [root-id %end] `jun] now)
  %-  expect-fail
  |.((apply store [%set-moment [a %end] `dec] now))
::
::  =========================================
::  missing from TS: completion — diamond scenarios
::  =========================================
::
++  test-completion-diamond-violation
  ::  a -> b, a -> c, b -> d, c -> d (diamond via precedence)
  ::  a and b done, c NOT done, d done → violation
  ::  (c.end incomplete feeds into d via precedence)
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store c=goal-id]  (add-child store id-c ~)
  =/  [store=goal-store d=goal-id]  (add-child store id-d ~)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  =/  [store=goal-store *]  (apply store [%link [a %end] [c %start]] now)
  =/  [store=goal-store *]  (apply store [%link [b %end] [d %start]] now)
  =/  [store=goal-store *]  (apply store [%link [c %end] [d %start]] now)
  ::  mark a done
  =/  [store=goal-store *]  (apply store [%done [a %start]] jan)
  =/  [store=goal-store *]  (apply store [%done [a %end]] feb)
  ::  mark b done
  =/  [store=goal-store *]  (apply store [%done [b %start]] mar)
  =/  [store=goal-store *]  (apply store [%done [b %end]] apr)
  ::  c stays incomplete — try to mark d done → violation
  %-  expect-fail
  |.((apply store [%done [d %start]] jun))
::
++  test-completion-diamond-all-done-valid
  ::  same diamond, all paths complete — should be fine
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store c=goal-id]  (add-child store id-c ~)
  =/  [store=goal-store d=goal-id]  (add-child store id-d ~)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  =/  [store=goal-store *]  (apply store [%link [a %end] [c %start]] now)
  =/  [store=goal-store *]  (apply store [%link [b %end] [d %start]] now)
  =/  [store=goal-store *]  (apply store [%link [c %end] [d %start]] now)
  ::  mark everything done in order
  =/  [store=goal-store *]  (apply store [%done [a %start]] jan)
  =/  [store=goal-store *]  (apply store [%done [a %end]] feb)
  =/  [store=goal-store *]  (apply store [%done [b %start]] mar)
  =/  [store=goal-store *]  (apply store [%done [b %end]] apr)
  =/  [store=goal-store *]  (apply store [%done [c %start]] ~2025.5.1)
  =/  [store=goal-store *]  (apply store [%done [c %end]] jun)
  =/  [store=goal-store *]  (apply store [%done [d %start]] ~2025.7.1)
  =/  [store=goal-store *]  (apply store [%done [d %end]] ~2025.8.1)
  (expect !>((validate store)))
::
++  test-completion-leaf-and-parent-both-done-valid
  ::  child done, then parent done — totally fine
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store *]  (apply store [%done [a %start]] jan)
  =/  [store=goal-store *]  (apply store [%done [a %end]] feb)
  =/  [store=goal-store *]  (apply store [%done [root-id %start]] mar)
  =/  [store=goal-store *]  (apply store [%done [root-id %end]] apr)
  (expect !>((validate store)))
::
::  =========================================
::  missing from TS: deep chain alternating completion
::  =========================================
::
++  test-deep-chain-alternating-completion
  ::  a -> b -> c -> d -> e (precedence chain)
  ::  a done, b done, c NOT done, d done → violation
  ::  (d.start is done but c.end feeds into it and is incomplete)
  =/  [store=goal-store a=goal-id]  (add-child fresh-store id-a ~)
  =/  [store=goal-store b=goal-id]  (add-child store id-b ~)
  =/  [store=goal-store c=goal-id]  (add-child store id-c ~)
  =/  [store=goal-store d=goal-id]  (add-child store id-d ~)
  =/  [store=goal-store e=goal-id]  (add-child store id-e ~)
  =/  [store=goal-store *]  (apply store [%link [a %end] [b %start]] now)
  =/  [store=goal-store *]  (apply store [%link [b %end] [c %start]] now)
  =/  [store=goal-store *]  (apply store [%link [c %end] [d %start]] now)
  =/  [store=goal-store *]  (apply store [%link [d %end] [e %start]] now)
  ::  mark a, b done
  =/  [store=goal-store *]  (apply store [%done [a %start]] jan)
  =/  [store=goal-store *]  (apply store [%done [a %end]] feb)
  =/  [store=goal-store *]  (apply store [%done [b %start]] mar)
  =/  [store=goal-store *]  (apply store [%done [b %end]] apr)
  ::  skip c — try to mark d.start done → violation
  %-  expect-fail
  |.((apply store [%done [d %start]] jun))
::
::  =========================================
::  missing from TS: immutability on failure
::  =========================================
::
++  test-immutability-on-failure
  ::  failed operation should not corrupt the store
  =/  store  fresh-store
  =/  original-size  ~(wyt by store)
  =/  result  (mole |.((apply store [%delete root-id] now)))
  ::  store should be unchanged
  %+  expect-eq  !>(original-size)  !>(~(wyt by store))
--
