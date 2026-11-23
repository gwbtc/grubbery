::  +reach-fwd tests: the path walk tells the same watchers as the
::  scan of every watcher that +notify-lanes used before it.
::
/+  *test, nexus, tarball
|%
+$  fwd-t  (axal [dir=subscribers:nexus fil=(map @ta subscribers:nexus)])
+$  hit    [watchers=subscribers:nexus relevant=(set lane:tarball)]
::  ==========================================
::  reference: the old notify-lanes, kept for comparison only
::  ==========================================
::
::  +ref-tap-fwd: every watched target, as +tap-fwd listed them
::
++  ref-tap-fwd
  |=  fwd=fwd-t
  =|  pax=path
  =|  acc=(list [lane:tarball subscribers:nexus])
  |-  ^+  acc
  =.  acc
    ?~  fil.fwd  acc
    =+  nod=u.fil.fwd
    =.  acc  ?~(dir.nod acc [[[%| pax] dir.nod] acc])
    =/  fils  ~(tap by fil.nod)
    |-  ?~  fils  acc
    =?  acc  ?=(^ q.i.fils)  [[[%& pax p.i.fils] q.i.fils] acc]
    $(fils t.fils)
  =/  kids  ~(tap by dir.fwd)
  |-  ?~  kids  acc
  =.  acc  ^$(pax (snoc pax p.i.kids), fwd q.i.kids)
  $(kids t.kids)
::  +ref-notified: check every watched target against every changed lane
::
++  ref-notified
  |=  [fwd=fwd-t changed=(set lane:tarball)]
  ^-  (list [target=lane:tarball hit])
  =/  watched  (ref-tap-fwd fwd)
  =|  out=(list [target=lane:tarball hit])
  |-  ^+  out
  ?~  watched  out
  =/  [target=lane:tarball watchers=subscribers:nexus]  i.watched
  =/  relevant=(set lane:tarball)
    %-  ~(gas in *(set lane:tarball))
    %+  murn  ~(tap in changed)
    |=  chg=lane:tarball
    ^-  (unit lane:tarball)
    ?-    -.target
        %&
      ?.  &(?=(%& -.chg) =(p.chg p.target))  ~
      `chg
        %|
      ?-  -.chg
        %&  ?~((decap:tarball p.target path.p.chg) ~ `chg)
        %|  ?~((decap:tarball p.target p.chg) ~ `chg)
      ==
    ==
  ?:  =(~ relevant)  $(watched t.watched)
  $(watched t.watched, out [[target watchers relevant] out])
::  +new-notified: what the path walk finds, in the same shape
::
++  new-notified
  |=  [fwd=fwd-t changed=(set lane:tarball)]
  ^-  (list [target=lane:tarball hit])
  ~(tap by (reach-fwd:nexus fwd changed))
::  +same: both sides found the same targets, watchers and lanes
::
++  same
  |=  [fwd=fwd-t changed=(set lane:tarball)]
  ^-  ?
  =/  old  (silt (ref-notified fwd changed))
  =/  new  (silt (new-notified fwd changed))
  &(=(old new) =((lent (ref-notified fwd changed)) (lent (new-notified fwd changed))))
::  +lanes: a set of lanes from a list
::
++  lanes
  |=  lst=(list lane:tarball)
  ^-  (set lane:tarball)
  (silt lst)
::  +put-watch: add one watcher of one target, as +sub-put does
::
++  put-watch
  |=  [fwd=fwd-t target=lane:tarball watcher=rail:tarball =wire]
  ^-  fwd-t
  =/  pax=path  ?-(-.target %| p.target, %& path.p.target)
  =/  node=[dir=subscribers:nexus fil=(map @ta subscribers:nexus)]
    (fall (~(get of fwd) pax) [~ ~])
  =.  node
    ?-    -.target
        %|
      node(dir (~(put by dir.node) watcher [wire ~]))
        %&
      =/  old=subscribers:nexus
        (fall (~(get by fil.node) name.p.target) ~)
      node(fil (~(put by fil.node) name.p.target (~(put by old) watcher [wire ~])))
    ==
  (~(put of fwd) pax node)
::  ==========================================
::  random cases
::  ==========================================
::
++  dirs   `(list @ta)`~[%a %b %c]
++  names  `(list @ta)`~[%x %y %z]
++  rails  `(list rail:tarball)`~[[/w1 %p] [/w1 %q] [/w2 %p] [/ %r] [/a %p]]
::  +pick: one random item of a list
::
++  pick
  |*  [rng=_og lst=(list)]
  ^-  [_?>(?=(^ lst) i.lst) _rng]
  =^  n  rng  (rads:rng (lent lst))
  [(snag n lst) rng]
::  +rand-path: a random path of up to :max steps
::
++  rand-path
  |=  [rng=_og max=@ud]
  ^-  [path _rng]
  =^  n  rng  (rads:rng +(max))
  =|  pax=path
  |-  ^-  [path _rng]
  ?:  =(0 n)  [pax rng]
  =^  d  rng  (pick rng dirs)
  $(n (dec n), pax (snoc pax d))
++  rand-lane
  |=  [rng=_og max=@ud]
  ^-  [lane:tarball _rng]
  =^  pax  rng  (rand-path rng max)
  =^  file  rng  (rads:rng 2)
  ?:  =(0 file)  [|+pax rng]
  =^  name  rng  (pick rng names)
  [&+[pax name] rng]
++  rand-fwd
  |=  [rng=_og count=@ud]
  ^-  [fwd-t _rng]
  =|  fwd=fwd-t
  |-  ^-  [fwd-t _rng]
  ?:  =(0 count)  [fwd rng]
  =^  target  rng  (rand-lane rng 3)
  =^  watcher  rng  (pick rng rails)
  =.  fwd  (put-watch fwd target watcher /k)
  $(count (dec count))
++  rand-changed
  |=  [rng=_og count=@ud]
  ^-  [(set lane:tarball) _rng]
  =|  changed=(set lane:tarball)
  |-  ^-  [(set lane:tarball) _rng]
  ?:  =(0 count)  [changed rng]
  =^  chg  rng  (rand-lane rng 4)
  $(count (dec count), changed (~(put in changed) chg))
::  +run-cases: :cases random ships, each checked against many change sets
::
++  run-cases
  |=  [seed=@ cases=@ud]
  ^-  ?
  =/  rng  ~(. og seed)
  |-  ^-  ?
  ?:  =(0 cases)  &
  =^  nw  rng  (rads:rng 16)
  =^  fwd  rng  (rand-fwd rng nw)
  =/  changes=@ud  8
  |-  ^-  ?
  ?:  =(0 changes)  ^$(cases (dec cases))
  =^  nc  rng  (rads:rng 7)
  =^  changed  rng  (rand-changed rng nc)
  ?.  (same fwd changed)  |
  $(changes (dec changes))
::  ==========================================
::  tests
::  ==========================================
::
++  test-random-watchers-and-changes
  %+  expect-eq
    !>  &
  !>  (run-cases 1 400)
::
++  test-random-seed-two
  %+  expect-eq
    !>  &
  !>  (run-cases 0xdead.beef 400)
::
++  test-no-watchers
  %+  expect-eq
    !>  ~
  !>  (new-notified *fwd-t (lanes ~[&+[/a %x] |+/a |+/]))
::
++  test-no-changes
  =/  fwd  (put-watch *fwd-t |+/a [/w %p] /k)
  %+  expect-eq
    !>  ~
  !>  (new-notified fwd *(set lane:tarball))
::
++  test-root-watcher-hears-everything
  =/  fwd  (put-watch *fwd-t |+/ [/w %p] /k)
  =/  changed  (lanes ~[&+[/a/b %x] |+/c |+/])
  ;:  weld
    %+  expect-eq
      !>  [[|+/ [[[/w %p] /k ~] ~ ~] changed] ~]
    !>  (new-notified fwd changed)
    (expect !>((same fwd changed)))
  ==
::
++  test-file-and-dir-watch-same-path
  =/  fwd  (put-watch *fwd-t |+/a [/w %p] /k)
  =.  fwd  (put-watch fwd &+[/a %x] [/w %q] /k)
  =.  fwd  (put-watch fwd &+[/a %y] [/w %q] /k)
  ;:  weld
    ::  a change to x reaches the dir watcher and x's watcher, not y's
    %+  expect-eq
      !>  2
    !>  (lent (new-notified fwd (lanes ~[&+[/a %x]])))
    ::  a change to the dir reaches only the dir watcher
    %+  expect-eq
      !>  1
    !>  (lent (new-notified fwd (lanes ~[|+/a])))
    (expect !>((same fwd (lanes ~[&+[/a %x]]))))
    (expect !>((same fwd (lanes ~[|+/a]))))
    (expect !>((same fwd (lanes ~[&+[/a %x] &+[/a %y] |+/a |+/]))))
  ==
::
++  test-file-watcher-ignores-dir-and-neighbours
  =/  fwd  (put-watch *fwd-t &+[/a %x] [/w %p] /k)
  ;:  weld
    %+  expect-eq
      !>  ~
    !>  (new-notified fwd (lanes ~[|+/a |+/ &+[/a %y] &+[/ %x] &+[/a/b %x]]))
    %+  expect-eq
      !>  1
    !>  (lent (new-notified fwd (lanes ~[&+[/a %x]])))
  ==
::
++  test-change-outside-every-watcher
  =/  fwd  (put-watch *fwd-t |+/a/b [/w %p] /k)
  =.  fwd  (put-watch fwd &+[/a/b %x] [/w %q] /k)
  ;:  weld
    ::  above, beside and below the watched dir
    %+  expect-eq
      !>  ~
    !>  (new-notified fwd (lanes ~[|+/a |+/ |+/c &+[/a %x] &+[/c/b %x]]))
    (expect !>((same fwd (lanes ~[|+/a |+/ |+/c &+[/a %x] &+[/c/b %x]]))))
    ::  below it, a dir watcher hears
    %+  expect-eq
      !>  1
    !>  (lent (new-notified fwd (lanes ~[&+[/a/b/c %x]])))
  ==
--
