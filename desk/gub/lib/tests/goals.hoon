/<  test   /lib/test.hoon
/<  goals  /lib/goals.hoon
%-  run-tests:test
!>
|%
++  now  ~2025.1.1
++  jan  ~2025.1.1
++  feb  ~2025.2.1
++  mar  ~2025.3.1
++  apr  ~2025.4.1
++  jun  ~2025.6.1
++  sep  ~2025.9.1
++  dec  ~2025.12.1
::
++  fresh-store  (create-store:goals now)
::
++  id-a  `goal-id:goals`'a'
++  id-b  `goal-id:goals`'b'
++  id-c  `goal-id:goals`'c'
++  id-d  `goal-id:goals`'d'
++  id-e  `goal-id:goals`'e'
++  id-f  `goal-id:goals`'f'
::
::  create a child under root, return [store child-id]
++  add-child
  |=  [store=goal-store:goals id=goal-id:goals data=(map @t json)]
  ^-  [goal-store:goals goal-id:goals]
  =/  [s=goal-store:goals mid=(unit goal-id:goals)]
    (apply:goals store [%create id root-id:goals data] now)
  ?>  ?=(^ mid)
  [s u.mid]
::
::  create a child under any parent
++  add-child-to
  |=  [store=goal-store:goals id=goal-id:goals parent=goal-id:goals data=(map @t json)]
  ^-  [goal-store:goals goal-id:goals]
  =/  [s=goal-store:goals mid=(unit goal-id:goals)]
    (apply:goals store [%create id parent data] now)
  ?>  ?=(^ mid)
  [s u.mid]
::
::  =========================================
::  store creation
::  =========================================
::
++  test-create-store
  |.  ^-  tang
  =/  store  fresh-store
  =/  root  (~(got by store) root-id:goals)
  ;:  weld
    %+  expect-eq:test  !>(root-id:goals)  !>(id.root)
    %+  expect-eq:test  !>(~)  !>(parent.root)
    (expect:test !>((validate:goals store)))
  ==
::
::  =========================================
::  create goal
::  =========================================
::
++  test-create-goal
  |.  ^-  tang
  =/  [store=goal-store:goals cid=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  child  (~(got by store) cid)
  =/  root   (~(got by store) root-id:goals)
  ;:  weld
    %+  expect-eq:test  !>(`root-id:goals)  !>(parent.child)
    (expect:test !>((lien children.root |=(c=goal-id:goals =(c cid)))))
    (expect:test !>((validate:goals store)))
  ==
::
++  test-create-nested-children
  |.  ^-  tang
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child-to store id-b a ~)
  =/  ga  (~(got by store) a)
  =/  gb  (~(got by store) b)
  ;:  weld
    (expect:test !>((lien children.ga |=(c=goal-id:goals =(c b)))))
    %+  expect-eq:test  !>(`a)  !>(parent.gb)
    (expect:test !>((validate:goals store)))
  ==
::
++  test-create-three-levels
  |.  ^-  tang
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child-to store id-b a ~)
  =/  [store=goal-store:goals c=goal-id:goals]  (add-child-to store id-c b ~)
  ;:  weld
    %+  expect-eq:test  !>(`a)  !>(parent:(~(got by store) b))
    %+  expect-eq:test  !>(`b)  !>(parent:(~(got by store) c))
    (expect:test !>((validate:goals store)))
  ==
::
++  test-duplicate-id-fails
  |.  ^-  tang
  =/  [store=goal-store:goals *]  (add-child fresh-store id-a ~)
  %-  expect-fail:test
  |.((apply:goals store [%create id-a root-id:goals ~] now))
::
::  =========================================
::  delete goal
::  =========================================
::
++  test-delete-leaf
  |.  ^-  tang
  =/  [store=goal-store:goals cid=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%delete cid] now)
  =/  root  (~(got by store) root-id:goals)
  ;:  weld
    %+  expect-eq:test  !>(~)  !>((~(get by store) cid))
    %+  expect-eq:test  !>(~)  !>(children.root)
    (expect:test !>((validate:goals store)))
  ==
::
++  test-delete-root-fails
  |.  ^-  tang
  %-  expect-fail:test
  |.((apply:goals fresh-store [%delete root-id:goals] now))
::
++  test-delete-with-children-fails
  |.  ^-  tang
  =/  [store=goal-store:goals cid=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals gcid=goal-id:goals]  (add-child-to store id-b cid ~)
  %-  expect-fail:test
  |.((apply:goals store [%delete cid] now))
::
::  =========================================
::  move goal
::  =========================================
::
++  test-move-goal
  |.  ^-  tang
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  ::  move b under a
  =/  [store=goal-store:goals *]  (apply:goals store [%move b a] now)
  =/  ga  (~(got by store) a)
  =/  gb  (~(got by store) b)
  ;:  weld
    %+  expect-eq:test  !>(`a)  !>(parent.gb)
    (expect:test !>((lien children.ga |=(c=goal-id:goals =(c b)))))
    ::  root should no longer list b
    %+  expect-eq:test
      !>(%.n)
      !>((lien children:(~(got by store) root-id:goals) |=(c=goal-id:goals =(c b))))
    (expect:test !>((validate:goals store)))
  ==
::
++  test-move-same-parent-noop
  |.  ^-  tang
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%move a root-id:goals] now)
  ;:  weld
    %+  expect-eq:test  !>(`root-id:goals)  !>(parent:(~(got by store) a))
    (expect:test !>((validate:goals store)))
  ==
::
++  test-move-root-fails
  |.  ^-  tang
  =/  [store=goal-store:goals cid=goal-id:goals]  (add-child fresh-store id-a ~)
  %-  expect-fail:test
  |.((apply:goals store [%move root-id:goals cid] now))
::
++  test-move-rewires-containment
  |.  ^-  tang
  ::  move b from root to a — old containment edges removed, new ones added
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%move b a] now)
  =/  root  (~(got by store) root-id:goals)
  =/  ga  (~(got by store) a)
  =/  gb  (~(got by store) b)
  ;:  weld
    ::  old containment gone: root.start should NOT -> b.start
    %+  expect-eq:test  !>(%.n)  !>((has-nid:goals outflow.start.root [b %start]))
    ::  old containment gone: b.end should NOT -> root.end
    %+  expect-eq:test  !>(%.n)  !>((has-nid:goals outflow.end.gb [root-id:goals %end]))
    ::  new containment: a.start -> b.start
    (expect:test !>((has-nid:goals outflow.start.ga [b %start])))
    ::  new containment: b.end -> a.end
    (expect:test !>((has-nid:goals outflow.end.gb [a %end])))
    (expect:test !>((validate:goals store)))
  ==
::
::  =========================================
::  link / unlink
::  =========================================
::
++  test-link-precedence
  |.  ^-  tang
  ::  a's end -> b's start (precedence: a must finish before b starts)
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals *]
    (apply:goals store [%link [a %end] [b %start]] now)
  =/  ga  (~(got by store) a)
  =/  gb  (~(got by store) b)
  ;:  weld
    (expect:test !>((has-nid:goals outflow.end.ga [b %start])))
    (expect:test !>((has-nid:goals inflow.start.gb [a %end])))
    (expect:test !>((validate:goals store)))
  ==
::
++  test-unlink
  |.  ^-  tang
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals *]
    (apply:goals store [%link [a %end] [b %start]] now)
  =/  [store=goal-store:goals *]
    (apply:goals store [%unlink [a %end] [b %start]] now)
  =/  ga  (~(got by store) a)
  ;:  weld
    %+  expect-eq:test
      !>(%.n)
      !>((has-nid:goals outflow.end.ga [b %start]))
    (expect:test !>((validate:goals store)))
  ==
::
++  test-link-cycle-fails
  |.  ^-  tang
  ::  create two goals, link them in a cycle
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  ::  a.end -> b.start and b.end -> a.start creates a cycle
  =/  [store=goal-store:goals *]
    (apply:goals store [%link [a %end] [b %start]] now)
  %-  expect-fail:test
  |.((apply:goals store [%link [b %end] [a %start]] now))
::
++  test-cycle-three-goals
  |.  ^-  tang
  ::  a -> b -> c -> a cycle
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals c=goal-id:goals]  (add-child store id-c ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [b %end] [c %start]] now)
  %-  expect-fail:test
  |.((apply:goals store [%link [c %end] [a %start]] now))
::
++  test-diamond-dag-no-cycle
  |.  ^-  tang
  ::  a -> b, a -> c, b -> d, c -> d  (diamond, not a cycle)
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals c=goal-id:goals]  (add-child store id-c ~)
  =/  [store=goal-store:goals d=goal-id:goals]  (add-child store id-d ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [c %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [b %end] [d %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [c %end] [d %start]] now)
  (expect:test !>((validate:goals store)))
::
::  =========================================
::  done / undone
::  =========================================
::
++  test-done-marks-node
  |.  ^-  tang
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %start]] feb)
  =/  ga  (~(got by store) a)
  ;:  weld
    (expect:test !>(done.i.status.start.ga))
    ::  history preserved: init entry + done entry = 2
    %+  expect-eq:test  !>(2)  !>((lent status.start.ga))
  ==
::
++  test-undone-pushes-history
  |.  ^-  tang
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %start]] feb)
  =/  [store=goal-store:goals *]  (apply:goals store [%undone [a %start]] mar)
  =/  ga  (~(got by store) a)
  ;:  weld
    %+  expect-eq:test  !>(%.n)  !>(done.i.status.start.ga)
    ::  3 entries: init, done, undone
    %+  expect-eq:test  !>(3)  !>((lent status.start.ga))
  ==
::
++  test-done-undone-end
  |.  ^-  tang
  =/  [store=goal-store:goals cid=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals *]
    (apply:goals store [%done [cid %end]] feb)
  =/  child  (~(got by store) cid)
  =/  top-status  i.status.end.child
  ;:  weld
    (expect:test !>(done.top-status))
    %+  expect-eq:test  !>(feb)  !>(at.top-status)
    ::  undone it
    =/  [store2=goal-store:goals *]  (apply:goals store [%undone [cid %end]] mar)
    =/  child2  (~(got by store2) cid)
    %+  expect-eq:test  !>(%.n)  !>(done.i.status.end.child2)
  ==
::
++  test-done-parent-end-while-child-undone-fails
  |.  ^-  tang
  ::  can't mark root.end done while child.end is still undone
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [root-id:goals %start]] feb)
  %-  expect-fail:test
  |.((apply:goals store [%done [root-id:goals %end]] mar))
::
::  =========================================
::  update data
::  =========================================
::
++  test-update-data
  |.  ^-  tang
  =/  [store=goal-store:goals cid=goal-id:goals]
    (add-child fresh-store id-a (my ~[['name' s+'first']]))
  =/  [store=goal-store:goals *]
    (apply:goals store [%update cid (my ~[['desc' s+'hello']])] now)
  =/  child  (~(got by store) cid)
  ;:  weld
    %+  expect-eq:test  !>(``json`s+'first')  !>((~(get by data.child) 'name'))
    %+  expect-eq:test  !>(``json`s+'hello')  !>((~(get by data.child) 'desc'))
  ==
::
++  test-update-overwrites-existing-key
  |.  ^-  tang
  =/  [store=goal-store:goals cid=goal-id:goals]
    (add-child fresh-store id-a (my ~[['name' s+'first']]))
  =/  [store=goal-store:goals *]
    (apply:goals store [%update cid (my ~[['name' s+'updated']])] now)
  =/  child  (~(got by store) cid)
  %+  expect-eq:test  !>(``json`s+'updated')  !>((~(get by data.child) 'name'))
::
::  =========================================
::  actionable (manual)
::  =========================================
::
++  test-set-actionable
  |.  ^-  tang
  =/  [store=goal-store:goals cid=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals *]
    (apply:goals store [%set-actionable cid %.y] now)
  =/  child  (~(got by store) cid)
  (expect:test !>(actionable.child))
::
++  test-actionable-with-children-fails
  |.  ^-  tang
  ::  can't be actionable if you have children
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child-to store id-b a ~)
  %-  expect-fail:test
  |.((apply:goals store [%set-actionable a %.y] now))
::
::  =========================================
::  actionable (policy)
::  =========================================
::
++  test-create-defaults-actionable
  |.  ^-  tang
  =/  store  (create-store:goals now)
  =/  result  (apply:goals store [%create 'a' '0' ~] now)
  =/  gid  (need +.result)
  =/  g  (get-goal:goals -.result gid)
  (expect:test !>(actionable.g))
::
++  test-parent-loses-actionable-on-create
  |.  ^-  tang
  =/  store  (create-store:goals now)
  =/  r1  (apply:goals store [%create 'a' '0' ~] now)
  =/  gid-a  (need +.r1)
  ::  a should be actionable
  =/  g-a  (get-goal:goals -.r1 gid-a)
  =/  t1  (expect:test !>(actionable.g-a))
  ?^  t1  t1
  ::  create child under a
  =/  r2  (apply:goals -.r1 [%create 'b' gid-a ~] now)
  ::  a should no longer be actionable
  =/  g-a2  (get-goal:goals -.r2 gid-a)
  (expect-eq:test !>(%.n) !>(actionable.g-a2))
::
++  test-child-defaults-actionable
  |.  ^-  tang
  =/  store  (create-store:goals now)
  =/  r1  (apply:goals store [%create 'a' '0' ~] now)
  =/  gid-a  (need +.r1)
  =/  r2  (apply:goals -.r1 [%create 'b' gid-a ~] now)
  =/  gid-b  (need +.r2)
  =/  g-b  (get-goal:goals -.r2 gid-b)
  (expect:test !>(actionable.g-b))
::
++  test-move-unsets-parent-actionable
  |.  ^-  tang
  =/  store  (create-store:goals now)
  =/  r1  (apply:goals store [%create 'a' '0' ~] now)
  =/  gid-a  (need +.r1)
  =/  r2  (apply:goals -.r1 [%create 'b' '0' ~] now)
  =/  gid-b  (need +.r2)
  ::  both should be actionable
  =/  g-a  (get-goal:goals -.r2 gid-a)
  =/  g-b  (get-goal:goals -.r2 gid-b)
  =/  t1  (expect:test !>(actionable.g-a))
  ?^  t1  t1
  =/  t2  (expect:test !>(actionable.g-b))
  ?^  t2  t2
  ::  move b under a
  =/  r3  (apply:goals -.r2 [%move gid-b gid-a] now)
  =/  g-a2  (get-goal:goals -.r3 gid-a)
  (expect-eq:test !>(%.n) !>(actionable.g-a2))
::
++  test-root-not-actionable
  |.  ^-  tang
  =/  store  (create-store:goals now)
  =/  root  (get-goal:goals store root-id:goals)
  ::  root starts not actionable and stays that way after adding child
  =/  t1  (expect-eq:test !>(%.n) !>(actionable.root))
  ?^  t1  t1
  =/  r1  (apply:goals store [%create 'a' '0' ~] now)
  =/  root2  (get-goal:goals -.r1 root-id:goals)
  (expect-eq:test !>(%.n) !>(actionable.root2))
::
::  =========================================
::  set-moment
::  =========================================
::
++  test-set-moment
  |.  ^-  tang
  =/  [store=goal-store:goals cid=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals *]
    (apply:goals store [%set-moment [cid %end] `feb] now)
  =/  child  (~(got by store) cid)
  %+  expect-eq:test  !>(`feb)  !>(moment.end.child)
::
++  test-clear-moment
  |.  ^-  tang
  =/  [store=goal-store:goals cid=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals *]
    (apply:goals store [%set-moment [cid %start] `feb] now)
  =/  [store=goal-store:goals *]
    (apply:goals store [%set-moment [cid %start] ~] now)
  =/  child  (~(got by store) cid)
  %+  expect-eq:test  !>(~)  !>(moment.start.child)
::
::  =========================================
::  moment ordering
::  =========================================
::
++  test-moment-ordering-valid
  |.  ^-  tang
  ::  correctly ordered: parent contains child's moments
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [root-id:goals %start] `jan] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [root-id:goals %end] `dec] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [a %start] `mar] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [a %end] `jun] now)
  (expect:test !>((validate:goals store)))
::
++  test-moment-ordering-partial-ok
  |.  ^-  tang
  ::  only some moments set — should be fine
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [a %start] `mar] now)
  (expect:test !>((validate:goals store)))
::
++  test-moment-child-start-before-parent-fails
  |.  ^-  tang
  ::  child start before parent start
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [root-id:goals %start] `jun] now)
  %-  expect-fail:test
  |.((apply:goals store [%set-moment [a %start] `jan] now))
::
++  test-moment-precedence-violation
  |.  ^-  tang
  ::  if a.end -> b.start, a's end moment can't be after b's start moment
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [b %start] `feb] now)
  %-  expect-fail:test
  |.((apply:goals store [%set-moment [a %end] `mar] now))
::
++  test-moment-precedence-valid
  |.  ^-  tang
  ::  a.end -> b.start, moments correctly ordered
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [a %start] `jan] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [a %end] `mar] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [b %start] `apr] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [b %end] `jun] now)
  (expect:test !>((validate:goals store)))
::
++  test-moment-transitive-through-no-moment
  |.  ^-  tang
  ::  root -> a -> b -> c (tree), a.start=Jun, c.start=Mar
  ::  even though b has no moment, bound propagates through b
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child-to store id-b a ~)
  =/  [store=goal-store:goals c=goal-id:goals]  (add-child-to store id-c b ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [a %start] `jun] now)
  %-  expect-fail:test
  |.((apply:goals store [%set-moment [c %start] `mar] now))
::
++  test-moment-diamond-violation
  |.  ^-  tang
  ::  a -> b, a -> c, b -> d, c -> d (diamond via precedence)
  ::  b.end = Sep, c.end = Mar, d.start = Jun
  ::  path through b says d.start must be >= Sep — violation
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals c=goal-id:goals]  (add-child store id-c ~)
  =/  [store=goal-store:goals d=goal-id:goals]  (add-child store id-d ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [c %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [b %end] [d %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [c %end] [d %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [b %end] `sep] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [c %end] `mar] now)
  %-  expect-fail:test
  |.((apply:goals store [%set-moment [d %start] `jun] now))
::
++  test-moment-diamond-valid
  |.  ^-  tang
  ::  same diamond, but d.start after both paths
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals c=goal-id:goals]  (add-child store id-c ~)
  =/  [store=goal-store:goals d=goal-id:goals]  (add-child store id-d ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [c %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [b %end] [d %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [c %end] [d %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [b %end] `jun] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [c %end] `mar] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [d %start] `sep] now)
  (expect:test !>((validate:goals store)))
::
++  test-moment-child-end-after-parent-end-fails
  |.  ^-  tang
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [root-id:goals %end] `jun] now)
  %-  expect-fail:test
  |.((apply:goals store [%set-moment [a %end] `dec] now))
::
++  test-moment-cross-cutting-precedence
  |.  ^-  tang
  ::  root -> A -> A1, A2; root -> B -> B1, B2
  ::  A2.end -> B1.start (cross-cutting precedence)
  ::  A2.end = Sep, B1.start = Mar → violation
  =/  [store=goal-store:goals a=goal-id:goals]   (add-child fresh-store 'A' ~)
  =/  [store=goal-store:goals b=goal-id:goals]   (add-child store 'B' ~)
  =/  [store=goal-store:goals a1=goal-id:goals]  (add-child-to store 'A1' a ~)
  =/  [store=goal-store:goals a2=goal-id:goals]  (add-child-to store 'A2' a ~)
  =/  [store=goal-store:goals b1=goal-id:goals]  (add-child-to store 'B1' b ~)
  =/  [store=goal-store:goals b2=goal-id:goals]  (add-child-to store 'B2' b ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a2 %end] [b1 %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [a2 %end] `sep] now)
  %-  expect-fail:test
  |.((apply:goals store [%set-moment [b1 %start] `mar] now))
::
::  =========================================
::  completion consistency
::  =========================================
::
++  test-completion-all-incomplete-ok
  |.  ^-  tang
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  (expect:test !>((validate:goals store)))
::
++  test-completion-leaf-done-parent-not-ok
  |.  ^-  tang
  ::  child done, parent still incomplete — that's fine
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %start]] feb)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %end]] mar)
  (expect:test !>((validate:goals store)))
::
++  test-completion-parent-done-child-not-fails
  |.  ^-  tang
  ::  parent.end done while child.end still undone — violation
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  ::  try to mark b.end done while a.end is still undone
  %-  expect-fail:test
  |.((apply:goals store [%done [b %end]] feb))
::
++  test-completion-precedence-valid
  |.  ^-  tang
  ::  a done then b done — fine
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %start]] jan)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %end]] feb)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [b %start]] mar)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [b %end]] apr)
  (expect:test !>((validate:goals store)))
::
++  test-completion-transitive-chain
  |.  ^-  tang
  ::  a.end -> b.start, b.end -> c.start (chain)
  ::  b and c done, a not → violation (b.start done requires a.end done)
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals c=goal-id:goals]  (add-child store id-c ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [b %end] [c %start]] now)
  ::  mark a done first so we can mark b
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %start]] jan)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %end]] feb)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [b %start]] mar)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [b %end]] apr)
  ::  now undone a, creating violation (b.start done but a.end no longer done)
  %-  expect-fail:test
  |.((apply:goals store [%undone [a %end]] jun))
::
++  test-completion-partial-ok
  |.  ^-  tang
  ::  a.end -> b.start: a done, b not yet started — fine
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %start]] jan)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %end]] feb)
  (expect:test !>((validate:goals store)))
::
++  test-completion-diamond-violation
  |.  ^-  tang
  ::  a -> b, a -> c, b -> d, c -> d (diamond via precedence)
  ::  a and b done, c NOT done, d done → violation
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals c=goal-id:goals]  (add-child store id-c ~)
  =/  [store=goal-store:goals d=goal-id:goals]  (add-child store id-d ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [c %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [b %end] [d %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [c %end] [d %start]] now)
  ::  mark a done
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %start]] jan)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %end]] feb)
  ::  mark b done
  =/  [store=goal-store:goals *]  (apply:goals store [%done [b %start]] mar)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [b %end]] apr)
  ::  c stays incomplete — try to mark d done → violation
  %-  expect-fail:test
  |.((apply:goals store [%done [d %start]] jun))
::
++  test-completion-diamond-all-done-valid
  |.  ^-  tang
  ::  same diamond, all paths complete — should be fine
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals c=goal-id:goals]  (add-child store id-c ~)
  =/  [store=goal-store:goals d=goal-id:goals]  (add-child store id-d ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [c %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [b %end] [d %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [c %end] [d %start]] now)
  ::  mark everything done in order
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %start]] jan)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %end]] feb)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [b %start]] mar)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [b %end]] apr)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [c %start]] ~2025.5.1)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [c %end]] jun)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [d %start]] ~2025.7.1)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [d %end]] ~2025.8.1)
  (expect:test !>((validate:goals store)))
::
++  test-completion-leaf-and-parent-both-done-valid
  |.  ^-  tang
  ::  child done, then parent done — totally fine
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %start]] jan)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %end]] feb)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [root-id:goals %start]] mar)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [root-id:goals %end]] apr)
  (expect:test !>((validate:goals store)))
::
++  test-deep-chain-alternating-completion
  |.  ^-  tang
  ::  a -> b -> c -> d -> e (precedence chain)
  ::  a done, b done, c NOT done, d done → violation
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals c=goal-id:goals]  (add-child store id-c ~)
  =/  [store=goal-store:goals d=goal-id:goals]  (add-child store id-d ~)
  =/  [store=goal-store:goals e=goal-id:goals]  (add-child store id-e ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [b %end] [c %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [c %end] [d %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [d %end] [e %start]] now)
  ::  mark a, b done
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %start]] jan)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %end]] feb)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [b %start]] mar)
  =/  [store=goal-store:goals *]  (apply:goals store [%done [b %end]] apr)
  ::  skip c — try to mark d.start done → violation
  %-  expect-fail:test
  |.((apply:goals store [%done [d %start]] jun))
::
::  =========================================
::  containment
::  =========================================
::
++  test-containment-enforced
  |.  ^-  tang
  ::  after create, parent.start -> child.start and child.end -> parent.end
  =/  [store=goal-store:goals cid=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  root  (~(got by store) root-id:goals)
  =/  child  (~(got by store) cid)
  ;:  weld
    (expect:test !>((has-nid:goals outflow.start.root [cid %start])))
    (expect:test !>((has-nid:goals outflow.end.child [root-id:goals %end])))
  ==
::
++  test-containment-nested
  |.  ^-  tang
  ::  containment edges at each level of nesting
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child-to store id-b a ~)
  =/  ga  (~(got by store) a)
  =/  gb  (~(got by store) b)
  ;:  weld
    ::  a.start -> b.start
    (expect:test !>((has-nid:goals outflow.start.ga [b %start])))
    ::  b.end -> a.end
    (expect:test !>((has-nid:goals outflow.end.gb [a %end])))
    (expect:test !>((validate:goals store)))
  ==
::
::  =========================================
::  queries: frontier
::  =========================================
::
++  test-frontier-two-actionable
  |.  ^-  tang
  ::  "what can I do under root?" — two independent actionable goals
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  ::  policy already sets actionable on create
  =/  front  (frontier:goals store root-id:goals)
  %+  expect-eq:test  !>(2)  !>((lent front))
::
++  test-frontier-precedence-blocks
  |.  ^-  tang
  ::  a.end -> b.start (a must finish before b starts)
  ::  "what can I do?" — only a, because b is blocked by a
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  ::  policy already sets actionable on create
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  =/  front  (frontier:goals store root-id:goals)
  %+  expect-eq:test  !>(1)  !>((lent front))
::
++  test-frontier-done-excluded
  |.  ^-  tang
  ::  completed goal shouldn't show up — nothing to do there
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  ::  policy already sets actionable on create
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %end]] feb)
  =/  front  (frontier:goals store root-id:goals)
  %+  expect-eq:test  !>(0)  !>((lent front))
::
++  test-frontier-scoped-to-goal
  |.  ^-  tang
  ::  a has child b (actionable). ask "frontier of a" → {b}
  ::  c is also actionable under root but not under a
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child-to store id-b a ~)
  =/  [store=goal-store:goals c=goal-id:goals]  (add-child store id-c ~)
  ::  policy already sets actionable on create (b and c are actionable)
  ;:  weld
    ::  frontier of a only includes b, not c
    %+  expect-eq:test  !>(1)  !>((lent (frontier:goals store a)))
    ::  frontier of root includes both b and c
    %+  expect-eq:test  !>(2)  !>((lent (frontier:goals store root-id:goals)))
  ==
::
++  test-frontier-chain-only-first
  |.  ^-  tang
  ::  a -> b -> c precedence chain, all actionable
  ::  "what do I need to do first?" — only a
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals c=goal-id:goals]  (add-child store id-c ~)
  ::  policy already sets actionable on create
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [b %end] [c %start]] now)
  =/  front  (frontier:goals store root-id:goals)
  %+  expect-eq:test  !>(1)  !>((lent front))
::
++  test-frontier-all-done-empty
  |.  ^-  tang
  ::  everything under a goal is done → nothing to do
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  ::  policy already sets actionable on create
  =/  [store=goal-store:goals *]  (apply:goals store [%done [a %end]] feb)
  =/  front  (frontier:goals store root-id:goals)
  %+  expect-eq:test  !>(0)  !>((lent front))
::
::  =========================================
::  queries: lineage
::  =========================================
::
++  test-lineage
  |.  ^-  tang
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child-to store id-b a ~)
  =/  lin  (lineage:goals store b)
  %+  expect-eq:test  !>(~[a root-id:goals])  !>(lin)
::
++  test-lineage-root
  |.  ^-  tang
  ::  root's lineage is empty
  =/  lin  (lineage:goals fresh-store root-id:goals)
  %+  expect-eq:test  !>(~)  !>(lin)
::
++  test-lineage-deep
  |.  ^-  tang
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child-to store id-b a ~)
  =/  [store=goal-store:goals c=goal-id:goals]  (add-child-to store id-c b ~)
  =/  lin  (lineage:goals store c)
  %+  expect-eq:test  !>(~[b a root-id:goals])  !>(lin)
::
::  =========================================
::  immutability
::  =========================================
::
++  test-apply-returns-new-store
  |.  ^-  tang
  =/  store  fresh-store
  =/  [new-store=goal-store:goals *]  (apply:goals store [%create id-a root-id:goals ~] now)
  ::  original store should still have just root
  %+  expect-eq:test  !>(1)  !>(~(wyt by store))
::
++  test-immutability-on-failure
  |.  ^-  tang
  ::  failed operation should not corrupt the store
  =/  store  fresh-store
  =/  original-size  ~(wyt by store)
  =/  result  (mole |.((apply:goals store [%delete root-id:goals] now)))
  ::  store should be unchanged
  %+  expect-eq:test  !>(original-size)  !>(~(wyt by store))
::
::  =========================================
::  complex traversal scenarios
::  =========================================
::
++  test-double-diamond-moments
  |.  ^-  tang
  ::     b
  ::   /   \
  :: a       d -> e
  ::   \   /      |
  ::     c    f <-+
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals c=goal-id:goals]  (add-child store id-c ~)
  =/  [store=goal-store:goals d=goal-id:goals]  (add-child store id-d ~)
  =/  [store=goal-store:goals e=goal-id:goals]  (add-child store id-e ~)
  =/  [store=goal-store:goals f=goal-id:goals]  (add-child store id-f ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [c %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [b %end] [d %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [c %end] [d %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [d %end] [e %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [e %end] [f %start]] now)
  ::  all valid moments, increasing left to right
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [a %start] `jan] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [a %end] `~2025.1.15] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [b %start] `feb] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [b %end] `~2025.2.15] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [c %start] `mar] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [c %end] `~2025.3.15] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [d %start] `apr] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [d %end] `~2025.4.15] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [e %start] `~2025.5.1] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [e %end] `~2025.5.15] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [f %start] `jun] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [f %end] `~2025.6.15] now)
  (expect:test !>((validate:goals store)))
::
++  test-memoization-second-path-violation
  |.  ^-  tang
  ::  diamond: a -> b, a -> c, b -> d, c -> d
  ::  b.end = Mar, c.end = Sep, d.start = Jun
  ::  path through b: bound=Mar, d.start=Jun >= Mar ✓
  ::  path through c: bound=Sep, d.start=Jun < Sep ✗
  ::  meld takes max(Mar,Sep)=Sep, so d.start=Jun < Sep → violation
  =/  [store=goal-store:goals a=goal-id:goals]  (add-child fresh-store id-a ~)
  =/  [store=goal-store:goals b=goal-id:goals]  (add-child store id-b ~)
  =/  [store=goal-store:goals c=goal-id:goals]  (add-child store id-c ~)
  =/  [store=goal-store:goals d=goal-id:goals]  (add-child store id-d ~)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [b %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [a %end] [c %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [b %end] [d %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%link [c %end] [d %start]] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [b %end] `mar] now)
  =/  [store=goal-store:goals *]  (apply:goals store [%set-moment [c %end] `sep] now)
  %-  expect-fail:test
  |.((apply:goals store [%set-moment [d %start] `jun] now))
::
++  test-create-nonexistent-parent-fails
  |.  ^-  tang
  %-  expect-fail:test
  |.((apply:goals fresh-store [%create id-a 'fake' ~] now))
--
