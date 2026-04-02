::  goals nexus: DAG-based goal tracking stores with web UI
::
::  /goals.goals/
::    main.sig              creates/deletes stores, accepts JSON action pokes
::    page.html             server-rendered view, re-renders on store changes
::    store/
::      <name>.goal-store   each store is a flat file
::
::  == GOAL DECOMPOSITION & AUDIT ==
::
::  the purpose of this system is to achieve the root goal — completely,
::  thoroughly, and efficiently. every node in the tree exists only to
::  serve that purpose. do not decompose for the sake of decomposing.
::  do not create subgoals to fill out a symmetrical tree. if a goal
::  can be achieved without further breakdown, leave it alone. if a
::  branch doesn't move the root forward, it shouldn't exist.
::
::  not everything needs to be elaborated upfront. a goal can be a
::  placeholder that invites its own decomposition later — "plan the
::  dinner party menu" is a valid actionable goal whose output is
::  more goals. decompose just enough to act, then let the work
::  itself reveal the next level of structure.
::
::  a goal is a predicate over states — a condition that is either met or
::  not. prospectively it's a goal, retrospectively it's a criterion. each
::  goal's start and end nodes encode this: the start node marks entry into
::  the work, the end node marks the completion condition being satisfied.
::
::  every goal's summary MUST describe a state of the world, not an
::  activity. the summary is the criterion — reading it should tell
::  you exactly what's true when this goal is done. the description
::  field holds longer context, rationale, or notes.
::
::  tense and voice depend on the goal's level:
::    - intermediate goals: present tense, as if evaluating from
::      within the achieved state. "fish is a normal weeknight
::      protein" not "learned to cook fish." you are there, looking
::      around, checking whether it's true.
::    - actionable goals: imperative, action-oriented. "make apple
::      tart with pate brisee from scratch" not "made apple tart."
::      these are tasks — something you sit down and do.
::
::  -- actionable goals --
::
::  an actionable goal is a concrete task that can be undertaken in a
::  single focused session. for a human, this means one ultradian
::  rhythm: roughly 90 minutes, at most 4 hours. for an LLM, this
::  means completable before context compression becomes necessary —
::  a single session's worth of coherent work. if it can't be started
::  and finished (or meaningfully advanced to a clear stopping point)
::  in that window, it needs further decomposition.
::
::  CRITICAL: a goal that describes a state requiring weeks or months
::  of effort is NOT actionable, even if it has no children yet. "can
::  make 10 weeknight dinners from memory" is an intermediate goal
::  that needs decomposition into session-sized tasks like "cook the
::  cherry tomato pasta without checking the recipe." do not confuse
::  "describes a concrete state" with "is actionable." a goal can be
::  concrete, state-based, and well-defined while still being far too
::  large for a single session. only mark actionable when someone
::  could literally sit down right now and do it.
::
::  -- decomposing a goal (top-down) --
::
::  to decompose a goal one level down: factor the parent predicate into
::  component predicates along a single axis.
::
::  each subgoal must be:
::    - strictly smaller: governs a proper subset of the parent's concern
::    - independent: satisfiable without reference to sibling implementation
::    - obviously contributing: the relationship to the parent is
::      self-evident, not argued for
::
::  the decomposition should be maximally coarse. find the biggest pieces
::  that are still strictly smaller than the parent and can't be merged
::  without reconstituting it. this prevents skipping levels.
::
::  at every level, a subgoal describes a state to achieve, not a step to
::  take. even at the bottom — where the solution space collapses to one
::  and the subgoal becomes a task — it's still a predicate, just narrow.
::
::  test for correct level: if the subgoal could be satisfied by multiple
::  implementations, it's still at goal level. solution space of one = leaf
::  task. both are valid, but grain should be roughly uniform per level.
::
::  test for skipped levels: if any subset of subgoals can be coherently
::  aggregated into an unnamed goal smaller than the parent but larger than
::  them — that intermediate was skipped. name it, insert it.
::
::  in this system: decomposition = creating children under a parent. the
::  containment edges (parent.start -> child.start, child.end ->
::  parent.end) encode the "strict subset" relationship structurally.
::
::  -- auditing a goal tree (bottom-up) --
::
::  given an existing tree, verify structural coherence from leaves to root.
::  at each node, three checks:
::
::  1. does every child obviously contribute to this parent?
::     look at each child: is it immediately clear what part of the parent
::     it serves? if you have to construct an argument, the child is
::     misplaced or the decomposition axis is wrong.
::
::  2. could any subset of children be grouped under an unnamed intermediate?
::     if yes, a level was skipped. that group should exist as a node.
::
::  3. are the children jointly sufficient?
::     if all children are satisfied, is there a scenario where the parent
::     still isn't? if so, a child is missing.
::
::  4. is each goal well-specified?
::     can you evaluate whether this goal is met without ambiguity?
::     if children seem incoherent or hard to audit, the problem may
::     not be the children — the parent itself may be vague. a fuzzy
::     parent produces fuzzy decompositions. if decomposition is
::     difficult and the difficulty traces to a lack of clarity in
::     the parent, sharpen the parent.
::
::  recurse upward. at every level the parent-child relationship should be
::  boring — self-evident, no surprises.
::
::  failure modes:
::    - orphan goals: children that don't obviously serve their parent.
::      reparent or delete.
::    - missing goals: a parent whose children can't jointly satisfy it.
::      add what's missing.
::    - skipped levels: children that aggregate into natural unnamed groups.
::      insert intermediate nodes.
::    - wrong axis: children that are all coupled or overlapping. the
::      decomposition cut the wrong joint. restructure.
::
/<  goals       /lib/goals.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0] [~ %1])
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 1)
            [%fall %& [/ %'main.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %& [/ %'page.html'] %.n [~ [/ %manx] !>((goals-page ~ ~))]]
            [%fall %| /store [~ ~] [~ ~] empty-dir:loader]
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
          ::  /main.sig: create/delete stores, route JSON action pokes
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%goals /main: failed, poke to restart")
        ~&  >  "%goals /main: ready"
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ?+    name.p.sage
            ~&  >  [%goals-main %unknown-mark name.p.sage]
            $
            %goal-create-store
          =/  name=@ta  !<(@ta q.sage)
          ~&  >  [%goals-main %creating name]
          ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
          =/  store=goal-store:goals  (create-store:goals now.bowl)
          =/  fname=@ta  (store-fname name)
          ;<  ~  bind:m
            (make:io /create [%| 0 %& /store fname] |+[%.n [[/ %goal-store] !>(store)] `%goal-store])
          $
            %goal-delete-store
          =/  name=@ta  !<(@ta q.sage)
          ~&  >  [%goals-main %deleting name]
          ;<  ~  bind:m  (cull:io /delete [%| 0 %& /store (store-fname name)])
          $
          ::  JSON pokes for web UI actions
          ::
            %json
          =/  jon=json  !<(json q.sage)
          ?.  ?=([%o *] jon)  $
          =/  act-type=@t
            (~(dug jo:json-utils jon) /action so:dejs:format '')
          ?+    act-type  $
              %'create-store'
            =/  name=@ta  (~(dog jo:json-utils jon) /name so:dejs:format)
            ~&  >  [%goals-main %creating name]
            ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
            =/  store=goal-store:goals  (create-store:goals now.bowl)
            =/  fname=@ta  (store-fname name)
            ;<  ~  bind:m
              (make:io /create [%| 0 %& /store fname] |+[%.n [[/ %goal-store] !>(store)] `%goal-store])
            $
              %'delete-store'
            =/  name=@ta  (~(dog jo:json-utils jon) /name so:dejs:format)
            ~&  >  [%goals-main %deleting name]
            ;<  ~  bind:m  (cull:io /delete [%| 0 %& /store (store-fname name)])
            $
              %'goal-action'
            =/  store-name=@ta  (~(dog jo:json-utils jon) /store so:dejs:format)
            =/  act-name=@t  (~(dog jo:json-utils jon) /type so:dejs:format)
            ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
            =/  act=action:goals
              ?+    act-name  ~|([%unknown-goal-action act-name] !!)
                  %'create'
                :*  %create
                    ''
                    (~(dug jo:json-utils jon) /parent so:dejs:format '0')
                    ^-  (map @t json)
                    =/  summary=(unit @t)
                      (~(deg jo:json-utils jon) /summary so:dejs:format)
                    ?~  summary  ~
                    (malt ~[['summary' s+u.summary]])
                ==
                  %'delete'
                [%delete (~(dog jo:json-utils jon) /id so:dejs:format)]
                  %'done'
                [%done (~(dog jo:json-utils jon) /id so:dejs:format) %end]
                  %'undone'
                [%undone (~(dog jo:json-utils jon) /id so:dejs:format) %end]
                  %'set-actionable'
                :+  %set-actionable
                  (~(dog jo:json-utils jon) /id so:dejs:format)
                (~(dug jo:json-utils jon) /value bo:dejs:format %.y)
                  %'reorder'
                :+  %reorder
                  (~(dog jo:json-utils jon) /id so:dejs:format)
                (~(deg jo:json-utils jon) /before so:dejs:format)
                  %'update'
                :+  %update
                  (~(dog jo:json-utils jon) /id so:dejs:format)
                ^-  (map @t json)
                =/  data-text=(unit @t)
                  (~(deg jo:json-utils jon) /data so:dejs:format)
                ?~  data-text  ~
                =/  data-jon=json  (need (de:json:html u.data-text))
                ((om:dejs:format same:dejs:format) data-jon)
              ==
            ;<  ~  bind:m
              (poke:io /act [%| 0 %& /store (store-fname store-name)] [[/ %goal-action] !>(act)])
            $
          ==
        ==
          ::  /page.html: server-rendered view, watches store/ for changes
          ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%goals /page: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /stores (cord-to-road:tarball './store/') ~)
        =/  stores=(map @ta goal-store:goals)
          (view-to-stores init)
        =/  store-names=(list @ta)  (sort ~(tap in ~(key by stores)) aor)
        ;<  ~  bind:m  (replace:io !>((goals-page store-names stores)))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /stores)
        =/  stores=(map @ta goal-store:goals)
          (view-to-stores upd)
        =/  store-names=(list @ta)  (sort ~(tap in ~(key by stores)) aor)
        ;<  ~  bind:m  (replace:io !>((goals-page store-names stores)))
        $
          ::  /store/*.goal-store: per-store process
          ::
          [[%store ~] @]
        ?>  ?=(%goal-store mark)
        ;<  ~  bind:m  (rise-wait:io prod "%goals /store: failed, poke to restart")
        =/  store-name=@ta  (store-name-from-fname name.rail)
        ~&  >  [%goals-store store-name %ready]
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ?.  =(%goal-action name.p.sage)
          ~&  >  [%goals-store store-name %unknown-mark name.p.sage]
          $
        =/  act=action:goals  !<(action:goals q.sage)
        ;<  store=goal-store:goals  bind:m  (get-state-as:io ,goal-store:goals)
        ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
        ::  auto-generate ID for create with empty id
        =/  act=action:goals
          ?.  ?=(%create -.act)  act
          ?.  =('' id.act)  act
          =/  n=@da  now.bowl
          |-
          =/  gid=@ta  (crip (scow %uv `@uv`(mug n)))
          ?.  (~(has by store) gid)
            act(id gid)
          $(n (add n ~s0..0001))
        =/  result  (apply:goals store act now.bowl)
        ;<  ~  bind:m  (replace:io !>(-.result))
        ~&  >  [%goals-store store-name %applied -.act]
        $
      ==
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Subdirectory under the goals nexus.'
            ~
          %-  crip
          """
          GOALS NEXUS — DAG-based goal tracking with web UI

          Manages goal stores, each containing a directed acyclic graph of
          goals. Page at /grubbery/api/peek/goals.goals/page.html?mark=mime

          FILES:
            main.sig          Store management + JSON action routing.
            page.html         Server-rendered goal view (manx).

          DIRECTORIES:
            store/            Goal stores (flat files).
          """
            [%store ~]
          'Goal stores. Each file is an independent goal collection.'
        ==
          %|
        ?+  rail.p.mana  'File under the goals nexus.'
          [~ %'main.sig']   'Goals main process. Store management + JSON action routing.'
          [~ %'page.html']  'Server-rendered goals page. Re-renders on store changes.'
        ==
      ==
    --
|%
++  take-poke-from
  =/  m  (fiber:fiber:nexus ,[from=from:fiber:nexus =sage:tarball])
  ^-  form:m
  |=  =input:fiber:nexus
  :+  ~  state.input
  ?+  in.input  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in.input)]
      [~ %poke * *]
    [%done [from sage]:u.in.input]
  ==
::  store-fname: build filename from store name (e.g. 'test' -> 'test.goal-store')
::
++  store-fname
  |=  name=@ta
  ^-  @ta
  (crip "{(trip name)}.goal-store")
::  store-name-from-fname: extract store name from filename
::
++  store-name-from-fname
  |=  fname=@ta
  ^-  @ta
  =/  full=tape  (trip fname)
  =/  suf=tape  ".goal-store"
  (crip (scag (sub (lent full) (lent suf)) full))
::  Peek a store file, return the goal-store
::  Extract stores from a view (directory subscription)
::
++  view-to-stores
  |=  =view:nexus
  ^-  (map @ta goal-store:goals)
  ?.  ?=([%ball *] view)  ~
  ?~  fil.ball.view  ~
  =/  entries=(list [@ta content:tarball])
    ~(tap by contents.u.fil.ball.view)
  =/  out=(map @ta goal-store:goals)  ~
  |-
  ?~  entries  out
  =/  [fname=@ta ct=content:tarball]  i.entries
  ?.  =(%goal-store name.p.sage.ct)  $(entries t.entries)
  =/  store=goal-store:goals  !<(goal-store:goals q.sage.ct)
  =/  sname=@ta  (store-name-from-fname fname)
  $(entries t.entries, out (~(put by out) sname store))
::  Render the full goals page
::
++  goals-page
  |=  [store-names=(list @ta) stores=(map @ta goal-store:goals)]
  ^-  manx
  =/  api=tape  "/grubbery/api"
  =/  base=tape  "goals.goals"
  ;html
    ;head
      ;title: Goals
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  style-text
      ==
    ==
    ;body
      ;div.container
        ::  store list view
        ::
        ;div#store-list
          ;h1: Goals
          ;*  ?~  store-names
                :~  ;p.muted: No stores yet.
                ==
              %+  turn  store-names
              |=  name=@ta
              ^-  manx
              =/  store=goal-store:goals  (~(got by stores) name)
              =/  count=@ud
                (dec ~(wyt by store))
              ;div.store-card(onclick "showStore('{(trip name)}')")
                ;div.store-card-info
                  ;span.store-name: {(trip name)}
                  ;span.muted: {<count>} goals
                ==
                ;button.btn-del(onclick "event.stopPropagation();deleteStore('{(trip name)}')"): x
              ==
          ;div.form-row
            ;input#new-store.input(type "text", placeholder "store-name");
            ;button.btn(onclick "createStore()"): New Store
          ==
        ==
        ::  per-store views (hidden by default)
        ::
        ;*  %+  turn  store-names
            |=  name=@ta
            ^-  manx
            =/  store=goal-store:goals  (~(got by stores) name)
            (render-store name store)
      ==
      ;script
        ;+  ;/
          ;:  weld
            "var API='{api}';var BASE='{base}';"
            js-text
          ==
      ==
    ==
  ==
::  Render a single store view (hidden by default, shown via JS)
::
++  render-store
  |=  [name=@ta store=goal-store:goals]
  ^-  manx
  =/  sn=tape  (trip name)
  =/  root=goal:goals  (get-goal:goals store root-id:goals)
  =/  front=(list goal:goals)  (frontier:goals store root-id:goals)
  =/  tree-kids=(list manx)
    ?~  children.root
      :~  ;p.muted: No goals yet.
      ==
    (render-children name store children.root 0)
  =/  frontier-manx=(list manx)
    ?~  front  ~
    :~  ;div.frontier
          ;h3.sub-header: frontier
          ;*  (turn front |=(g=goal:goals (render-goal-row name g 0)))
        ==
    ==
  =/  root-summary=tape
    =/  sv=(unit json)  (~(get by data.root) 'summary')
    ?.  ?=([~ %s *] sv)  ""
    (trip p.u.sv)
  =/  root-desc=tape
    =/  dv=(unit json)  (~(get by data.root) 'description')
    ?.  ?=([~ %s *] dv)  ""
    (trip p.u.dv)
  ;div.store-view(id "store-{sn}", style "display:none")
    ;div.store-header
      ;button.btn(onclick "showList()"): back
      ;h2: {sn}
      ;div.tab-bar
        ;button.tab.tab-active(id "tab-{sn}-tree", onclick "switchTab('{sn}','tree')"): tree
        ;button.tab(id "tab-{sn}-gantt", onclick "switchTab('{sn}','gantt')"): gantt
      ==
    ==
    ;div.store-meta(id "meta-{sn}")
      ;+  ?.  =(root-summary "")
            ;p.store-summary: {root-summary}
          ;p.store-summary.muted: No summary.
      ;+  ?.  =(root-desc "")
            ;details.store-details
              ;summary: details
              ;p.store-desc: {root-desc}
            ==
          ;span;
      ;button.btn-sm(onclick "editMeta('{sn}')"): edit
    ==
    ;div.tab-panel(id "panel-{sn}-tree")
      ;*  frontier-manx
      ;div.tree-section
        ;h3.sub-header: tree
        ;*  tree-kids
      ==
      ;+  (make-add-row sn "0" 0)
      ;button.btn-sm.add-btn(onclick "startAdd('{sn}','0',0)"): + add goal
    ==
    ;div.tab-panel(id "panel-{sn}-gantt", style "display:none")
      ;+  (render-gantt name store)
    ==
  ==
::  Render children recursively as a tree
::
++  render-children
  |=  [store-name=@ta store=goal-store:goals ids=(list goal-id:goals) depth=@ud]
  ^-  (list manx)
  =/  out=(list manx)  ~
  =/  sn=tape  (trip store-name)
  =/  par-id=tape
    ?~  ids  "0"
    =/  g=goal:goals  (get-goal:goals store i.ids)
    ?~  parent.g  "0"
    (trip u.parent.g)
  |-
  ?~  ids
    =/  final-slot=manx  (make-move-slot sn par-id "" depth)
    (flop [final-slot out])
  =/  g=goal:goals  (get-goal:goals store i.ids)
  =/  gid=tape  (trip id.g)
  =/  slot=manx  (make-move-slot sn par-id gid depth)
  =/  row=manx  (render-goal-row store-name g depth)
  =/  child-depth=@ud  +(depth)
  =/  add=manx
    (make-add-row sn gid child-depth)
  =/  kids=(list manx)
    ?~  children.g  ~
    (render-children store-name store children.g child-depth)
  =/  nested=(list manx)
    ?~  kids  [slot row add ~]
    =/  kids-id=tape  "kids-{sn}-{gid}"
    :~  slot
        row
        ;div.kids-wrap(id kids-id)
          ;+  add
          ;*  kids
        ==
    ==
  $(ids t.ids, out (weld (flop nested) out))
::  Render a move-target slot (hidden by default, shown in move mode)
::
++  make-move-slot
  |=  [sn=tape par-id=tape before=tape depth=@ud]
  ^-  manx
  =/  pad=@t  (crip (scow %ud (mul depth 24)))
  =/  slot-id=tape  "slot-{sn}-{par-id}-{before}"
  =/  onclick=tape  "doMove('{sn}','{before}')"
  ;div.move-slot(id slot-id, style "display:none;padding-left:{(trip pad)}px", onclick onclick)
    ;span.slot-line: -- drop here --
  ==
::  Render an inline add-child input row
::
++  make-add-row
  |=  [sn=tape gid=tape depth=@ud]
  ^-  manx
  =/  pad=@t   (crip (scow %ud (mul depth 24)))
  =/  row-id=@t  (crip "add-{sn}-{gid}")
  =/  sty=@t  (crip "display:none;padding-left:{(trip pad)}px")
  =/  onkey=@t  (crip "addKey(event,'{sn}','{gid}')")
  =/  oncancel=@t  (crip "cancelAdd('{sn}','{gid}')")
  ;div(class "add-row", id (trip row-id), style (trip sty))
    ;input(class "input add-input", type "text", placeholder "new child...", onkeydown (trip onkey));
    ;button(class "btn-sm", onclick (trip oncancel)): esc
  ==
::  Render a single goal row with indentation
::
++  render-goal-row
  |=  [store-name=@ta g=goal:goals depth=@ud]
  ^-  manx
  =/  is-done=?  done.i.status.end.g
  =/  is-started=?  done.i.status.start.g
  =/  summary=tape
    =/  s=(unit json)  (~(get by data.g) 'summary')
    ?.  ?=([~ %s *] s)  ""
    (trip p.u.s)
  =/  status-class=tape
    ?:  is-done     "goal-done"
    ?:  is-started  "goal-started"
    ""
  =/  indent=tape  (reap (mul depth 24) ' ')
  =/  sn=tape  (trip store-name)
  =/  gid=tape  (trip id.g)
  =/  par-id=tape  ?~(parent.g "0" (trip u.parent.g))
  =/  has-kids=?  !=(~ children.g)
  ;div.goal-row(class status-class, style "padding-left: {(scow %ud (mul depth 24))}px")
    ;div.goal-info
      ;*  ?.  has-kids  ~
          :~  ;span.tree-toggle(onclick "toggleKids('{sn}','{gid}')", id "tog-{sn}-{gid}"): v
          ==
      ;button.btn-copy(onclick "copyId('{gid}')", title "{gid}"): #
      ;*  ?.  !=('' (crip summary))  ~
          :~  ;span.goal-summary: {summary}
          ==
      ;*  ?.  actionable.g  ~
          :~  ;span.tag: actionable
          ==
      ;*  ?.  is-done  ~
          :~  ;span.tag-done: done
          ==
      ;*  ?.  &(is-started !is-done)  ~
          :~  ;span.tag-started: started
          ==
    ==
    ;div.goal-actions
      ;*  ?.  is-done
            :~  ;button.btn-sm(onclick "goalAct('{sn}','done','{gid}')"): done
            ==
          :~  ;button.btn-sm(onclick "goalAct('{sn}','undone','{gid}')"): undo
          ==
      ;*  ?.  actionable.g  ~
          :~  ;button.btn-sm(onclick "goalAct('{sn}','set-actionable','{gid}',false)"): unset
          ==
      ;*  ?.  !actionable.g  ~
          :~  ;button.btn-sm(onclick "goalAct('{sn}','set-actionable','{gid}',true)"): actionable
          ==
      ;button.btn-sm(onclick "startAdd('{sn}','{gid}',{(scow %ud +(depth))})"): +
      ;button.btn-sm(onclick "startMove('{sn}','{gid}','{par-id}')"): m
      ;button.btn-del(onclick "goalAct('{sn}','delete','{gid}')"): x
    ==
  ==
::  Render Gantt chart — position by longest dependency chain
::
++  render-gantt
  |=  [name=@ta store=goal-store:goals]
  ^-  manx
  =/  depths=(map @t @ud)  (node-depths:goals store)
  =/  max-depth=@ud
    %+  roll  ~(val by depths)
    |=([d=@ud acc=@ud] (max d acc))
  =/  max-depth=@ud  (max max-depth 1)
  ::  flatten tree with nesting depth
  =/  gds=(list [goal:goals @ud])
    %-  flop
    =/  gid=goal-id:goals  root-id:goals
    =/  lvl=@ud  0
    =|  acc=(list [goal:goals @ud])
    |-
    =/  g=goal:goals  (get-goal:goals store gid)
    =/  acc  ?.  =(gid root-id:goals)  [[g lvl] acc]  acc
    =/  kids=(list goal-id:goals)  children.g
    %+  roll  (flop kids)
    |=  [kid=goal-id:goals acc=_acc]
    ^$(gid kid, lvl +(lvl), acc acc)
  ?~  gds
    ;div.gantt: No goals to chart.
  =/  cols=@ud  +(max-depth)
  =/  sn=tape  (trip name)
  ;div.gantt(id "gantt-{sn}", data-cols (scow %ud cols))
    ;div.gantt-controls
      ;button.btn-sm(onclick "ganttZoom('{sn}',-1)"): -
      ;button.btn-sm(onclick "ganttZoom('{sn}',1)"): +
      ;button.btn-sm(onclick "ganttFit('{sn}')"): fit
    ==
    ;div.gantt-scroll
      ;div.gantt-row.gantt-header
        ;div.gantt-label.gantt-label-header: goal
        ;div.gantt-track.gantt-cols
          ;*  %+  turn  (gulf 0 max-depth)
              |=  n=@ud
              ;span.gantt-col: {(scow %ud n)}
        ==
      ==
      ;*  %+  turn  gds
        |=  [g=goal:goals lvl=@ud]
        =/  skey=@t  (nkey:goals [id.g %start])
        =/  ekey=@t  (nkey:goals [id.g %end])
        =/  s=@ud  (~(gut by depths) skey 0)
        =/  e=@ud  (~(gut by depths) ekey 0)
        =/  summary=tape
          =/  sv=(unit json)  (~(get by data.g) 'summary')
          ?.  ?=([~ %s *] sv)  (trip id.g)
          (trip p.u.sv)
        =/  is-done=?  done.i.status.end.g
        =/  bar-class=tape
          %+  weld  "gantt-bar"
          ?:(is-done " gantt-bar-done" "")
        =/  indent=tape  (scow %ud (mul lvl 12))
        =/  has-kids=?  !=(~ children.g)
        =/  toggle=tape
          ?:  has-kids  "ganttToggle(this.parentNode)"
          ""
        =/  lbl-class=tape
          ?:  has-kids  "gantt-label gantt-label-toggle"
          "gantt-label"
        ;div.gantt-row(data-lvl (scow %ud lvl))
          ;div(class lbl-class, title "{summary}", style "text-indent: {indent}px", onclick toggle): {summary}
          ;div.gantt-track
            ;div(class bar-class, data-start (scow %ud s), data-end (scow %ud e))
              ;+  ;/  summary
            ==
          ==
        ==
    ==
  ==
::
++  js-text
  ^-  tape
  """
  function poke(body,cb)\{
    return fetch(API+'/poke/'+BASE+'/main.sig?mark=json',\{
      method:'POST',
      headers:\{'Content-Type':'application/json'},
      body:JSON.stringify(body)
    }).then(function()\{setTimeout(cb||function()\{location.reload()},300)})
  }
  function showStore(name)\{
    document.getElementById('store-list').style.display='none';
    document.getElementById('store-'+name).style.display='block';
    location.hash=name;
  }
  function showList()\{
    document.querySelectorAll('.store-view').forEach(function(e)\{e.style.display='none'});
    document.getElementById('store-list').style.display='block';
    location.hash='';
  }
  function createStore()\{
    var n=document.getElementById('new-store').value.trim();
    if(!n)return;
    poke(\{action:'create-store',name:n})
  }
  function deleteStore(n)\{
    if(!confirm('Delete store '+n+'?'))return;
    poke(\{action:'delete-store',name:n})
  }
  function startAdd(store,parent,depth)\{
    var row=document.getElementById('add-'+store+'-'+parent);
    row.style.display='flex';
    row.querySelector('input').focus();
  }
  function cancelAdd(store,parent)\{
    var row=document.getElementById('add-'+store+'-'+parent);
    row.style.display='none';
    row.querySelector('input').value='';
  }
  function addKey(e,store,parent)\{
    if(e.key=='Escape')\{cancelAdd(store,parent);return}
    if(e.key!='Enter')return;
    var inp=e.target;
    var summary=inp.value.trim();
    var b=\{action:'goal-action',store:store,type:'create',parent:parent};
    if(summary)b.summary=summary;
    inp.disabled=true;
    poke(b,function()\{location.hash=store;location.reload()})
  }
  function copyId(id)\{
    navigator.clipboard.writeText(id).then(function()\{},function()\{prompt('Goal ID:',id)})
  }
  function toggleKids(store,id)\{
    var el=document.getElementById('kids-'+store+'-'+id);
    var tog=document.getElementById('tog-'+store+'-'+id);
    if(!el)return;
    if(el.style.display==='none')\{el.style.display='';tog.textContent='v'}
    else\{el.style.display='none';tog.textContent='>'}
  }
  var moveState=null;
  function startMove(store,id,parent)\{
    cancelMove();
    moveState=\{store:store,id:id,parent:parent};
    document.querySelectorAll('[id^="slot-'+store+'-'+parent+'-"]').forEach(function(el)\{
      el.style.display='flex'
    });
    document.body.classList.add('moving');
  }
  function cancelMove()\{
    if(!moveState)return;
    document.querySelectorAll('.move-slot').forEach(function(el)\{el.style.display='none'});
    document.body.classList.remove('moving');
    moveState=null;
  }
  function doMove(store,before)\{
    if(!moveState)return;
    var id=moveState.id;
    cancelMove();
    var b=\{action:'goal-action',store:store,type:'reorder',id:id};
    if(before)b.before=before;
    poke(b,function()\{location.hash=store;location.reload()})
  }
  document.addEventListener('keydown',function(e)\{if(e.key==='Escape')cancelMove()});
  function switchTab(store,tab)\{
    document.querySelectorAll('#store-'+store+' .tab-panel').forEach(function(el)\{el.style.display='none'});
    document.getElementById('panel-'+store+'-'+tab).style.display='block';
    document.querySelectorAll('#store-'+store+' .tab').forEach(function(el)\{el.classList.remove('tab-active')});
    document.getElementById('tab-'+store+'-'+tab).classList.add('tab-active');
    if(tab==='gantt')\{if(!ganttScales[store])ganttFit(store);else ganttRender(store)}
  }
  var ganttScales=\{};
  function ganttRender(store)\{
    var el=document.getElementById('gantt-'+store);
    if(!el)return;
    var cols=parseInt(el.dataset.cols);
    var scale=ganttScales[store]||40;
    var w=cols*scale;
    el.querySelectorAll('.gantt-track').forEach(function(t)\{t.style.width=w+'px'});
    el.querySelectorAll('.gantt-col').forEach(function(c)\{c.style.width=scale+'px'});
    el.querySelectorAll('.gantt-bar').forEach(function(b)\{
      var s=parseInt(b.dataset.start);
      var e=parseInt(b.dataset.end);
      b.style.left=(s*scale)+'px';
      b.style.width=(Math.max(1,(e-s+1))*scale)+'px';
    });
  }
  function ganttZoom(store,dir)\{
    var scale=ganttScales[store]||40;
    scale=Math.max(10,Math.min(200,scale+(dir*10)));
    ganttScales[store]=scale;
    ganttRender(store);
  }
  function ganttFit(store)\{
    var el=document.getElementById('gantt-'+store);
    if(!el)return;
    var cols=parseInt(el.dataset.cols);
    var scroll=el.querySelector('.gantt-scroll');
    var labelW=120;
    var avail=scroll.clientWidth-labelW;
    ganttScales[store]=Math.max(10,Math.floor(avail/cols));
    ganttRender(store);
  }
  function ganttToggle(row)\{
    var lvl=parseInt(row.dataset.lvl);
    var collapsed=row.classList.toggle('gantt-collapsed');
    var sib=row.nextElementSibling;
    while(sib&&parseInt(sib.dataset.lvl)>lvl)\{
      sib.style.display=collapsed?'none':'flex';
      if(collapsed)sib.classList.remove('gantt-collapsed');
      sib=sib.nextElementSibling;
    }
  }
  function editMeta(store)\{
    var meta=document.getElementById('meta-'+store);
    var sumEl=meta.querySelector('.store-summary');
    var curSum=sumEl&&!sumEl.classList.contains('muted')?sumEl.textContent:'';
    var descEl=meta.querySelector('.store-desc');
    var curDesc=descEl?descEl.textContent:'';
    meta.innerHTML='<div style="display:flex;flex-direction:column;gap:6px">'
      +'<input id="meta-summary-'+store+'" placeholder="Summary (one line)" value="'+curSum.replace(/"/g,'&amp;quot;')+'" style="font-size:0.85rem;padding:4px 6px;border:1px solid #ccc;border-radius:3px">'
      +'<textarea id="meta-desc-'+store+'" rows="4" placeholder="Description (detailed)" style="font-size:0.8rem;padding:4px 6px;border:1px solid #ccc;border-radius:3px;resize:vertical">'+curDesc+'</textarea>'
      +'<div style="display:flex;gap:4px">'
      +'<button class="btn-sm" onclick="saveMeta(&quot;'+store+'&quot;)">save</button>'
      +'<button class="btn-sm" onclick="location.reload()">cancel</button>'
      +'</div></div>';
  }
  function saveMeta(store)\{
    var summary=document.getElementById('meta-summary-'+store).value;
    var desc=document.getElementById('meta-desc-'+store).value;
    var data=\{};
    if(summary)data.summary=summary;
    if(desc)data.description=desc;
    poke(\{action:'goal-action',store:store,type:'update',id:'0',data:JSON.stringify(data)},
      function()\{location.hash=store;location.reload()});
  }
  function goalAct(store,type,id,val)\{
    var b=\{action:'goal-action',store:store,type:type,id:id};
    if(val!==undefined)b.value=val;
    poke(b,function()\{location.hash=store;location.reload()})
  }
  (function()\{
    var h=location.hash.slice(1);
    if(h)\{var el=document.getElementById('store-'+h);if(el)\{showStore(h)}}
  })();
  """
::
++  style-text
  ^-  tape
  ;:  weld
    "body \{ font-family: monospace; margin: 0; padding: 0; background: #fafafa; } "
    ".container \{ max-width: 700px; margin: 0 auto; padding: 2rem; } "
    "h1 \{ font-size: 1.4rem; margin: 0 0 1rem; } "
    "h2 \{ font-size: 1.1rem; margin: 0; } "
    ".sub-header \{ font-size: 0.85rem; margin: 0 0 4px; opacity: 0.5; } "
    ".muted \{ opacity: 0.5; font-size: 0.85rem; } "
    ".input \{ font-family: monospace; font-size: 0.85rem; padding: 4px 6px; border: 1px solid #ccc; border-radius: 3px; } "
    ".btn \{ font-family: monospace; font-size: 0.85rem; padding: 4px 10px; cursor: pointer; border: 1px solid #ccc; border-radius: 3px; background: #fff; } "
    ".btn:hover \{ background: #eee; } "
    ".btn-sm \{ font-family: monospace; font-size: 0.75rem; padding: 2px 6px; cursor: pointer; border: 1px solid #ccc; border-radius: 3px; background: #fff; } "
    ".btn-sm:hover \{ background: #eee; } "
    ".btn-del \{ font-family: monospace; font-size: 0.75rem; padding: 2px 6px; cursor: pointer; border: 1px solid #daa; border-radius: 3px; background: #fff; color: #a33; } "
    ".btn-del:hover \{ background: #fee; } "
    ".store-card \{ display: flex; justify-content: space-between; align-items: center; "
    "padding: 10px 14px; border: 1px solid #ddd; border-radius: 6px; background: #fff; "
    "margin-bottom: 6px; cursor: pointer; } "
    ".store-card:hover \{ background: #f4f8ff; border-color: #aac; } "
    ".store-card-info \{ display: flex; gap: 12px; align-items: center; } "
    ".store-name \{ font-weight: bold; } "
    ".store-view \{ } "
    ".store-header \{ display: flex; gap: 12px; align-items: center; margin-bottom: 8px; } "
    ".store-meta \{ margin-bottom: 12px; display: flex; align-items: baseline; gap: 8px; flex-wrap: wrap; } "
    ".store-summary \{ font-size: 0.85rem; color: #555; margin: 0; } "
    ".store-details \{ width: 100%; font-size: 0.8rem; color: #666; } "
    ".store-details summary \{ cursor: pointer; opacity: 0.6; font-size: 0.75rem; } "
    ".store-desc \{ margin: 4px 0 0; } "
    ".tree-section \{ margin-bottom: 12px; } "
    ".tree-toggle \{ opacity: 0.4; font-size: 0.7rem; cursor: pointer; user-select: none; } "
    ".tree-toggle:hover \{ opacity: 1; } "
    ".frontier \{ margin-bottom: 12px; padding: 8px; background: #f0f8ff; border-radius: 4px; } "
    ".goal-row \{ display: flex; justify-content: space-between; align-items: center; "
    "padding: 4px 6px; border: 1px solid #eee; border-radius: 3px; margin-bottom: 2px; gap: 8px; } "
    ".goal-done \{ opacity: 0.4; background: #f0fff0; } "
    ".goal-started \{ background: #fffff0; } "
    ".goal-info \{ display: flex; flex-wrap: wrap; gap: 6px; align-items: center; flex: 1; min-width: 0; } "
    ".btn-copy \{ font-family: monospace; font-size: 0.65rem; padding: 1px 4px; cursor: pointer; "
    "border: 1px solid #ddd; border-radius: 2px; background: #f8f8f8; color: #999; opacity: 0.5; } "
    ".btn-copy:hover \{ opacity: 1; background: #eef; color: #369; } "
    ".goal-actions \{ display: flex; gap: 2px; flex-shrink: 0; } "
    ".tag \{ font-size: 0.7rem; padding: 1px 4px; border: 1px solid #acd; border-radius: 2px; color: #369; background: #eef; } "
    ".tag-done \{ font-size: 0.7rem; padding: 1px 4px; border: 1px solid #ada; border-radius: 2px; color: #363; background: #efe; } "
    ".tag-started \{ font-size: 0.7rem; padding: 1px 4px; border: 1px solid #dda; border-radius: 2px; color: #663; background: #ffe; } "
    ".form-row \{ display: flex; gap: 6px; align-items: center; margin-top: 8px; } "
    ".add-row \{ display: flex; gap: 6px; align-items: center; padding: 3px 6px; } "
    ".add-input \{ flex: 1; } "
    ".add-btn \{ margin-top: 6px; opacity: 0.5; } "
    ".add-btn:hover \{ opacity: 1; } "
    ".move-slot \{ padding: 2px 6px; margin: 1px 0; cursor: pointer; border: 1px dashed #aac; "
    "border-radius: 3px; background: #f4f8ff; display: none; } "
    ".move-slot:hover \{ background: #ddeeff; border-color: #69c; } "
    ".slot-line \{ font-size: 0.7rem; opacity: 0.5; } "
    ".moving .goal-row \{ opacity: 0.7; } "
    ".tab-bar \{ display: flex; gap: 4px; margin-left: auto; } "
    ".tab \{ font-family: monospace; font-size: 0.75rem; padding: 2px 8px; cursor: pointer; "
    "border: 1px solid #ccc; border-radius: 3px; background: #fff; } "
    ".tab:hover \{ background: #eee; } "
    ".tab-active \{ background: #333; color: #fff; border-color: #333; } "
    ".tab-active:hover \{ background: #444; } "
    ".gantt \{ margin-top: 8px; border: 1px solid #ddd; border-radius: 6px; "
    "background: #fff; padding: 10px; } "
    ".gantt-controls \{ display: flex; gap: 4px; margin-bottom: 8px; } "
    ".gantt-scroll \{ overflow-x: auto; } "
    ".gantt-row \{ display: flex; align-items: center; margin-bottom: 2px; } "
    ".gantt-label \{ width: 120px; min-width: 120px; flex-shrink: 0; "
    "position: sticky; left: 0; background: #fff; z-index: 1; padding-right: 6px; "
    "font-size: 0.75rem; height: 30px; line-height: 30px; "
    "overflow: hidden; text-overflow: ellipsis; white-space: nowrap; cursor: default; } "
    ".gantt-label-header \{ font-size: 0.7rem; opacity: 0.5; height: 16px; line-height: 16px; } "
    ".gantt-track \{ position: relative; height: 30px; background: #f8f8f8; border-radius: 2px; flex-shrink: 0; } "
    ".gantt-header .gantt-label \{ height: 16px; line-height: 16px; } "
    ".gantt-header .gantt-track \{ display: flex; background: none; height: 16px; } "
    ".gantt-col \{ text-align: center; font-size: 0.6rem; opacity: 0.4; "
    "border-left: 1px solid #eee; } "
    ".gantt-bar \{ position: absolute; top: 2px; bottom: 2px; background: #69c; "
    "border-radius: 2px; font-size: 0.65rem; color: #fff; padding: 0 4px; "
    "overflow: hidden; white-space: nowrap; text-overflow: ellipsis; line-height: 26px; } "
    ".gantt-bar-done \{ background: #9c9; opacity: 0.6; } "
    ".gantt-label-toggle \{ cursor: pointer; } "
    ".gantt-label-toggle::before \{ content: '\\25BE'; margin-right: 4px; opacity: 0.5; } "
    ".gantt-collapsed .gantt-label-toggle::before \{ content: '\\25B8'; } "
  ==
--
