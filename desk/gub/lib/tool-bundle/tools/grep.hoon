/<  tools  /lib/tools.hoon
::  grep: search text file contents in the grubbery ball.
::
::  Walks the tree one directory at a time (shallow peeks), never
::  materialising the whole ball: a deep peek of the root pulls every
::  git pack and binary into one event, which is how this tool once
::  exhausted the loom. Only text is read (text blots, text mimes);
::  binaries, jams and nouns with no text form are skipped unread.
::  Every call is bounded: a byte budget on text scanned and a cap on
::  matches. When either runs out the result says so and names where
::  the walk stopped, so the caller narrows with `path` and goes again.
::
!:
=>  |%
    ::  the budgets: text bytes scanned, matches returned, directories
    ::  visited per call (a filter that matches nothing still walks)
    ++  byte-budget   16.777.216
    ++  match-budget  200
    ++  dir-budget    2.000
    ::  +walk-root: the directory to start from. A path pattern with a
    ::  literal prefix ("/code/lib/*") need not walk the rest of the tree.
    ++  walk-root
      |=  pat=(unit @t)
      ^-  path
      ?~  pat  /
      =/  t=tape  (trip u.pat)
      =/  lit=tape
        =/  star=(unit @ud)  (find "*" t)
        ?~  star  t
        (scag u.star t)
      ::  back up to the last / so a partial segment ("/co") is not a dir
      =/  cut=(unit @ud)
        =/  r=tape  (flop lit)
        =/  i=(unit @ud)  (find "/" r)
        ?~  i  ~
        `(sub (lent lit) u.i)
      ?~  cut  /
      ::  the prefix ends in its /; stap wants it gone
      =/  dir=tape  (scag u.cut lit)
      =?  dir  (gth (lent dir) 1)  (snip dir)
      (fall (rush (crip dir) stap) /)
    ::  +text-of: a file's text if it has one, else ~ without reading it.
    ::  Text blots convert through their mime; a raw mime is text by its
    ::  media type; anything else (jams, nouns, images, packs) is skipped.
    ++  text-of
      |=  =sang:tarball
      =/  m  (fiber:fiber:nexus ,(unit @t))
      ^-  form:m
      =/  =sage:tarball  (need-sage:tarball sang)
      ?:  =(%mime name.p.sage)
        =/  =mime  !<(mime q.sage)
        ::  a mite stored as one 'text/plain' segment reads as /text/plain
        =/  =mite
          ?.  ?=([@ ~] p.mime)  p.mime
          =/  t=tape  (trip i.p.mime)
          ?~  sl=(find "/" t)  p.mime
          ~[(crip (scag u.sl t)) (crip (slag +(u.sl) t))]
        ?.  (is-text-mime:tools mite)  (pure:m ~)
        (pure:m `q.q.mime)
      ?.  (is-text-blot:tools name.p.sage)  (pure:m ~)
      ;<  =mime  bind:m  (sage-to-mime:io sage)
      (pure:m `q.q.mime)
    ::  +report: the result text. A stop names where the walk ended and why.
    ++  report
      |=  $:  results=(list tape)
              matches=@ud
              scanned=@ud
              files=@ud
              stop=(unit [dir=path file=@ta why=@t])
          ==
      ^-  tool-result:tools
      =/  tail=tape
        ?~  stop  ""
        =/  at=tape
          %+  weld  ?~(dir.u.stop "/" (trip (spat dir.u.stop)))
          ?:(=('' file.u.stop) "" "/{(trip file.u.stop)}")
        %+  weld  "\0a\0aStopped ({(trip why.u.stop)}) at {at} after {(a-co:co files)} files, "
        "{(a-co:co (div scanned 1.024))} KB scanned. Narrow with path and search again."
      ?~  results
        [%text (crip "No matches found ({(a-co:co files)} text files, {(a-co:co (div scanned 1.024))} KB scanned){tail}")]
      [%text (crip "Found {(a-co:co matches)} matches:{(zing (flop results))}{tail}")]
    --
^-  tool:tools
|%
++  name  'grep'
++  description
  ^~  %-  crip
  ;:  weld
    "Search text file contents in the grubbery ball for a string. "
    "Returns matching lines with file paths and line numbers. "
    "Optionally filter which files to search by path, name, or blot pattern "
    "(path with a literal prefix, e.g. \"/code/*\", starts the walk there). "
    "Binary files are skipped. Each call scans at most "
    "16 MB of text and returns at most 200 matches; past either limit the "
    "result says where it stopped, so narrow with path and search again."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['pattern' [%string 'Text string to search for']]
      ['path' [%string 'Directory path pattern to filter files (e.g. "/config/*")']]
      ['name' [%string 'Filename pattern to filter (e.g. "*config*")']]
      ['blot' [%string 'Blot pattern to filter (e.g. "hoon", "txt")']]
  ==
++  required  ~['pattern']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each @t tang)
    (mule |.((~(dog jo:json-utils [%o args.st]) /pattern so:dejs:format)))
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid argument: pattern'])
  =/  search=@t  p.parsed
  ?:  =('' search)
    (pure:m [%error 'pattern cannot be empty'])
  =/  opt
    |=  k=@t
    ^-  (unit @t)
    ?~  v=(~(get jo:json-utils [%o args.st]) [k ~])  ~
    ?.  ?=([%s *] u.v)  ~
    ?:  =('' p.u.v)  ~
    `p.u.v
  =/  pat-path=(unit @t)  (opt 'path')
  =/  pat-name=(unit @t)  (opt 'name')
  =/  pat-mark=(unit @t)  (opt 'blot')
  =/  search-tape=tape  (trip search)
  ::  where to start: the literal directory prefix of the path pattern
  ::  (everything before its first *), else the root
  =/  start=path  (walk-root pat-path)
  =/  dir-label
    |=  p=path
    ^-  tape
    ?~(p "/" (trip (spat p)))
  ::  the walk: a stack of directories still to visit, depth first
  =/  todo=(list path)  ~[start]
  =|  results=(list tape)
  =|  matches=@ud
  =|  scanned=@ud
  =|  files=@ud
  =|  dirs=@ud
  |-  ^-  form:m
  ::  pop through a unit so `todo` keeps its list type for the recursion
  =/  pop=(unit [path (list path)])  ?~(todo ~ `[i.todo t.todo])
  ?~  pop
    (pure:m (report results matches scanned files ~))
  =/  here=path  -.u.pop
  =.  todo  +.u.pop
  ?:  (gte dirs dir-budget)
    (pure:m (report results matches scanned files `[here '' 'directory budget']))
  =.  dirs  +(dirs)
  ;<  dv=view:nexus  bind:m  (peek-shallow:io [%& %| here] ~)
  ?.  ?=([%ball *] dv)  $
  ::  subdirectories go on the stack (sorted, so the walk is stable)
  =.  todo
    %+  weld
      %+  turn  (sort ~(tap in ~(key by dir.ball.dv)) aor)
      |=(n=@ta (snoc here n))
    todo
  ?~  fil.ball.dv  $
  =/  here-label=tape  (dir-label here)
  ::  the candidate files at this level, by the metadata filters
  =/  cands=(list [name=@ta =sang:tarball])
    %+  murn  (sort ~(tap by contents.u.fil.ball.dv) |=([[a=@ta *] [b=@ta *]] (aor a b)))
    |=  [n=@ta =sang:tarball *]
    ^-  (unit [@ta sang:tarball])
    ?:  (is-boom:tarball sang)  ~
    =/  blot-name=tape  (trip name.p.sang)
    ?.  ?&  ?~(pat-path %.y (glob-match:tools (trip u.pat-path) here-label))
            ?~(pat-name %.y (glob-match:tools (trip u.pat-name) (trip n)))
            ?~(pat-mark %.y (glob-match:tools (trip u.pat-mark) blot-name))
        ==
      ~
    `[n sang]
  ::  scan each candidate; stop at a budget
  |-  ^-  form:m
  ?~  cands  ^$
  =/  [n=@ta =sang:tarball]  i.cands
  ;<  text=(unit @t)  bind:m  (text-of sang)
  ?~  text  $(cands t.cands)
  =/  size=@ud  (met 3 u.text)
  ?:  (gth (add scanned size) byte-budget)
    (pure:m (report results matches scanned files `[here n 'byte budget']))
  =.  scanned  (add scanned size)
  =.  files  +(files)
  =/  label=tape  "{here-label}{?:(=(/ here) "" "/")}{(trip n)}"
  =/  lines=(list @t)  (to-wain:format u.text)
  =/  min=@ud  (lent search-tape)
  =|  ln=@ud
  |-  ^-  form:m
  ?~  lines  ^$(cands t.cands)
  =.  ln  +(ln)
  ?:  (lth (met 3 i.lines) min)  $(lines t.lines)
  ?~  (find search-tape (trip i.lines))  $(lines t.lines)
  ?:  (gte matches match-budget)
    (pure:m (report results matches scanned files `[here n 'match budget']))
  %=  $
    lines    t.lines
    matches  +(matches)
    results  ["\0a{label}:{(a-co:co ln)}: {(trip i.lines)}" results]
  ==
--
