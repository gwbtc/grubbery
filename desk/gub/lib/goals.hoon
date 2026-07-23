::  goals: DAG-based goal tracking library
::
::  each goal has start/end nodes connected by directed edges.
::  the DAG encodes priority, precedence, nesting, and containment.
::  a goal collection is a single unit of state with one root goal (id %0).
::
|%
::  types
::
+$  goal-id   @ta
+$  point     ?(%start %end)
+$  node-id   [=goal-id =point]
+$  status-entry  [done=? at=@da]
+$  node
  $:  status=(lest status-entry)       ::  newest first, never empty
      moment=(unit @da)
      inflow=(list node-id)
      outflow=(list node-id)
  ==
+$  goal
  $:  id=goal-id
      data=(map @t json)               ::  arbitrary json data
      parent=(unit goal-id)
      children=(list goal-id)
      actionable=?
      start=node
      end=node
  ==
+$  goal-store  (map goal-id goal)
+$  action
  $%  [%create id=goal-id parent=goal-id data=(map @t json)]
      [%delete id=goal-id]
      [%move id=goal-id new-parent=goal-id]
      [%reorder id=goal-id before=(unit goal-id)]
      [%link from=node-id to=node-id]
      [%unlink from=node-id to=node-id]
      [%done =node-id]
      [%undone =node-id]
      [%update id=goal-id data=(map @t json)]
      [%set-actionable id=goal-id actionable=?]
      [%set-moment =node-id moment=(unit @da)]
  ==
::  constants
::
++  root-id  `goal-id`'0'
::  helpers
::
++  get-goal
  |=  [store=goal-store id=goal-id]
  ^-  goal
  (~(got by store) id)
::
++  get-node
  |=  [store=goal-store nid=node-id]
  ^-  node
  =/  g  (get-goal store goal-id.nid)
  ?-  point.nid
    %start  start.g
    %end    end.g
  ==
::
++  nid-eq
  |=  [a=node-id b=node-id]
  ^-  ?
  &(=(goal-id.a goal-id.b) =(point.a point.b))
::
++  has-nid
  |=  [lis=(list node-id) target=node-id]
  ^-  ?
  %+  lien  lis
  |=(n=node-id (nid-eq n target))
::
++  is-done
  |=  [store=goal-store nid=node-id]
  ^-  ?
  done.i.status:(get-node store nid)
::
++  nkey
  |=  nid=node-id
  ^-  @t
  (crip "{(trip goal-id.nid)}:{(trip ?-(point.nid %start 'start', %end 'end'))}")
::  make fresh start/end nodes for a new goal
::
++  make-nodes
  |=  [id=goal-id now=@da]
  ^-  [start=node end=node]
  :-  :*  status=~[[done=%.n at=now]]
          moment=~
          inflow=~
          outflow=~[[goal-id=id point=%end]]
      ==
  :*  status=~[[done=%.n at=now]]
      moment=~
      inflow=~[[goal-id=id point=%start]]
      outflow=~
  ==
::  set a node on a goal in the store
::
++  put-node
  |=  [store=goal-store nid=node-id =node]
  ^-  goal-store
  =/  g  (get-goal store goal-id.nid)
  =/  g
    ?-  point.nid
      %start  g(start node)
      %end    g(end node)
    ==
  (~(put by store) id.g g)
::  add a directed edge (both directions)
::
++  add-edge
  |=  [store=goal-store from=node-id to=node-id]
  ^-  goal-store
  =/  from-node  (get-node store from)
  =/  to-node    (get-node store to)
  =.  store  (put-node store from from-node(outflow [to outflow.from-node]))
  (put-node store to to-node(inflow [from inflow.to-node]))
::  remove a directed edge (both directions)
::
++  remove-edge
  |=  [store=goal-store from=node-id to=node-id]
  ^-  goal-store
  =/  from-node  (get-node store from)
  =/  to-node    (get-node store to)
  =.  from-node
    from-node(outflow (skip outflow.from-node |=(n=node-id (nid-eq n to))))
  =.  to-node
    to-node(inflow (skip inflow.to-node |=(n=node-id (nid-eq n from))))
  =.  store  (put-node store from from-node)
  (put-node store to to-node)
::  add containment edges (parent.start->child.start, child.end->parent.end)
::
++  add-containment
  |=  [store=goal-store parent-id=goal-id child-id=goal-id]
  ^-  goal-store
  =.  store
    (add-edge store [parent-id %start] [child-id %start])
  (add-edge store [child-id %end] [parent-id %end])
::  remove containment edges
::
++  remove-containment
  |=  [store=goal-store parent-id=goal-id child-id=goal-id]
  ^-  goal-store
  =.  store
    (remove-edge store [parent-id %start] [child-id %start])
  (remove-edge store [child-id %end] [parent-id %end])
::  find root nodes (end nodes with empty outflow)
::
++  root-nodes
  |=  store=goal-store
  ^-  (list node-id)
  =/  goals  ~(val by store)
  |-
  ?~  goals  ~
  =/  g  i.goals
  ?:  =(~ outflow.end.g)
    [[goal-id=id.g point=%end] $(goals t.goals)]
  $(goals t.goals)
::  generic DAG traversal engine
::
::  walks inflow (leftward) from starting nodes with cycle detection
::  and memoization. init/meld/land callbacks control the accumulator.
::
++  traverse-dag
  |*  result=mold
  |=  $:  store=goal-store
          starts=(list node-id)
          init=$-(node-id (unit result))
          meld=$-([acc=(unit result) neighbor=(unit result)] (unit result))
          land=$-([nid=node-id acc=(unit result)] (unit result))
      ==
  ^-  (map @t (unit result))
  =/  visited=(map @t (unit result))  ~
  =/  path=(set @t)  ~
  =|  stack=(list node-id)
  |^
  |-
  ?~  starts  visited
  =/  rvp  (visit i.starts)
  =.  visited  vis.rvp
  =.  path  pat.rvp
  $(starts t.starts)
  ::
  ++  visit
    |=  nid=node-id
    ^-  [res=(unit result) vis=(map @t (unit result)) pat=(set @t)]
    =/  key  (nkey nid)
    ::  already computed
    ?:  (~(has by visited) key)
      [(~(got by visited) key) visited path]
    ::  cycle detection
    ?:  (~(has in path) key)
      ~|("cycle detected at {(trip key)}" !!)
    =.  path  (~(put in path) key)
    ::  compute
    =/  nd  (get-node store nid)
    =/  acc=(unit result)  (init nid)
    =/  neighbors  inflow.nd
    |-
    ?~  neighbors
      ::  done with neighbors, land and memoize
      =/  final  (land nid acc)
      =.  visited  (~(put by visited) key final)
      =.  path  (~(del in path) key)
      [final visited path]
    ::  visit each neighbor, fold into acc
    =/  nvp  (visit i.neighbors)
    =.  visited  vis.nvp
    =.  path  pat.nvp
    =.  acc  (meld acc res.nvp)
    $(neighbors t.neighbors)
  --
::  validation rules
::
::  rule 0: root exists and has no parent
::
++  check-root
  |=  store=goal-store
  ^-  ?
  =/  root  (~(get by store) root-id)
  ?~  root  ~|(%root-missing !!)
  ?^  parent.u.root  ~|(%root-has-parent !!)
  %.y
::  rule 1: parent/child links are bidirectional
::
++  check-parent-child-symmetry
  |=  store=goal-store
  ^-  ?
  =/  goals  ~(val by store)
  |-
  ?~  goals  %.y
  =/  g  i.goals
  ::  check each child points back
  ?.  %+  levy  children.g
      |=  cid=goal-id
      =/  child  (get-goal store cid)
      ?~  parent.child  %.n
      =(u.parent.child id.g)
    ~|([%parent-child-symmetry %child-mismatch id.g] !!)
  ::  check parent lists us
  ?.  ?~  parent.g  %.y
      =/  par  (get-goal store u.parent.g)
      %+  lien  children.par
      |=(c=goal-id =(c id.g))
    ~|([%parent-child-symmetry %parent-mismatch id.g] !!)
  $(goals t.goals)
::  rule 2: graph edges are bidirectional
::
++  check-edge-symmetry
  |=  store=goal-store
  ^-  ?
  =/  goals  ~(val by store)
  |-
  ?~  goals  %.y
  =/  g  i.goals
  ?.  (check-node-edges store [id.g %start])  %.n
  ?.  (check-node-edges store [id.g %end])  %.n
  $(goals t.goals)
::
++  check-node-edges
  |=  [store=goal-store nid=node-id]
  ^-  ?
  =/  nd  (get-node store nid)
  ?.  %+  levy  outflow.nd
      |=  target=node-id
      =/  target-node  (get-node store target)
      (has-nid inflow.target-node nid)
    ~|([%edge-symmetry %outflow-mismatch goal-id.nid point.nid] !!)
  ?.  %+  levy  inflow.nd
      |=  source=node-id
      =/  source-node  (get-node store source)
      (has-nid outflow.source-node nid)
    ~|([%edge-symmetry %inflow-mismatch goal-id.nid point.nid] !!)
  %.y
::  rule 3: no cycles in the DAG
::
++  check-no-cycles
  |=  store=goal-store
  ^-  ?
  =/  all-nodes=(list node-id)
    =/  goals  ~(val by store)
    |-
    ?~  goals  ~
    [[id.i.goals %start] [id.i.goals %end] $(goals t.goals)]
  ::  traverse will crash on cycle
  =/  res
    %.  :*  store
            all-nodes
            |=(=node-id `(unit ?)`(some %.y))
            |=  [acc=(unit ?) nb=(unit ?)]
            ^-  (unit ?)
            (some &(?=(^ acc) u.acc ?=(^ nb) u.nb))
            |=  [=node-id acc=(unit ?)]
            ^-  (unit ?)
            acc
        ==
    (traverse-dag ?)
  %.y
::  rule 4: every goal's start flows into its own end
::
++  check-start-to-end
  |=  store=goal-store
  ^-  ?
  =/  goals  ~(val by store)
  |-
  ?~  goals  %.y
  =/  g  i.goals
  ?.  (has-nid outflow.start.g [id.g %end])
    ~|([%start-to-end %missing-outflow id.g] !!)
  ?.  (has-nid inflow.end.g [id.g %start])
    ~|([%start-to-end %missing-inflow id.g] !!)
  $(goals t.goals)
::  rule 5: parent/child hierarchy matches containment edges
::
++  check-containment
  |=  store=goal-store
  ^-  ?
  =/  goals  ~(val by store)
  |-
  ?~  goals  %.y
  =/  g  i.goals
  ?~  parent.g  $(goals t.goals)
  =/  par  (get-goal store u.parent.g)
  ?.  (has-nid outflow.start.par [id.g %start])
    ~|([%containment %missing-start id.g] !!)
  ?.  (has-nid outflow.end.g [u.parent.g %end])
    ~|([%containment %missing-end id.g] !!)
  $(goals t.goals)
::  rule 6: actionable goals have no end nodes in their end's inflow
::
++  check-actionable
  |=  store=goal-store
  ^-  ?
  =/  goals  ~(val by store)
  |-
  ?~  goals  %.y
  =/  g  i.goals
  ?.  actionable.g  $(goals t.goals)
  =/  has-end-inflow
    %+  lien  inflow.end.g
    |=(n=node-id =(%end point.n))
  ?:  has-end-inflow
    ~|([%actionable-leaf %has-end-inflow id.g] !!)
  $(goals t.goals)
::  rule 7: moments respect graph ordering
::
++  check-moment-ordering
  |=  store=goal-store
  ^-  ?
  =/  roots  (root-nodes store)
  =/  results
    %.  :*  store
            roots
            |=(=node-id `(unit (unit @da))`[~ ~])
            |=  [acc=(unit (unit @da)) nb=(unit (unit @da))]
            ^-  (unit (unit @da))
            ?~  acc  nb
            ?~  nb   acc
            ?~  u.acc  nb
            ?~  u.nb   acc
            [~ [~ `@da`(max u.u.acc u.u.nb)]]
            |=  [nid=node-id bound=(unit (unit @da))]
            ^-  (unit (unit @da))
            =/  nd  (get-node store nid)
            ?~  moment.nd
              bound
            ?~  bound  [~ moment.nd]
            ?~  u.bound  [~ moment.nd]
            ?.  (gte u.moment.nd u.u.bound)
              ~|([%moment-ordering nid u.moment.nd u.u.bound] !!)
            [~ moment.nd]
        ==
    (traverse-dag (unit @da))
  ::  check all visited
  =/  goals  ~(val by store)
  |-
  ?~  goals  %.y
  =/  g  i.goals
  ?.  (~(has by results) (nkey [id.g %start]))
    ~|([%moment-ordering %not-visited id.g %start] !!)
  ?.  (~(has by results) (nkey [id.g %end]))
    ~|([%moment-ordering %not-visited id.g %end] !!)
  $(goals t.goals)
::  rule 8: completion consistency
::
++  check-completion-consistency
  |=  store=goal-store
  ^-  ?
  =/  roots  (root-nodes store)
  =/  results
    %.  :*  store
            roots
            |=(=node-id [~ [~ %.n]])
            |=  [acc=(unit (unit ?)) nb=(unit (unit ?))]
            ^-  (unit (unit ?))
            ?~  acc  nb
            ?~  nb   acc
            ?~  u.acc  ~
            ?~  u.nb   ~
            [~ [~ |(u.u.acc u.u.nb)]]
            |=  [nid=node-id has-left-inc=(unit (unit ?))]
            ^-  (unit (unit ?))
            ?~  has-left-inc  ~
            ?~  u.has-left-inc  ~
            =/  done  (is-done store nid)
            ::  any done node with incomplete inflow is a violation
            ?:  &(done u.u.has-left-inc)
              ~|([%completion-consistency goal-id.nid point.nid] !!)
            ::  start nodes pass through without adding incompleteness
            ?:  =(%start point.nid)  has-left-inc
            ::  end nodes propagate own completion state
            ?:  !done  [~ [~ %.y]]
            [~ [~ %.n]]
        ==
    (traverse-dag (unit ?))
  ::  check all visited
  =/  goals  ~(val by store)
  |-
  ?~  goals  %.y
  =/  g  i.goals
  ?.  (~(has by results) (nkey [id.g %start]))
    ~|([%completion-consistency %not-visited id.g %start] !!)
  ?.  (~(has by results) (nkey [id.g %end]))
    ~|([%completion-consistency %not-visited id.g %end] !!)
  $(goals t.goals)
::  run all validation rules
::
++  validate
  |=  store=goal-store
  ^-  ?
  ?&  (check-root store)
      (check-parent-child-symmetry store)
      (check-edge-symmetry store)
      (check-no-cycles store)
      (check-start-to-end store)
      (check-containment store)
      (check-actionable store)
      (check-moment-ordering store)
      (check-completion-consistency store)
  ==
::  operations
::
::  create a new empty store with just the root goal
::
++  create-store
  |=  now=@da
  ^-  goal-store
  =/  nodes  (make-nodes root-id now)
  =/  root=goal
    :*  id=root-id
        data=~
        parent=~
        children=~
        actionable=%.n
        start=start.nodes
        end=end.nodes
    ==
  (my ~[[root-id root]])
::  apply an action: returns new store (crashes on validation failure)
::
::  This is the policy layer — it dispatches to fundamental operations
::  (apply-create, apply-move, etc) which are purely mechanical, then
::  applies smart defaults on top:
::
::    - new goals default to actionable
::    - adding a child under an actionable parent auto-unsets the parent
::    - moving a goal under an actionable parent auto-unsets the parent
::
::  Anyone wanting different policy can call the fundamental ops directly.
::
++  apply
  |=  [store=goal-store =action now=@da]
  ^-  [goal-store (unit goal-id)]
  =^  new-id  store
    ?-    -.action
        %create
      (apply-create store id.action parent.action data.action now)
        %delete
      [~ (apply-delete store id.action)]
        %move
      [~ (apply-move store id.action new-parent.action)]
        %reorder
      [~ (apply-reorder store id.action before.action)]
        %link
      [~ (add-edge store from.action to.action)]
        %unlink
      [~ (remove-edge store from.action to.action)]
        %done
      [~ (apply-done store node-id.action now)]
        %undone
      [~ (apply-undone store node-id.action now)]
        %update
      [~ (apply-update store id.action data.action)]
        %set-actionable
      =/  g  (get-goal store id.action)
      [~ (~(put by store) id.action g(actionable actionable.action))]
        %set-moment
      =/  nd  (get-node store node-id.action)
      [~ (put-node store node-id.action nd(moment moment.action))]
    ==
  ::  policy: new goals default actionable
  =?  store  ?=(%create -.action)
    =/  cid=goal-id  (need new-id)
    =/  g  (get-goal store cid)
    (~(put by store) cid g(actionable %.y))
  ::  policy: parent loses actionable when it gains a child
  =?  store  ?=(%create -.action)
    =/  par  (get-goal store parent.action)
    ?.  actionable.par  store
    (~(put by store) parent.action par(actionable %.n))
  =?  store  ?=(%move -.action)
    =/  par  (get-goal store new-parent.action)
    ?.  actionable.par  store
    (~(put by store) new-parent.action par(actionable %.n))
  ?>  (validate store)
  [store new-id]
::
++  apply-create
  |=  [store=goal-store id=goal-id parent-id=goal-id data=(map @t json) now=@da]
  ^-  [(unit goal-id) goal-store]
  ?:  (~(has by store) id)  ~|([%id-already-exists id] !!)
  =/  nodes  (make-nodes id now)
  =/  g=goal
    :*  id=id
        data=data
        parent=`parent-id
        children=~
        actionable=%.n
        start=start.nodes
        end=end.nodes
    ==
  =.  store  (~(put by store) id g)
  =/  par  (get-goal store parent-id)
  =.  store  (~(put by store) parent-id par(children [id children.par]))
  =.  store  (add-containment store parent-id id)
  [`id store]
::
++  apply-delete
  |=  [store=goal-store id=goal-id]
  ^-  goal-store
  ?:  =(id root-id)  ~|(%cannot-delete-root !!)
  =/  g  (get-goal store id)
  ?^  children.g  ~|(%cannot-delete-with-children !!)
  ::  remove from parent
  =.  store
    ?~  parent.g  store
    =/  par  (get-goal store u.parent.g)
    =.  par  par(children (skip children.par |=(c=goal-id =(c id))))
    =.  store  (~(put by store) u.parent.g par)
    (remove-containment store u.parent.g id)
  ::  remove all edges involving this goal
  =/  points=(list point)  ~[%start %end]
  |-
  ?~  points  (~(del by store) id)
  =/  pt  i.points
  =/  this-nid=node-id  [id pt]
  =/  nd  (get-node store this-nid)
  ::  remove outflow edges (skip self)
  =.  store
    =/  outs  outflow.nd
    |-
    ?~  outs  store
    ?.  =(goal-id.i.outs id)
      $(outs t.outs, store (remove-edge store this-nid i.outs))
    $(outs t.outs)
  ::  remove inflow edges (skip self)
  =/  nd  (get-node store this-nid)
  =.  store
    =/  ins  inflow.nd
    |-
    ?~  ins  store
    ?.  =(goal-id.i.ins id)
      $(ins t.ins, store (remove-edge store i.ins this-nid))
    $(ins t.ins)
  $(points t.points)
::
++  apply-reorder
  |=  [store=goal-store id=goal-id before=(unit goal-id)]
  ^-  goal-store
  ?:  =(id root-id)  ~|(%cannot-reorder-root !!)
  =/  g  (get-goal store id)
  ?~  parent.g  ~|(%cannot-reorder-orphan !!)
  =/  par  (get-goal store u.parent.g)
  =/  without=(list goal-id)
    (skip children.par |=(c=goal-id =(c id)))
  =/  new-kids=(list goal-id)
    ?~  before  (snoc without id)
    =/  out=(list goal-id)  ~
    =/  rem=_without  without
    |-
    ?~  rem  (flop [id out])
    ?:  =(i.rem u.before)
      (weld (flop [i.rem [id out]]) t.rem)
    $(rem t.rem, out [i.rem out])
  (replace-children store u.parent.g new-kids)
::
++  replace-children
  |=  [store=goal-store parent-id=goal-id new-kids=(list goal-id)]
  ^-  goal-store
  =/  par  (get-goal store parent-id)
  =/  old-set=(set goal-id)  (~(gas in *(set goal-id)) children.par)
  =/  new-set=(set goal-id)  (~(gas in *(set goal-id)) new-kids)
  ?>  =(old-set new-set)
  (~(put by store) parent-id par(children new-kids))
::
++  apply-move
  |=  [store=goal-store id=goal-id new-parent-id=goal-id]
  ^-  goal-store
  ?:  =(id root-id)  ~|(%cannot-move-root !!)
  =/  g  (get-goal store id)
  ?:  ?&(?=(^ parent.g) =(u.parent.g new-parent-id))  store
  ::  remove from old parent
  =.  store
    ?~  parent.g  store
    =/  par  (get-goal store u.parent.g)
    =.  par  par(children (skip children.par |=(c=goal-id =(c id))))
    =.  store  (~(put by store) u.parent.g par)
    (remove-containment store u.parent.g id)
  ::  add to new parent
  =/  new-par  (get-goal store new-parent-id)
  =.  store  (~(put by store) new-parent-id new-par(children [id children.new-par]))
  =.  g  (get-goal store id)
  =.  store  (~(put by store) id g(parent `new-parent-id))
  (add-containment store new-parent-id id)
::
++  apply-done
  |=  [store=goal-store nid=node-id now=@da]
  ^-  goal-store
  =/  nd  (get-node store nid)
  (put-node store nid nd(status [[done=%.y at=now] status.nd]))
::
++  apply-undone
  |=  [store=goal-store nid=node-id now=@da]
  ^-  goal-store
  =/  nd  (get-node store nid)
  (put-node store nid nd(status [[done=%.n at=now] status.nd]))
::
++  apply-update
  |=  [store=goal-store id=goal-id data=(map @t json)]
  ^-  goal-store
  =/  g  (get-goal store id)
  =/  merged  (~(uni by data.g) data)
  (~(put by store) id g(data merged))
::  queries
::
::  harvest: "what can I work on right now to move toward this goal?"
::
::  walk backwards from a goal's end node through ALL inflow edges
::  (containment, precedence, internal start->end — the DAG encodes it all).
::  skip completed goals. an actionable end node with no further incomplete
::  inflow is a harvestable leaf — something you can actually do right now.
::
++  harvest
  |=  [store=goal-store gid=goal-id]
  ^-  (set goal-id)
  =/  visited=(map @t (set goal-id))  ~
  =/  hvp  (visit-harvest store [gid %end] visited)
  (~(got by vis.hvp) (nkey [gid %end]))
::
++  visit-harvest
  |=  [store=goal-store nid=node-id visited=(map @t (set goal-id))]
  ^-  [res=(set goal-id) vis=(map @t (set goal-id))]
  =/  key  (nkey nid)
  ::  memoized
  ?:  (~(has by visited) key)
    [(~(got by visited) key) visited]
  ::  if goal's end is done, skip — completed goals have no harvest
  ?:  done.i.status:(get-node store [goal-id.nid %end])
    =.  visited  (~(put by visited) key ~)
    [~ visited]
  ::  walk incomplete inflow
  =/  nd  (get-node store nid)
  =/  neighbors  inflow.nd
  =/  acc=(set goal-id)  ~
  |-
  ?~  neighbors
    ::  land: if end node with empty harvest and actionable, return {self}
    =/  result=(set goal-id)
      ?.  &(=(~ acc) =(%end point.nid) actionable:(get-goal store goal-id.nid))
        acc
      (~(put in *(set goal-id)) goal-id.nid)
    =.  visited  (~(put by visited) key result)
    [result visited]
  ::  skip completed neighbor goals
  =/  ngid  goal-id.i.neighbors
  ?:  done.i.status:(get-node store [ngid %end])
    $(neighbors t.neighbors)
  ::  recurse
  =/  hvp  (visit-harvest store i.neighbors visited)
  =.  visited  vis.hvp
  $(neighbors t.neighbors, acc (~(uni in acc) res.hvp))
::
::  frontier: harvest as a list of goals
::
++  frontier
  |=  [store=goal-store gid=goal-id]
  ^-  (list goal)
  =/  ids  ~(tap in (harvest store gid))
  (turn ids |=(id=goal-id (get-goal store id)))
::  get lineage (ancestors) from goal to root
::
++  lineage
  |=  [store=goal-store id=goal-id]
  ^-  (list goal-id)
  =/  g  (get-goal store id)
  ?~  parent.g  ~
  [u.parent.g $(id u.parent.g)]
::  compute longest-path depth for each node in the DAG
::  depth = max chain of predecessor nodes. roots = 0.
::
++  node-depths
  |=  store=goal-store
  ^-  (map @t @ud)
  =/  all-nids=(list node-id)
    %-  zing
    %+  turn  ~(val by store)
    |=(g=goal ~[[goal-id=id.g point=%start] [goal-id=id.g point=%end]])
  =/  depths=(map @t @ud)
    (malt (turn all-nids |=(nid=node-id [(nkey nid) 0])))
  ::  relax N times (longest path bounded by node count)
  =/  iters=@ud  (lent all-nids)
  |-
  ?:  =(0 iters)  depths
  =.  depths
    =/  nids=_all-nids  all-nids
    |-
    ?~  nids  depths
    =/  nid=node-id  i.nids
    =/  nd=node  (get-node store nid)
    =/  my-key=@t  (nkey nid)
    =/  my-depth=@ud  (~(got by depths) my-key)
    =/  max-in=@ud
      =/  ins  inflow.nd
      |-
      ?~  ins  0
      (max +((~(gut by depths) (nkey i.ins) 0)) $(ins t.ins))
    ?.  (gth max-in my-depth)
      $(nids t.nids)
    $(nids t.nids, depths (~(put by depths) my-key max-in))
  $(iters (dec iters))
::  flatten goal tree in children-list order (same as tree view)
::
++  flatten-tree
  |=  [store=goal-store gid=goal-id]
  ^-  (list goal)
  =/  g=goal  (get-goal store gid)
  =/  out=(list goal)
    ?.  =(gid root-id)  ~[g]  ~
  =/  kids  children.g
  |-
  ?~  kids  out
  =/  sub  ^$(gid i.kids)
  $(kids t.kids, out (weld out sub))
--
