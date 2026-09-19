/<  tools  /lib/tools.hoon
::  write_file: write a text attachment into an itinerary's files root.
::  Missing folders on the way are created; an existing file keeps its
::  blot (mirrors write_grub's overwrite rule). Mime type from extension.
::
!:
=<  ^-  tool:tools
    |%
++  name  'write_file'
++  description
  '''
  Write a text file into an itinerary's attachments (notes, a packing list,
  a markdown summary, a csv...). path is relative to the itinerary's files
  root, e.g. "notes.md" or "research/hotels.md"; folders are created as
  needed. Overwrites an existing file. Binary files (images, PDFs) cannot be
  written this way — the user uploads those from the Files tab.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'file path relative to the files root']]
      ['content' [%string 'the text content']]
  ==
++  required  ~['path' 'content']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  rel=(unit @t)      (deg /path so:dejs:format)
  =/  content=(unit @t)  (deg /content so:dejs:format)
  ?:  |(?=(~ rel) ?=(~ content))
    (pure:m [%error 'Missing required argument'])
  ;<  tu=(unit @ud)  bind:m  trip-up:tools
  ?~  tu  (pure:m [%error 'not running inside a trip agent'])
  =/  up=@ud  u.tu
  =/  parsed=(each path @t)  (rel-path u.rel)
  ?:  ?=(%| -.parsed)  (pure:m [%error p.parsed])
  ?~  p.parsed  (pure:m [%error 'path names the files root, not a file'])
  =/  full=path  (weld `path`/files p.parsed)
  =/  dir=path   (snip full)
  =/  fname=@ta  (rear full)
  =/  road=road:tarball  [%| up %& dir fname]
  =/  src-mime=mime
    [(ct-to-path (guess-content-type fname)) (as-octs:mimes:html u.content)]
  ::  make sure every folder from the files root down to dir exists
  ;<  ~  bind:m  (ensure-dirs up dir)
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    ;<  cur=view:nexus  bind:m  (peek:io road ~)
    ;<  ~  bind:m
      ?:  ?&(?=([%file *] cur) !=([/ %mime] p.sang.cur))
        (over-as:io road [[/ %mime] src-mime] p.sang.cur)
      (over:io road [[/ %mime] src-mime])
    (pure:m [%text (crip "Updated {(trip u.rel)}")])
  ;<  ~  bind:m  (make:io road |+[[[/ %mime] src-mime] ~])
  (pure:m [%text (crip "Created {(trip u.rel)}")])
--
|%
::  +ensure-dirs: make every missing folder from the trip dir (up
::  steps above us) down to `dir`, e.g. /files then /files/research
++  ensure-dirs
  |=  [up=@ud dir=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  at=path  /
  |-
  ?~  dir  (pure:m ~)
  =/  here=path  (snoc at i.dir)
  ;<  v=view:nexus  bind:m  (peek:io [%| up %| here] ~)
  ;<  ~  bind:m
    ?:  ?=([%ball *] v)  (pure:m ~)
    (make:io [%| up %| here] &+[`[~ ~ %.n ~] ~])
  $(at here, dir t.dir)
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
++  ct-to-path
  |=  ct=@t
  ^-  path
  =/  t=tape  (trip ct)
  =/  idx=(unit @ud)  (find "/" t)
  ?~  idx  ~[ct]
  ~[(crip (scag u.idx t)) (crip (slag +(u.idx) t))]
++  guess-content-type
  |=  filename=@t
  ^-  @t
  =/  t=tape  (trip filename)
  =/  idx=(unit @ud)  (find "." (flop t))
  =/  ext=@t
    ?~  idx  ''
    (crip (slag (sub (lent t) u.idx) t))
  ?+  ext  'text/plain'
    %md    'text/markdown'
    %txt   'text/plain'
    %json  'application/json'
    %csv   'text/csv'
    %html  'text/html'
    %svg   'image/svg+xml'
    %xml   'application/xml'
    %ics   'text/calendar'
  ==
--
