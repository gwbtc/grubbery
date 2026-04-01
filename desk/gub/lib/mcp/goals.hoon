::  goals: manage DAG-based goal stores
::
::  Single tool for all goal operations. Command parameter selects the
::  operation. Store files live at /goals.goals/store/*.goal-store.
::
/<  tools  /lib/nex/tools.hoon
/<  goals  /lib/goals.hoon
!:
^-  tool:tools
=>
|%
::  road to a store file (flat: store/<name>.goal-store)
::
++  store-road
  |=  name=@ta
  ^-  road:tarball
  =/  fname=@ta  (crip "{(trip name)}.goal-store")
  [%& %& /'goals.goals'/store fname]
::  road to the store directory
::
++  store-dir-road
  ^-  road:tarball
  [%& %| /'goals.goals'/store]
::  peek a store, return the goal-store
::
++  peek-store
  |=  name=@ta
  =/  m  (fiber:fiber:nexus ,goal-store:goals)
  ^-  form:m
  ;<  =seen:nexus  bind:m
    (peek:io /read (store-road name) ~)
  ?.  ?=([%& %file *] seen)
    ~|(%store-not-found !!)
  (pure:m !<(goal-store:goals q.sage.p.seen))
::  parse a node-id from json fields
::
++  parse-nid
  |=  [jon=json gid-path=path pt-path=path]
  ^-  node-id:goals
  =/  gid=@ta  (~(dog jo:json-utils jon) gid-path so:dejs:format)
  =/  pt=@t  (~(dog jo:json-utils jon) pt-path so:dejs:format)
  :-  gid
  ?:  =('start' pt)  %start
  ?:  =('end' pt)    %end
  !!
::  format a goal as text
::
++  render-goal
  |=  g=goal:goals
  ^-  tape
  =/  data-text=tape
    ?~  data.g  ""
    " {(trip (en:json:html [%o data.g]))}"
  =/  status-text=tape
    ?:  done.i.status.end.g  " [DONE]"
    ?:  done.i.status.start.g  " [STARTED]"
    ""
  =/  parent-text=tape
    ?~  parent.g  ""
    " parent={<u.parent.g>}"
  =/  children-text=tape
    ?~  children.g  ""
    " children={<children.g>}"
  =/  actionable-text=tape
    ?:  actionable.g  " [actionable]"
    ""
  "{<id.g>}{status-text}{actionable-text}{parent-text}{children-text}{data-text}"
::  format a list of goals
::
++  render-goals
  |=  gs=(list goal:goals)
  ^-  @t
  ?~  gs  'No goals found.'
  %-  crip
  %-  zing
  %+  turn  gs
  |=(g=goal:goals (weld (render-goal g) "\0a"))
--
|%
++  name  'goals'
++  description
  ^~  %-  crip
  ;:  weld
    "Manage DAG-based goal tracking stores. "
    "Commands: create-store, delete-store, list-stores, "
    "act, list, get, frontier, lineage. "
    "Actions for 'act': create, delete, move, link, unlink, "
    "done, undone, update, set-actionable, set-moment."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['command' [%string 'Operation: create-store, delete-store, list-stores, act, list, get, frontier, lineage']]
      ['store' [%string 'Store name (e.g. "my-project")']]
      ['action' [%string 'JSON action for act command (e.g. {"type":"create","parent":"0","data":{"summary":"design"}}). id/parent optional for create.']]
      ['goal_id' [%string 'Goal ID for get/frontier/lineage (e.g. "a")']]
  ==
++  required  ~['command']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each @t tang)
    (mule |.((~(dog jo:json-utils [%o args.st]) /command so:dejs:format)))
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid argument: command'])
  =/  command=@t  p.parsed
  =/  store-name=(unit @t)
    (~(deg jo:json-utils [%o args.st]) /store so:dejs:format)
  =/  action-jon=(unit json)
    (~(deg jo:json-utils [%o args.st]) /action same:dejs:format)
  =/  goal-id-text=(unit @t)
    (~(deg jo:json-utils [%o args.st]) /'goal_id' so:dejs:format)
  ::
  ?+  command
    (pure:m [%error (crip "Unknown command: {(trip command)}")])
  ::
      %'create-store'
    ?~  store-name
      (pure:m [%error 'Missing required argument: store'])
    =/  name=@ta  u.store-name
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    =/  store=goal-store:goals  (create-store:goals now.bowl)
    ;<  ~  bind:m
      (make:io /create (store-road name) |+[%.n [[/ %goal-store] !>(store)] `%goal-store])
    (pure:m [%text (crip "Created store: {(trip name)}")])
  ::
      %'delete-store'
    ?~  store-name
      (pure:m [%error 'Missing required argument: store'])
    ;<  ~  bind:m  (cull:io /delete (store-road u.store-name))
    (pure:m [%text (crip "Deleted store: {(trip u.store-name)}")])
  ::
      %'list-stores'
    ;<  =seen:nexus  bind:m
      (peek:io /read store-dir-road ~)
    ?.  ?=([%& %ball *] seen)
      (pure:m [%text 'No stores found.'])
    ?~  fil.ball.p.seen
      (pure:m [%text 'No stores found.'])
    =/  suf=tape  ".goal-store"
    =/  names=(list @ta)
      %+  murn  ~(tap by contents.u.fil.ball.p.seen)
      |=  [fname=@ta *]
      =/  full=tape  (trip fname)
      ?.  (gte (lent full) (lent suf))  ~
      ?.  =((slag (sub (lent full) (lent suf)) full) suf)  ~
      `(crip (scag (sub (lent full) (lent suf)) full))
    ?~  names
      (pure:m [%text 'No stores found.'])
    =/  text=@t
      %-  crip
      %-  zing
      (turn names |=(n=@ta "{(trip n)}\0a"))
    (pure:m [%text text])
  ::
      %'act'
    ?~  store-name
      (pure:m [%error 'Missing required argument: store'])
    ?~  action-jon
      (pure:m [%error 'Missing required argument: action'])
    =/  jon=json  u.action-jon
    ?.  ?=([%o *] jon)
      (pure:m [%error 'Action must be a JSON object'])
    =/  act-parsed=(each [@t action:goals] tang)
      %-  mule  |.
      =/  act-type=@t
        (~(dog jo:json-utils jon) /type so:dejs:format)
      :-  act-type
      ^-  action:goals
      ?+  act-type
        ~|([%unknown-action-type act-type] !!)
      ::
          %'create'
        :*  %create
            (~(dug jo:json-utils jon) /id so:dejs:format '')
            (~(dug jo:json-utils jon) /parent so:dejs:format '0')
            ^-  (map @t json)
            %.  (~(dug jo:json-utils jon) /data same:dejs:format [%o ~])
            (om:dejs:format same:dejs:format)
        ==
          %'delete'
        [%delete (~(dog jo:json-utils jon) /id so:dejs:format)]
          %'move'
        :+  %move
          (~(dog jo:json-utils jon) /id so:dejs:format)
        (~(dog jo:json-utils jon) /'new_parent' so:dejs:format)
          %'reorder'
        :+  %reorder
          (~(dog jo:json-utils jon) /id so:dejs:format)
        (~(deg jo:json-utils jon) /before so:dejs:format)
          %'link'
        :+  %link
          (parse-nid jon /from /'from_point')
        (parse-nid jon /to /'to_point')
          %'unlink'
        :+  %unlink
          (parse-nid jon /from /'from_point')
        (parse-nid jon /to /'to_point')
          %'done'
        [%done (parse-nid jon /'goal_id' /point)]
          %'undone'
        [%undone (parse-nid jon /'goal_id' /point)]
          %'update'
        :+  %update
          (~(dog jo:json-utils jon) /id so:dejs:format)
        ^-  (map @t json)
        %.  (~(dug jo:json-utils jon) /data same:dejs:format [%o ~])
        (om:dejs:format same:dejs:format)
          %'set-actionable'
        :+  %set-actionable
          (~(dog jo:json-utils jon) /id so:dejs:format)
        (~(dog jo:json-utils jon) /actionable bo:dejs:format)
          %'set-moment'
        :+  %set-moment
          (parse-nid jon /'goal_id' /point)
        =/  moment-text=(unit @t)
          (~(deg jo:json-utils jon) /moment so:dejs:format)
        ?~  moment-text  ~
        `(slav %da u.moment-text)
      ==
    ?:  ?=(%| -.act-parsed)
      (pure:m [%error 'Missing or invalid action arguments'])
    =/  act-type=@t  -.p.act-parsed
    =/  act=action:goals  +.p.act-parsed
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    ;<  ~  bind:m
      (poke:io /act (store-road u.store-name) [[/ %goal-action] !>(act)])
    (pure:m [%text (crip "Applied {(trip act-type)}")])
  ::
      ::  list: show all goals in a store
      ::
      %'list'
    ?~  store-name
      (pure:m [%error 'Missing required argument: store'])
    ;<  store=goal-store:goals  bind:m  (peek-store u.store-name)
    =/  gs=(list goal:goals)  ~(val by store)
    (pure:m [%text (render-goals gs)])
  ::
      %'get'
    ?~  store-name
      (pure:m [%error 'Missing required argument: store'])
    ?~  goal-id-text
      (pure:m [%error 'Missing required argument: goal_id'])
    ;<  store=goal-store:goals  bind:m  (peek-store u.store-name)
    =/  g=goal:goals  (get-goal:goals store u.goal-id-text)
    (pure:m [%text (crip (render-goal g))])
  ::
      %'frontier'
    ?~  store-name
      (pure:m [%error 'Missing required argument: store'])
    ;<  store=goal-store:goals  bind:m  (peek-store u.store-name)
    =/  gid=goal-id:goals
      ?~  goal-id-text  root-id:goals
      u.goal-id-text
    =/  front=(list goal:goals)  (frontier:goals store gid)
    (pure:m [%text (render-goals front)])
  ::
      %'lineage'
    ?~  store-name
      (pure:m [%error 'Missing required argument: store'])
    ?~  goal-id-text
      (pure:m [%error 'Missing required argument: goal_id'])
    ;<  store=goal-store:goals  bind:m  (peek-store u.store-name)
    =/  ids=(list goal-id:goals)  (lineage:goals store u.goal-id-text)
    ?~  ids
      (pure:m [%text 'Root goal (no ancestors).'])
    =/  gs=(list goal:goals)
      (turn ids |=(id=goal-id:goals (get-goal:goals store id)))
    (pure:m [%text (render-goals gs)])
  ==
--
