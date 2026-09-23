/<  tools  /lib/tools.hoon
::  read_doc: a library document by name, in ranges. Documents are whole
::  books and long notes; nothing is chunked on disk. Without a range the
::  tool returns the first 200 lines plus the total, so a careless call
::  never floods the context. `find` greps the document and reports
::  matching line numbers, so the agent locates a passage first, then
::  reads around it. Lines are 1-based inclusive; bytes are 0-based.
::
!:
=<  ^-  tool:tools
    |%
++  name  'read_doc'
++  description
  '''
  Read a library document by name (from list_library). Optional ranges:
  from/to = 1-based line numbers, inclusive; or offset/length = a byte
  range. With no range: the first 200 lines and the total line count.
  find = a search string: returns every matching line with its number
  (no text otherwise) — use it to locate a passage, then read a line
  range around it. Every reply starts with a header naming the document
  and the range returned.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['name' [%string 'the document name, e.g. montaigne-essays.txt']]
      ['from' [%number 'first line to return, 1-based. Pairs with to.']]
      ['to' [%number 'last line to return, inclusive; at most 400 lines per call. Pairs with from.']]
      ['offset' [%number 'byte offset to start at, 0-based — an alternative to from/to. Pairs with length.']]
      ['length' [%number 'bytes to return from offset; at most 40000. Pairs with offset.']]
      ['find' [%string 'search string (case-insensitive): returns matching line numbers + lines, up to 60 hits']]
  ==
++  required  ~['name']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  nm=@t  (fall (deg /name so:dejs:format) '')
  ?:  =('' nm)  (pure:m [%error 'name is required'])
  =/  from=(unit @ud)    (jnum args.st 'from')
  =/  to=(unit @ud)      (jnum args.st 'to')
  =/  offset=(unit @ud)  (jnum args.st 'offset')
  =/  length=(unit @ud)  (jnum args.st 'length')
  =/  query=(unit @t)    (deg /find so:dejs:format)
  ;<  fv=view:nexus  bind:m
    (peek:io [%& %& /apps/ghostprompter/library `@ta`nm] `[/ %mime])
  ?.  ?=([%file *] fv)
    (pure:m [%error (cat 3 'no such document: ' nm)])
  =/  =mime  !<(mime (need-vase:tarball sang.fv))
  =/  txt=@t  `@t`q.q.mime
  =/  size=@ud  p.q.mime
  ::  byte range: exact slice, no line math
  ?^  offset
    =/  len=@ud  (min (fall length 40.000) 40.000)
    =/  off=@ud  (min u.offset size)
    =/  end=@ud  (min (add off len) size)
    =/  bytes=@t  (cut 3 [off (sub end off)] txt)
    %-  pure:m
    :-  %text
    (crip "[{(trip nm)} — bytes {(a-co:co off)}–{(a-co:co end)} of {(a-co:co size)}]\0a{(trip bytes)}")
  =/  lines=(list @t)  (to-wain:format txt)
  =/  total=@ud  (lent lines)
  ::  search: matching line numbers, no range
  ?^  query
    =/  needle=tape  (cass (trip u.query))
    =/  hits=(list [n=@ud l=@t])
      =|  acc=(list [n=@ud l=@t])
      =/  i=@ud  1
      |-
      ?~  lines  (flop acc)
      ?:  (gte (lent acc) 60)  (flop acc)
      ?~  (find needle (cass (trip i.lines)))
        $(lines t.lines, i +(i))
      $(lines t.lines, i +(i), acc [[i i.lines] acc])
    ?~  hits
      (pure:m [%text (crip "[{(trip nm)} — no lines match \"{(trip u.query)}\" ({(a-co:co total)} lines)]")])
    =/  head=tape
      "[{(trip nm)} — {(a-co:co (lent hits))} matching lines of {(a-co:co total)}; read a from/to range around one]\0a"
    =/  rows=tape
      %-  zing
      ^-  (list tape)
      %+  turn  hits
      |=  [n=@ud l=@t]
      ^-  tape
      "{(a-co:co n)}: {(trip l)}\0a"
    (pure:m [%text (crip (weld head rows))])
  ::  line range (default: the head of the document)
  =/  lo=@ud  (max 1 (fall from 1))
  =/  hi=@ud  (min total (fall to (add lo 199)))
  =/  hi=@ud  (min hi (add lo 399))
  ?:  (gth lo total)
    (pure:m [%error (crip "from {(a-co:co lo)} is past the end ({(a-co:co total)} lines)")])
  =/  body=tape
    %-  zing
    ^-  (list tape)
    %+  turn  (scag (sub +(hi) lo) (slag (dec lo) lines))
    |=(l=@t ^-(tape (weld (trip l) "\0a")))
  =/  more=tape
    ?:  (gte hi total)  ""
    " — continue with from={(a-co:co +(hi))}"
  %-  pure:m
  :-  %text
  (crip "[{(trip nm)} — lines {(a-co:co lo)}–{(a-co:co hi)} of {(a-co:co total)}{more}]\0a{body}")
--
|%
::  +num: a string argument as a number (the schema is all-string)
::  read a number the caller may send as a JSON number (%n) or, being a
::  fuzzy LLM client, as a string (%s); either way parse to (unit @ud).
++  jnum
  |=  [args=(map @t json) k=@t]
  ^-  (unit @ud)
  =/  v  (~(get by args) k)
  ?~  v  ~
  ?+  u.v  ~
    [%n *]  (rush p.u.v dem)
    [%s *]  (rush p.u.v dem)
  ==
--
