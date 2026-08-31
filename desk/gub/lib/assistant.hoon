::  lib/nex/assistant: the contract an assistant code file satisfies
::
::  An assistant is an autonomous, chat-less LLM-adjacent process: it
::  runs on a recurrence rule, does its work in one pass, and returns
::  an optional notification. Code lives at /code/lib/assistants/*;
::  the instance is a directory under claw's /assistants/ holding
::  main.assistant (code ref, args, recur, zone, enabled) plus
::  whatever state the assistant keeps for itself.
::
|%
::  what a run hands back: ~ = silent run, or a notification
::
+$  output  (unit [title=@t body=@t])
::  the gate an assistant file evaluates to: instance args + the
::  moment this run fired
::
+$  assistant  $-([args=json now=@da] _*form:(fiber:fiber:nexus ,output))
::  +think: one LLM call through claw's anthropic proxy (the calls/
::  lifecycle: poke main.sig, await the call grub reaching %done).
::  Returns ~ on any failure — callers degrade gracefully. Usage is
::  metered by the proxy under caller 'assistant'.
::
++  think
  |=  [model=@t max=@ud system=@t user=@t]
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  id=@t  (scot %uv (end [3 8] eny))
  ;<  proxy=road:tarball  bind:m
    (ancestor-road:io [/claw %app] [%& /apis/anthropic %'main.sig'])
  ;<  call=road:tarball  bind:m
    (ancestor-road:io [/claw %app] [%& /apis/anthropic/calls (crip "{(trip id)}.json")])
  ;<  *  bind:m  (keep:io /think call ~)
  =/  body=json
    %-  pairs:enjs:format
    :~  ['model' s+model]
        ['max_tokens' (numb:enjs:format max)]
        ['system' s+system]
        :-  'messages'
        :-  %a
        ~[(pairs:enjs:format ~[['role' s+'user'] ['content' s+user]])]
    ==
  ;<  ~  bind:m
    %+  poke:io  proxy
    :-  [/ %json]
    (pairs:enjs:format ~[['id' s+id] ['body' body] ['from' s+'assistant']])
  =/  call-file=@ta  (crip "{(trip id)}.json")
  =/  fuel=@ud  120
  |-
  ?:  =(0 fuel)
    ~&  >>>  "%think: fuel exhausted"
    ;<  ~  bind:m  (drop:io /think call)
    (pure:m ~)
  ;<  wav=wave:nexus  bind:m  (take-news:io /think)
  ::  the call fiber self-cleans after writing its result, so the
  ::  latest version may already be gone — peek the wave's version
  ::  of the file, never latest (also survives fiber respawns:
  ::  every pass re-derives its place from the news, not from
  ::  in-flight position)
  =/  hit
    ?~  fil.wav  ~
    (~(get by file.u.fil.wav) call-file)
  ?~  hit  $(fuel (dec fuel))
  ;<  =view:nexus  bind:m  (peek-at:io call ~ [%ud ud.u.hit])
  ?.  ?=([%file *] view)  $(fuel (dec fuel))
  =/  j=json
    (fall (mole |.(!<(json (need-vase:tarball sang.view)))) *json)
  ?.  ?=(%o -.j)  $(fuel (dec fuel))
  =/  status=(unit json)  (~(get by p.j) 'status')
  ?.  ?=([~ %s %done] status)  $(fuel (dec fuel))
  ;<  ~  bind:m  (drop:io /think call)
  ;<  *  bind:m  (cull-soft:io call)
  =/  resp=(unit json)  (~(get by p.j) 'response')
  ?.  ?=([~ %o *] resp)  (pure:m ~)
  =/  content=(unit json)  (~(get by p.u.resp) 'content')
  ?.  ?=([~ %a *] content)
    ~&  >>>  [%think-error (~(get by p.u.resp) 'error')]
    (pure:m ~)
  ::  first text block
  =/  blocks=(list json)  p.u.content
  |-
  ?~  blocks  (pure:m ~)
  ?.  ?=(%o -.i.blocks)  $(blocks t.blocks)
  =/  txt=(unit json)  (~(get by p.i.blocks) 'text')
  ?.  ?=([~ %s *] txt)  $(blocks t.blocks)
  (pure:m `p.u.txt)
::  +read-context: ./context.md from the assistant's own dir, '' if
::  absent. Relative roads resolve against the running fiber's rail,
::  so this works at any depth.
::
++  read-context
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  =view:nexus  bind:m
    (peek:io (cord-to-road:tarball './context.md') `[/ %txt])
  ?.  ?=([%file *] view)  (pure:m '')
  =/  as-wain=(unit wain)  (mole |.(!<(wain (need-vase:tarball sang.view))))
  ?^  as-wain  (pure:m (of-wain:format u.as-wain))
  (pure:m (fall (mole |.(!<(@t (need-vase:tarball sang.view)))) ''))
--
