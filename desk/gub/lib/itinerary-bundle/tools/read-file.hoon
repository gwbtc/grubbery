/<  tools  /lib/tools.hoon
::  read_file: read one attachment of an itinerary. Text files (notes,
::  markdown, json, csv...) come back verbatim; binaries (images, PDFs)
::  come back as a one-line summary — the agent's tool loop is text-only.
::
!:
=<  ^-  tool:tools
    |%
++  name  'read_file'
++  description
  '''
  Read a file attached to an itinerary. path is relative to the itinerary's
  files root, e.g. "notes.md" or "tickets/train.txt". Text files return their
  content; binary files (images, PDFs) return only their type and size.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'file path relative to the files root']]
  ==
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  rel=(unit @t)   (deg /path so:dejs:format)
  ?~  rel
    (pure:m [%error 'Missing required argument'])
  ;<  tu=(unit @ud)  bind:m  trip-up:tools
  ?~  tu  (pure:m [%error 'not running inside a trip agent'])
  =/  up=@ud  u.tu
  =/  parsed=(each path @t)  (rel-path u.rel)
  ?:  ?=(%| -.parsed)  (pure:m [%error p.parsed])
  ?~  p.parsed  (pure:m [%error 'path names the files root, not a file'])
  =/  full=path  (weld `path`/files p.parsed)
  =/  road=road:tarball  [%| up %& (snip full) (rear full)]
  ;<  =view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%file *] view)
    (pure:m [%error (crip "No such file: {(trip u.rel)}")])
  ;<  res=tool-result:tools  bind:m  (render-grub-content:tools view)
  ?.  ?=(%mime -.res)  (pure:m res)
  ::  images and PDFs ride to the model as a multimodal block (the agent
  ::  turns %mime into an image/document tool_result); anything too big
  ::  for the API is summarized instead
  ?:  (lte p.q.mime.res 4.000.000)
    ::  phones mislabel: trust the bytes over the stored type
    (pure:m [%mime (sniff-mite p.mime.res q.mime.res) q.mime.res])
  =/  ct=tape  (join-mime p.mime.res)
  %-  pure:m
  :-  %text
  (crip "{(trip u.rel)}: {ct}, {(a-co:co p.q.mime.res)} bytes — too large to view here. Open it from the Files tab.")
--
|%
::  +sniff-mite: media type from magic bytes, falling back to the stored
::  mite. Bytes are little-endian in the atom: byte 0 is the low byte.
++  sniff-mite
  |=  [fallback=mite =octs]
  ^-  mite
  =/  b  |=(i=@ud ^-(@ (cut 3 [i 1] q.octs)))
  ?:  (lth p.octs 12)  fallback
  ?:  &(=(0x89 (b 0)) =('P' (b 1)) =('N' (b 2)) =('G' (b 3)))  /image/png
  ?:  &(=(0xff (b 0)) =(0xd8 (b 1)) =(0xff (b 2)))  /image/jpeg
  ?:  &(=('G' (b 0)) =('I' (b 1)) =('F' (b 2)) =('8' (b 3)))  /image/gif
  ?:  &(=('R' (b 0)) =('I' (b 1)) =('F' (b 2)) =('F' (b 3)) =('W' (b 8)) =('E' (b 9)) =('B' (b 10)) =('P' (b 11)))
    /image/webp
  ?:  &(=('%' (b 0)) =('P' (b 1)) =('D' (b 2)) =('F' (b 3)))  /application/pdf
  fallback
::  +rel-path: a relative "a/b/c" into a path, refusing anything that
::  could climb out of the itinerary's files root.
++  rel-path
  |=  rel=@t
  ^-  (each path @t)
  ?:  =('' rel)  [%& ~]
  =/  t=tape  (trip rel)
  =/  t=tape  ?~(t t ?:(=('/' i.t) t.t t))
  =/  t=tape  ?~(t t ?:(=('/' (rear t)) (snip `tape`t) t))
  ?~  t  [%& ~]
  ::  split on '/' by hand: names are whatever the explorer stored
  ::  (spaces, parens, capitals — phone uploads), not knot-only
  =/  segs=(list @ta)
    =/  rest=tape  t
    =|  acc=(list @ta)
    =|  cur=tape
    |-  ^-  (list @ta)
    ?~  rest  (flop [(crip (flop cur)) acc])
    ?:  =('/' i.rest)  $(rest t.rest, acc [(crip (flop cur)) acc], cur ~)
    $(rest t.rest, cur [i.rest cur])
  ?:  (lien segs |=(s=@ta |(=('' s) =('..' s) =('.' s))))
    [%| 'path must not contain empty, "." or ".." segments']
  [%& segs]
++  join-mime
  |=  p=path
  ^-  tape
  ?~  p  "application/octet-stream"
  (trip (rap 3 (join '/' `(list @t)`p)))
--
