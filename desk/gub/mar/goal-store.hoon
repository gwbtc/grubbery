::  mark for goal-store: DAG-based goal collection state
::
/<  goals  /lib/goals.hoon
=,  format
|_  store=goal-store:goals
++  grab
  |%
  ++  noun  goal-store:goals
  ++  json
    |=  jon=^json
    ^-  goal-store:goals
    ?>  ?=([%o *] jon)
    %-  ~(gas by *goal-store:goals)
    %+  turn  ~(tap by p.jon)
    |=  [key=@t val=^json]
    ^-  [goal-id:goals goal:goals]
    ?>  ?=([%o *] val)
    =/  m  p.val
    =/  gid=goal-id:goals  key
    =/  par=(unit goal-id:goals)
      =/  p  (~(get by m) 'parent')
      ?~  p  ~
      ?:  ?=([~ %~] p)  ~
      ?:  ?=([~ %s *] p)  `p.u.p
      ~
    =/  kids=(list goal-id:goals)
      =/  k  (~(get by m) 'children')
      ?~  k  ~
      ?.  ?=([~ %a *] k)  ~
      (turn p.u.k |=(j=^json ?>(?=(%s -.j) p.j)))
    =/  act=?
      =/  a  (~(get by m) 'actionable')
      ?~  a  %.n
      ?:  ?=([~ %b *] a)  p.u.a
      %.n
    =/  dat=(map @t ^json)
      =/  d  (~(get by m) 'data')
      ?~  d  ~
      ?.  ?=([~ %o *] d)  ~
      p.u.d
    =/  start=node:goals  (parse-node (~(got by m) 'start'))
    =/  end=node:goals    (parse-node (~(got by m) 'end'))
    [gid [id=gid data=dat parent=par children=kids actionable=act start=start end=end]]
  ++  mime
    |=  [p=mite q=octs]
    ^-  goal-store:goals
    (json (need (de:json:html (@t q.q))))
  --
++  grow
  |%
  ++  noun  store
  ++  json
    ^-  ^json
    :-  %o
    %-  ~(gas by *(map @t ^json))
    %+  turn  ~(tap by store)
    |=  [gid=goal-id:goals g=goal:goals]
    ^-  [@t ^json]
    :-  gid
    :-  %o
    %-  ~(gas by *(map @t ^json))
    :~  ['id' s+id.g]
        ['parent' ?~(parent.g ~ s+u.parent.g)]
        ['children' [%a (turn children.g |=(c=goal-id:goals s+c))]]
        ['actionable' b+actionable.g]
        ['data' [%o data.g]]
        ['start' (node-to-json start.g)]
        ['end' (node-to-json end.g)]
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
::
++  node-to-json
  |=  nd=node:goals
  ^-  json
  :-  %o
  %-  ~(gas by *(map @t json))
  :~  ['status' [%a (turn status.nd status-entry-to-json)]]
      ['moment' ?~(moment.nd ~ (numb:enjs:format `@u`u.moment.nd))]
      ['inflow' [%a (turn inflow.nd nid-to-json)]]
      ['outflow' [%a (turn outflow.nd nid-to-json)]]
  ==
::
++  nid-to-json
  |=  nid=node-id:goals
  ^-  json
  :-  %o
  %-  ~(gas by *(map @t json))
  :~  ['goal-id' s+goal-id.nid]
      =/  pt=@t
        ?-  point.nid
          %start  'start'
          %end    'end'
        ==
      ['point' s+pt]
  ==
::
++  status-entry-to-json
  |=  se=status-entry:goals
  ^-  json
  :-  %o
  %-  ~(gas by *(map @t json))
  :~  ['done' b+done.se]
      ['at' (numb:enjs:format `@u`at.se)]
  ==
::
++  parse-node
  |=  jon=json
  ^-  node:goals
  ?>  ?=([%o *] jon)
  =/  m  p.jon
  :*  status=(parse-status (~(got by m) 'status'))
      moment=(parse-moment (~(got by m) 'moment'))
      inflow=(parse-nids (~(got by m) 'inflow'))
      outflow=(parse-nids (~(got by m) 'outflow'))
  ==
::
++  parse-status
  |=  jon=json
  ^-  (lest status-entry:goals)
  ?>  ?=([%a *] jon)
  ?>  ?=(^ p.jon)
  =/  res=(list status-entry:goals)
    %+  turn  p.jon
  |=  j=json
  ?>  ?=([%o *] j)
  =/  m  p.j
  =/  d=json  (~(got by m) 'done')
  =/  a=json  (~(got by m) 'at')
  ?>  ?=([%b *] d)
  ?>  ?=([%n *] a)
  [done=p.d at=`@da`(rash p.a dem)]
  ?>(?=(^ res) res)
::
++  parse-moment
  |=  jon=json
  ^-  (unit @da)
  ?:  ?=(%~ jon)  ~
  ?:  ?=([%n *] jon)  `(rash p.jon dem)
  ~
::
++  parse-nids
  |=  jon=json
  ^-  (list node-id:goals)
  ?.  ?=([%a *] jon)  ~
  %+  turn  p.jon
  |=  j=json
  ^-  node-id:goals
  ?>  ?=([%o *] j)
  =/  m  p.j
  =/  gid=json  (~(got by m) 'goal-id')
  =/  pt=json   (~(got by m) 'point')
  ?>  ?=([%s *] gid)
  ?>  ?=([%s *] pt)
  [goal-id=p.gid point=?:(=('start' p.pt) %start %end)]
--
