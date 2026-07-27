::  loops: manage open-loops stores (flat commitments with labels
::  and best-by dates), served by the loops nexus at
::  /apps/loops.loops. Reads peek the store grubs; mutations poke
::  main.sig.
::
/<  tools  /lib/nex/tools.hoon
/<  ol     /lib/open-loops.hoon
/<  iso    /lib/iso-8601.hoon
!:
^-  tool:tools
=>
|%
++  app-root  `path`/apps/'loops.loops'
++  main-road  `road:tarball`[%& %& app-root %'main.sig']
++  store-dir-road  `road:tarball`[%& %| (snoc app-root %store)]
++  store-road
  |=  ctx=@t
  ^-  road:tarball
  [%& %& (snoc app-root %store) (crip "{(trip ctx)}.open-loops")]
::
++  peek-store
  |=  ctx=@t
  =/  m  (fiber:fiber:nexus ,loops:ol)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io (store-road ctx) ~)
  %-  pure:m
  ?.  ?=([%file *] view)  *loops:ol
  (fall (mole |.(!<(loops:ol (need-vase:tarball sang.view)))) *loops:ol)
::
++  render-loop
  |=  [now=@da id=@ud lop=loop:ol]
  ^-  tape
  =/  labels=tape
    ?:  =(~ labels.lop)  ""
    " [{(zing (join ", " (turn ~(tap in labels.lop) trip)))}]"
  =/  best=tape
    ?~  best-by.lop  ""
    =/  d=tape  (en:date-input:iso [[%.y y] m d.t]:(yore u.best-by.lop))
    ?:  (gth now u.best-by.lop)
      " (OVERDUE: best by {d})"
    " (best by {d})"
  "{(a-co:co id)}. {(trip text.lop)}{labels}{best}"
::
++  arg
  |=  [args=(map @t json) k=@t]
  ^-  @t
  =/  j=(unit json)  (~(get by args) k)
  ?.(?=([~ %s *] j) '' p.u.j)
::
++  trim-sp
  |=  t=tape
  ^-  tape
  |-
  ?:  &(?=(^ t) =(' ' i.t))  $(t t.t)
  t
::
++  split-commas
  |=  s=@t
  ^-  (list @t)
  ?:  =('' s)  ~
  =/  toks=(list tape)
    (fall (rush s (most com (star ;~(less com prn)))) ~[(trip s)])
  %+  murn  toks
  |=  t=tape
  =/  c=tape  (trim-sp t)
  ?:(=("" c) ~ `(crip c))
--
|%
++  name  'loops'
++  description
  '''
  Open-loops tracking: flat commitments with labels and best-by dates,
  per context (a named store, e.g. "urbit", "personal"). Commands:
  contexts (list stores), list (context, optional status=open|closed),
  open (context, text, optional labels comma-separated, best_by
  YYYY-MM-DD), close/reopen/delete (context, id), label (context, id,
  add/del comma-separated), best-by (context, id, best_by or empty to
  clear), text (context, id, text). Label taxonomy convention:
  energy:low|high, focus:shallow|deep, time:5m|2h|1w, type:*,
  status:blocked|waiting, domain:*. No urgent label — set best_by.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['command' [%string 'contexts | list | open | close | reopen | delete | label | best-by | text']]
      ['context' [%string 'Store name (e.g. "urbit"). Required for everything except contexts.']]
      ['status' [%string 'For list: open (default) | closed | all']]
      ['text' [%string 'Loop text (open, text)']]
      ['id' [%string 'Loop id (close, reopen, delete, label, best-by, text)']]
      ['labels' [%string 'Comma-separated labels (open)']]
      ['add' [%string 'Comma-separated labels to add (label)']]
      ['del' [%string 'Comma-separated labels to remove (label)']]
      ['best_by' [%string 'YYYY-MM-DD, empty to clear (open, best-by)']]
  ==
++  required  ~['command']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  cmd=@t  (arg args.st 'command')
  =/  ctx=@t  (arg args.st 'context')
  ;<  now=@da  bind:m  get-time:io
  ?:  =('contexts' cmd)
    ;<  =view:nexus  bind:m  (peek:io store-dir-road ~)
    ?.  ?=([%ball *] view)
      (pure:m [%text 'no stores yet'])
    =/  =lump:tarball  (fall fil.ball.view *lump:tarball)
    =/  names=(list tape)
      %+  murn  ~(tap by contents.lump)
      |=  [n=@ta *]
      =/  t=tape  (trip n)
      =/  l=@ud  (lent t)
      ?.  &((gth l 11) =(".open-loops" (slag (sub l 11) t)))  ~
      `(scag (sub l 11) t)
    ?:  =(~ names)  (pure:m [%text 'no stores yet'])
    (pure:m [%text (crip (zing (join "\0a" names)))])
  ?:  =('' ctx)
    (pure:m [%error 'context is required'])
  ?:  =('list' cmd)
    ;<  lops=loops:ol  bind:m  (peek-store ctx)
    =/  status=@t  (arg args.st 'status')
    =/  show-open=?  |(=('' status) =('open' status) =('all' status))
    =/  show-closed=?  |(=('closed' status) =('all' status))
    =/  lines=(list tape)
      %+  weld
        ?.  show-open  ~
        %+  turn  ~(list-open lo:ol lops)
        |=([id=@ud lop=loop:ol] (render-loop now id lop))
      ?.  show-closed  ~
      %+  turn  ~(list-closed lo:ol lops)
      |=([id=@ud lop=loop:ol] "[closed] {(render-loop now id lop)}")
    ?:  =(~ lines)  (pure:m [%text (crip "no loops in {(trip ctx)}")])
    (pure:m [%text (crip (zing (join "\0a" lines)))])
  ::  mutations: build the action json and poke main.sig
  =/  id=@t  (arg args.st 'id')
  =/  jon=json
    :-  %o
    %-  ~(gas by *(map @t json))
    :~  ['action' s+cmd]
        ['context' s+ctx]
        ['text' s+(arg args.st 'text')]
        ['id' n+?:(=('' id) '0' id)]
        ['best_by' s+(arg args.st 'best_by')]
        ['labels' a+(turn (split-commas (arg args.st 'labels')) |=(l=@t s+l))]
        ['add' a+(turn (split-commas (arg args.st 'add')) |=(l=@t s+l))]
        ['del' a+(turn (split-commas (arg args.st 'del')) |=(l=@t s+l))]
    ==
  ;<  ~  bind:m  (poke:io main-road [/ %json] jon)
  ;<  lops=loops:ol  bind:m  (peek-store ctx)
  %-  pure:m
  :-  %text
  %-  crip
  "{(trip cmd)} ok: {(trip ctx)} now has {(a-co:co ~(wyt by open.lops))} open, {(a-co:co ~(wyt by closed.lops))} closed"
--
