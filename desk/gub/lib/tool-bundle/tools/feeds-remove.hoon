/<  tools  /lib/tools.hoon
^-  tool:tools
|%
++  name  'feeds_remove'
++  description
  'Remove an RSS/Atom feed URL and delete its stored items.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['url' [%string 'Feed URL to remove']]
  ==
++  required  ~['url']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  url=@t
    =/  v  (~(get by args.st) 'url')
    ?.(?=([~ %s *] v) '' p.u.v)
  ?:  =('' url)
    (pure:m [%error 'Missing required argument: url'])
  =/  config=road:tarball  [%& %& /apps/'feeds.feeds' %'feeds.json']
  ;<  cfg=view:nexus  bind:m  (peek:io config `[/ %json])
  =/  urls=(list @t)
    ?.  ?=([%file *] cfg)  ~
    =/  jon=json  !<(json (need-vase:tarball sang.cfg))
    ?.  ?=([%a *] jon)  ~
    (murn p.jon |=(j=json ?.(?=([%s *] j) ~ `p.j)))
  ?:  =(~ (find [url]~ urls))
    (pure:m [%text 'Not present.'])
  ;<  ~  bind:m
    %+  over:io  config
    [[/ %json] `json`[%a (turn (skip urls |=(u=@t =(u url))) |=(u=@t s+u))]]
  =/  store=road:tarball
    [%& %& /apps/'feeds.feeds'/store (rap 3 (scot %uv (sham url)) '.feed' ~)]
  ;<  =view:nexus  bind:m  (peek:io store ~)
  ;<  ~  bind:m
    ?.  ?=([%file *] view)  (pure:(fiber:fiber:nexus ,~) ~)
    (cull:io store)
  (pure:m [%text 'Removed.'])
--
