/<  tools  /lib/tools.hoon
::  list_files: list one itinerary's attachment directory (or a subdir
::  of it). Scoped by construction: the path is relative to
::  the trip's files/ (a sibling of its agent) and never escapes it.
::
!:
=<  ^-  tool:tools
    |%
++  name  'list_files'
++  description
  '''
  List the files attached to an itinerary (tickets, notes, images, PDFs the
  user uploaded or you wrote). path is optional: a subfolder relative to the
  itinerary's files root, e.g. "tickets". Folders end in "/". Each file shows
  its mime type and size.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'optional subfolder, relative to the files root']]
  ==
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  sub=(unit @t)   (deg /path so:dejs:format)
  ;<  tu=(unit @ud)  bind:m  trip-up:tools
  ?~  tu  (pure:m [%error 'not running inside a trip agent'])
  =/  up=@ud  u.tu
  =/  rel=(each path @t)  (rel-path (fall sub ''))
  ?:  ?=(%| -.rel)  (pure:m [%error p.rel])
  =/  dir=path  (weld `path`/files p.rel)
  ;<  =view:nexus  bind:m  (peek:io [%| up %| dir] ~)
  ?.  ?=([%ball *] view)
    ?~  p.rel  (pure:m [%text 'No files attached to this itinerary yet.'])
    (pure:m [%error (crip "No such folder: {(trip (fall sub ''))}")])
  =/  subs=(list @ta)  (sort ~(tap in ~(key by dir.ball.view)) aor)
  =/  files=(list [n=@ta desc=tape])
    ?~  fil.ball.view  ~
    %+  sort
      %+  turn  ~(tap by contents.u.fil.ball.view)
      |=  [n=@ta [c=sang:tarball gain=? bang=(unit tang)]]
      ^-  [@ta tape]
      :-  n
      ?:  (is-boom:tarball c)  "(broken)"
      ?.  =(%mime name.p.c)  "[{(trip name.p.c)}]"
      =/  mim=mime  !<(mime (need-vase:tarball c))
      "({(join-mime p.mim)}, {(a-co:co p.q.mim)} bytes)"
    |=([a=[n=@ta *] b=[n=@ta *]] (aor n.a n.b))
  ?:  &(?=(~ subs) ?=(~ files))
    (pure:m [%text 'Empty folder.'])
  =/  head=tape  ?~(p.rel "files/" "files{(spud p.rel)}/")
  =/  dir-text=tape
    (zing (turn subs |=(d=@ta "\0a  {(trip d)}/")))
  =/  file-text=tape
    (zing (turn files |=([n=@ta d=tape] "\0a  {(trip n)} {d}")))
  (pure:m [%text (crip "{head}{dir-text}{file-text}")])
--
|%
::  +rel-path: a relative "a/b/c" (or "") into a path, refusing anything
::  that could climb out of the itinerary's files root.
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
::  +join-mime: a mime path back into "type/subtype"
++  join-mime
  |=  p=path
  ^-  tape
  ?~  p  "application/octet-stream"
  (trip (rap 3 (join '/' `(list @t)`p)))
--
