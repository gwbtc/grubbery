::  grep: search file contents in the grubbery ball
::
!:
^-  tool:tools
|%
++  name  'grep'
++  description
  ^~  %-  crip
  ;:  weld
    "Search file contents in the grubbery ball for a string. "
    "Returns matching lines with file paths and line numbers. "
    "Optionally filter which files to search by path, name, or mark pattern."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['pattern' [%string 'Text string to search for']]
      ['path' [%string 'Directory path pattern to filter files (e.g. "/config/*")']]
      ['name' [%string 'Filename pattern to filter (e.g. "*config*")']]
      ['mark' [%string 'Mark/extension pattern to filter (e.g. "hoon", "txt")']]
  ==
++  required  ~['pattern']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  search=@t  (~(dog jo:json-utils [%o args.st]) /pattern so:dejs:format)
  =/  pat-path=(unit @t)
    ?~  p=(~(get jo:json-utils [%o args.st]) /path)  ~
    ?.  ?=([%s *] u.p)  ~
    ?:  =('' p.u.p)  ~
    `p.u.p
  =/  pat-name=(unit @t)
    ?~  n=(~(get jo:json-utils [%o args.st]) /name)  ~
    ?.  ?=([%s *] u.n)  ~
    ?:  =('' p.u.n)  ~
    `p.u.n
  =/  pat-mark=(unit @t)
    ?~  mk=(~(get jo:json-utils [%o args.st]) /mark)  ~
    ?.  ?=([%s *] u.mk)  ~
    ?:  =('' p.u.mk)  ~
    `p.u.mk
  =/  search-tape=tape  (trip search)
  ::  Browse root to get entire ball
  ;<  =seen:nexus  bind:m  (peek:io /browse [%& %| ~] ~)
  ?.  ?=([%& %ball *] seen)
    (pure:m [%error 'Could not read ball'])
  ::  Flatten and filter by metadata patterns
  =/  candidates=(list [rail:tarball content:tarball])
    %+  skim  ~(tap ba:tarball ball.p.seen)
    |=  [=rail:tarball =content:tarball]
    =/  file-path=tape  ?~(path.rail "/" (trip (spat path.rail)))
    =/  file-name=tape  (trip name.rail)
    =/  file-mark=tape  (trip p.cage.content)
    ?&  ?~(pat-path %.y (glob-match:tools (trip u.pat-path) file-path))
        ?~(pat-name %.y (glob-match:tools (trip u.pat-name) file-name))
        ?~(pat-mark %.y (glob-match:tools (trip u.pat-mark) file-mark))
    ==
  ::  Search each candidate file for the pattern
  =|  results=(list tape)
  =/  total-matches=@ud  0
  |-
  ?~  candidates
    ?~  results
      (pure:m [%text 'No matches found'])
    =/  out=tape  (zing (flop results))
    (pure:m [%text (crip "Found {<total-matches>} matches:{out}")])
  =/  [=rail:tarball =content:tarball]  i.candidates
  =/  file-label=tape
    =/  pax=tape  ?~(path.rail "/" (trip (spat path.rail)))
    "{pax}/{(trip name.rail)}.{(trip p.cage.content)}"
  ::  Try to read file content as text
  ;<  file-seen=seen:nexus  bind:m
    (peek:io /read [%& %& path.rail name.rail] ~)
  ?.  ?=([%& %file *] file-seen)
    $(candidates t.candidates)
  ;<  =mime  bind:m  (cage-to-mime:io cage.p.file-seen)
  =/  text=tape  (trip ;;(@t q.q.mime))
  ::  Split into lines and search
  =/  lines=(list tape)
    %+  roll  (flop text)
    |=  [c=@t acc=(list tape)]
    ?~  acc
      ?:  =(c 10)  ["" ~]
      [(trip c) ~]
    ?:  =(c 10)  ["" acc]
    [[(weld (trip c) i.acc) t.acc]]
  =/  line-num=@ud  1
  =/  file-matches=(list tape)  ~
  |-
  ?~  lines
    =/  new-results=(list tape)
      ?~  file-matches  results
      (weld (flop file-matches) results)
    ^$(candidates t.candidates, results new-results, total-matches (add total-matches (lent file-matches)))
  =/  hit=?  !=(~ (find search-tape i.lines))
  =?  file-matches  hit
    :_  file-matches
    "\0a{file-label}:{<line-num>}: {i.lines}"
  $(lines t.lines, line-num +(line-num))
--
