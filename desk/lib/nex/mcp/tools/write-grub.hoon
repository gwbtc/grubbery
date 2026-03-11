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
    "Mark is detected from filename extension "
    "(e.g. .hoon, .txt, .json). Falls back to %txt if unknown. "
    "Set content_type to store as raw mime (e.g. \"text/html\"). "
    "Set mark to convert from mime to a specific mark (e.g. \"hoon\"). "
    "When using mark, omit the extension from the filename — the mark becomes the extension."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Directory path (e.g. "/")']]
      ['name' [%string 'Filename with extension (e.g. "foo.hoon", "notes.txt"). Omit extension when using mark parameter.']]
      ['content' [%string 'Text content to write']]
      ['content_type' [%string 'MIME content type (e.g. "text/html"). When set, stores as raw mime.']]
      ['mark' [%string 'Destination mark (e.g. "hoon", "txt"). Converts from mime to this mark via warm tube.']]
  ==
++  required  ~['path' 'name' 'content']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  file-path=@t  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  file-name=@t  (~(dog jo:json-utils [%o args.st]) /name so:dejs:format)
  =/  content=@t  (~(dog jo:json-utils [%o args.st]) /content so:dejs:format)
  =/  content-type=(unit @t)
    ?~  ct=(~(get jo:json-utils [%o args.st]) /'content_type')  ~
    ?.  ?=([%s *] u.ct)  ~
    ?:  =('' p.u.ct)  ~
    `p.u.ct
  =/  dest-mark=(unit @tas)
    ?~  mk=(~(get jo:json-utils [%o args.st]) /mark)  ~
    ?.  ?=([%s *] u.mk)  ~
    ?:  =('' p.u.mk)  ~
    `p.u.mk
  =/  pax=path  (stab file-path)
  =/  road=road:tarball  [%& %& pax file-name]
  ::  Explicit content_type: store as raw mime with that content-type
  ?^  content-type
    =/  mtype=path  (stab (cat 3 '/' u.content-type))
    =/  src-mime=mime  [mtype (as-octs:mimes:html content)]
    ;<  exists=?  bind:m  (peek-exists:io /check road)
    ?:  exists
      ;<  ~  bind:m  (over:io /write road mime+!>(src-mime))
      (pure:m [%text (crip "Wrote {(trip file-path)}/{(trip file-name)} [{(trip u.content-type)}]")])
    ;<  ~  bind:m  (make:io /write road |+[%.n mime+!>(src-mime) ~])
    (pure:m [%text (crip "Created {(trip file-path)}/{(trip file-name)} [{(trip u.content-type)}]")])
  ::  Build mime cage from content
  =/  src-mime=mime  [/text/plain (as-octs:mimes:html content)]
  ;<  exists=?  bind:m  (peek-exists:io /check road)
  ?:  exists
    ::  Existing file: %over converts mime to file's mark via warm tube
    ;<  ~  bind:m  (over:io /write road mime+!>(src-mime))
    (pure:m [%text (crip "Wrote {(trip file-path)}/{(trip file-name)}")])
  ::  New file: pass dest-mark so runtime converts mime before storing.
  ::  If no mark specified, stores as mime.
  ;<  ~  bind:m  (make:io /write road |+[%.n mime+!>(src-mime) dest-mark])
  =/  mark-msg=tape  ?~(dest-mark "mime" (trip u.dest-mark))
  (pure:m [%text (crip "Created {(trip file-path)}/{(trip file-name)} [{mark-msg}]")])
--
