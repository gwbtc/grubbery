/<  tools  /lib/tools.hoon
^-  tool:tools
|%
++  name  'feeds_add'
++  description
  'Add an RSS/Atom feed URL and trigger an immediate refresh.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['url' [%string 'Feed URL to add']]
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
  ?.  =(~ (find [url]~ urls))
    (pure:m [%text 'Already present.'])
  ;<  ~  bind:m
    %+  over:io  config
    [[/ %json] `json`[%a (turn (snoc urls url) |=(u=@t s+u))]]
  ;<  ~  bind:m
    (poke:io [%& %& /apps/'feeds.feeds' %'refresh.sig'] [[/ %sig] ~])
  (pure:m [%text 'Added; refresh started.'])
--
