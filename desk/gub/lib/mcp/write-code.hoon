/<  tools  /lib/nex/tools.hoon
::  write-code: write hoon to code namespace and check compilation
::
::  Two modes:
::    - Full write: provide 'content' with full source
::    - Edit: provide 'old_string' and 'new_string' to patch existing source
::
::  Writes source to the code ball, which triggers build-code
::  automatically via save-file. Then checks the compiled bin
::  and returns success or the error tang.
::
!:
^-  tool:tools
=>
|%
++  do-check
  |=  [=road:tarball pax=@t nam=@t]
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  res=built:nexus  bind:m  (get-code-full:io /check road)
  ?:  ?=(%vase -.res)
    (pure:m [%text (crip "OK: {(trip pax)}/{(trip nam)} compiled successfully")])
  ?.  ?=(%tang -.res)
    (pure:m [%text (crip "OK: {(trip pax)}/{(trip nam)} — non-vase artifact")])
  =/  rendered=tape
    %-  zing
    %+  turn  (flop tang.res)
    |=(=tank (weld ~(ram re tank) "\0a"))
  (pure:m [%error (crip "COMPILE ERROR: {(trip pax)}/{(trip nam)}\0a{rendered}")])
::
++  do-write
  |=  [src-road=road:tarball bin-road=road:tarball pax=@t nam=@t content=@t]
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  =/  src-mime=mime  [/text/plain (as-octs:mimes:html content)]
  ;<  exists=?  bind:m  (peek-exists:io /check src-road)
  ?:  exists
    ;<  ~  bind:m  (over:io /write src-road [[/ %mime] !>(src-mime)])
    (do-check bin-road pax nam)
  ;<  ~  bind:m  (make:io /write src-road |+[%.n [[/ %mime] !>(src-mime)] `%hoon])
  (do-check bin-road pax nam)
::
++  replace
  |=  [body=tape old=tape new=tape]
  ^-  (unit tape)
  =/  olen=@ud  (lent old)
  =/  blen=@ud  (lent body)
  =/  idx=(unit @ud)  (find old body)
  ?~  idx  ~
  =/  before=tape  (scag u.idx body)
  =/  after=tape   (slag (add u.idx olen) body)
  `:(weld before new after)
--
|%
++  name  'write_code'
++  description
  ^~  %-  crip
  ;:  weld
    "Write or edit Hoon source in the code namespace with immediate "
    "compilation check. Full write: provide 'content'. "
    "Edit: provide 'old_string' and 'new_string' to patch existing source. "
    "path is the directory (e.g. '/lib/mcp'), name is the file stem "
    "without extension (e.g. 'goals')."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Directory in code namespace (e.g. "/lib/mcp", "/mar", "/nex")']]
      ['name' [%string 'File stem without extension (e.g. "goals", "echo")']]
      ['content' [%string 'Full Hoon source (for full write mode)']]
      ['old_string' [%string 'String to find and replace (for edit mode)']]
      ['new_string' [%string 'Replacement string (for edit mode)']]
      ['code' [%string 'Code namespace path (default: "/code")']]
  ==
++  required  ~['path' 'name']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each [@t @t] tang)
    %-  mule  |.
    :-  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
    (~(dog jo:json-utils [%o args.st]) /name so:dejs:format)
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid required arguments (path, name)'])
  =/  [pax=@t nam=@t]  p.parsed
  =/  content=(unit @t)
    (~(deg jo:json-utils [%o args.st]) /content so:dejs:format)
  =/  old-string=(unit @t)
    (~(deg jo:json-utils [%o args.st]) /'old_string' so:dejs:format)
  =/  new-string=(unit @t)
    (~(deg jo:json-utils [%o args.st]) /'new_string' so:dejs:format)
  =/  code-ns=path
    =/  raw=(unit @t)
      ?~  p=(~(get jo:json-utils [%o args.st]) /code)  ~
      ?.  ?=([%s *] u.p)  ~
      ?:  =('' p.u.p)  ~
      `p.u.p
    ?~  raw  /code
    (stab u.raw)
  =/  bin-path=path  (stab pax)
  =/  bin-name=@ta  (crip (trip nam))
  =/  file-name=@ta  (cat 3 bin-name '.hoon')
  =/  src-road=road:tarball  [%& %& (weld code-ns bin-path) file-name]
  =/  bin-road=road:tarball  [%& %& (weld code-ns bin-path) bin-name]
  ::  full write mode
  ?^  content
    (do-write src-road bin-road pax nam u.content)
  ::  edit mode
  ?~  old-string
    (pure:m [%error 'Provide either content (full write) or old_string+new_string (edit)'])
  ?~  new-string
    (pure:m [%error 'Missing required argument: new_string'])
  ::  read current source
  ;<  =seen:nexus  bind:m  (peek:io /read src-road ~)
  ?.  ?=([%& %file *] seen)
    (pure:m [%error (crip "File not found: {(trip pax)}/{(trip nam)}.hoon")])
  =/  current=@t  !<(@t q.sage.p.seen)
  =/  result=(unit tape)
    (replace (trip current) (trip u.old-string) (trip u.new-string))
  ?~  result
    (pure:m [%error (crip "old_string not found in {(trip pax)}/{(trip nam)}.hoon")])
  (do-write src-road bin-road pax nam (crip u.result))
--
