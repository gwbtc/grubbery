/<  tools  /lib/nex/tools.hoon
::  write-grub: write a text file to the grubbery ball
::
!:
^-  tool:tools
|%
++  name  'write_grub'
++  description
  ^~  %-  crip
  ;:  weld
    "Write a text file to the grubbery ball. "
    "Set mark to store as a specific mark (e.g. \"hoon\", \"/wallet/account\"). "
    "Without mark, stores as raw mime. "
    "Set content_type to override the mime type (e.g. \"text/html\")."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Directory path (e.g. "/")']]
      ['name' [%string 'Filename (e.g. "foo.hoon", "notes.txt", "config.json")']]
      ['content' [%string 'Text content to write']]
      ['content_type' [%string 'MIME content type (e.g. "text/html"). When set, stores as raw mime.']]
      ['mark' [%string 'Target mark as a blot path (e.g. "hoon", "/wallet/account"). Omit to store as mime.']]
  ==
++  required  ~['path' 'name' 'content']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  file-path=(unit @t)  (~(deg jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  file-name=(unit @t)  (~(deg jo:json-utils [%o args.st]) /name so:dejs:format)
  =/  content-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /content so:dejs:format)
  ?~  file-path
    (pure:m [%error 'Missing required argument: path'])
  ?~  file-name
    (pure:m [%error 'Missing required argument: name'])
  ?~  content-raw
    (pure:m [%error 'Missing required argument: content'])
  =/  content-type=(unit @t)
    ?~  ct=(~(get jo:json-utils [%o args.st]) /'content_type')  ~
    ?.  ?=([%s *] u.ct)  ~
    ?:  =('' p.u.ct)  ~
    `p.u.ct
  =/  dest-blot=(unit blot:tarball)
    ?~  mk=(~(get jo:json-utils [%o args.st]) /mark)  ~
    ?.  ?=([%s *] u.mk)  ~
    ?:  =('' p.u.mk)  ~
    ::  parse as blot path
    =/  pax=path
      ?:  =('/' (end 3 p.u.mk))  (stab p.u.mk)
      (stab (cat 3 '/' p.u.mk))
    ?~  pax  ~
    `[(snip `path`pax) (rear pax)]
  =/  file-path=@t  u.file-path
  =/  file-name=@t  u.file-name
  =/  content=@t  u.content-raw
  =/  pax-parsed=(each path @t)  (parse-path:tools file-path)
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  pax=path  p.pax-parsed
  =/  road=road:tarball  [%& %& pax file-name]
  ::  Explicit content_type: store as raw mime with that content-type
  ?^  content-type
    =/  mtype=path  (stab (cat 3 '/' u.content-type))
    =/  src-mime=mime  [mtype (as-octs:mimes:html content)]
    ;<  exists=?  bind:m  (peek-exists:io road)
    ?:  exists
      ;<  ~  bind:m  (over:io road [[/ %mime] src-mime])
      (pure:m [%text (crip "Wrote {(trip file-path)}/{(trip file-name)} [{(trip u.content-type)}]")])
    ;<  ~  bind:m  (make:io road |+[[[/ %mime] src-mime] ~])
    (pure:m [%text (crip "Created {(trip file-path)}/{(trip file-name)} [{(trip u.content-type)}]")])
  ::  Build mime cage from content
  =/  src-mime=mime  [/text/plain (as-octs:mimes:html content)]
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    ?^  dest-blot
      (pure:m [%error 'Cannot change blot of existing file. Delete it first, then recreate with the desired blot.'])
    ::  Existing file: %over converts mime to file's blot via warm tube
    ;<  ~  bind:m  (over:io road [[/ %mime] src-mime])
    (pure:m [%text (crip "Wrote {(trip file-path)}/{(trip file-name)}")])
  ::  New file: pass dest-blot so runtime converts mime before storing.
  ::  If no blot specified, stores as mime.
  ;<  ~  bind:m  (make:io road |+[[[/ %mime] src-mime] dest-blot])
  =/  blot-msg=tape  ?~(dest-blot "mime" (spud (rail-to-path:tarball u.dest-blot)))
  (pure:m [%text (crip "Created {(trip file-path)}/{(trip file-name)} [{blot-msg}]")])
--
