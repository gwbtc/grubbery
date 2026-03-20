::  run-tests: discover and run unit tests from a Clay desk
::
::  Path resolution follows ted/test.hoon: if the path is a .hoon file,
::  test it directly. If it's a directory, find all .hoon files under it.
::  If neither, treat the last segment as a test arm prefix and look for
::  the parent .hoon file.
::
!:
^-  tool:tools
=>
|%
++  do-tests
  |=  [dek=desk test-files=(list path) test-filter=(unit @tas)]
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  =|  results=(list @t)
  =|  total=@ud
  =|  passed=@ud
  =|  failed=@ud
  |-
  ?~  test-files
    ?~  results
      (pure:m [%text 'No tests found'])
    =/  summary=@t
      (crip "{<total>} tests, {<passed>} passed, {<failed>} failed")
    =/  all=(list @t)
      (weld (flop results) ~[summary])
    (pure:m [%text (of-wain:format all)])
  =/  pax=path  i.test-files
  =/  file-path=path  (snip pax)
  ;<  cor=(unit vase)  bind:m  (build-clay-file:io dek pax)
  ?~  cor
    =/  fail-text=@t  (crip "FAILED  {(spud file-path)} (build)")
    %=  $
      test-files  t.test-files
      results     [fail-text results]
      total       +(total)
      failed      +(failed)
    ==
  ::  Extract test- prefixed arms
  =/  arms=(list @tas)  (sloe -:u.cor)
  =/  test-arms=(list @tas)
    (skim arms |=(a=@tas =((end [3 5] a) 'test-')))
  ::  Filter to specific arm prefix if requested
  =?  test-arms  ?=(^ test-filter)
    %+  skim  test-arms
    |=(a=@tas =((end [3 (met 3 u.test-filter)] a) u.test-filter))
  ::  Run each test arm
  =/  arm-results=[t=@ud p=@ud f=@ud r=(list @t)]
    [total passed failed results]
  =.  arm-results
    %+  roll  test-arms
    |=  [arm=@tas t=@ud p=@ud f=@ud r=(list @t)]
    =/  test-name=tape  "{(spud file-path)}/{(trip arm)}"
    =/  fire-arm=nock
      q:(~(mint ut -:u.cor) p:!>(*tang) [%limb arm])
    ::  %bout logs timing to dojo via %slog, not captured in tool output
    =/  run=(each tang tang)
      (mule |.(;;(tang ~>(%bout.[1 arm] .*(+:u.cor fire-arm)))))
    ?:  ?=(%| -.run)
      :^  +(t)  p  +(f)
      [(crip "CRASHED {test-name}") r]
    ?:  =(~ p.run)
      :^  +(t)  +(p)  f
      [(crip "OK      {test-name}") r]
    =/  err-lines=wall
      %-  zing
      (turn (flop `tang`p.run) (cury wash [0 80]))
    =/  err-text=tape
      (zing (turn err-lines |=(l=tape "{l}\0a")))
    :^  +(t)  p  +(f)
    [(crip "FAILED  {test-name}\0a{err-text}") r]
  %=  $
    test-files  t.test-files
    total    t.arm-results
    passed   p.arm-results
    failed   f.arm-results
    results  r.arm-results
  ==
--
|%
++  name  'run_tests'
++  description
  '''
  Run unit tests from a Clay desk. Discovers test files under the given
  path prefix, compiles each, extracts test- prefixed arms, and runs them.
  Returns pass/fail results for each test. You can also target a specific
  test arm by appending its name to the path (e.g. "/tests/lib/foo/test-bar").
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['desk' [%string 'Desk name (e.g. "grubbery")']]
      ['path' [%string 'Path prefix or specific test (e.g. "/tests", "/tests/lib/foo/test-bar")']]
  ==
++  required  ~['desk' 'path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  desk-json=(unit json)  (~(get by args.st) 'desk')
  =/  path-json=(unit json)  (~(get by args.st) 'path')
  ?~  desk-json  (pure:m [%error 'Missing required argument: desk'])
  ?.  ?=([%s *] u.desk-json)
    (pure:m [%error 'desk must be a string'])
  ?~  path-json  (pure:m [%error 'Missing required argument: path'])
  ?.  ?=([%s *] u.path-json)
    (pure:m [%error 'path must be a string'])
  =/  dek=desk  (slav %tas p.u.desk-json)
  =/  test-path=path  (stab p.u.path-json)
  ::  Resolve test files, following ted/test.hoon's find-test-files:
  ::  1. Is it a .hoon file? Use it directly.
  ::  2. Is it a directory? Find all .hoon files under it.
  ::  3. Otherwise, treat last segment as test arm prefix, check parent.
  ::
  =/  test-filter=(unit @tas)  ~
  ;<  is-file=?  bind:m  (check-clay-file:io dek (snoc test-path %hoon))
  ?:  is-file
    =/  test-files=(list path)  ~[(snoc test-path %hoon)]
    (do-tests dek test-files test-filter)
  ;<  fez=(list path)  bind:m  (list-clay-tree:io dek test-path)
  =/  hoon-files=(list path)
    (skim fez |=(p=path =(%hoon (rear p))))
  ?.  =(~ hoon-files)
    =/  test-files=(list path)  (sort hoon-files aor)
    (do-tests dek test-files test-filter)
  ::  No file or directory — try as test arm prefix
  =/  arm-name=@tas  (rear test-path)
  =/  parent=path  (snip test-path)
  ;<  parent-exists=?  bind:m  (check-clay-file:io dek (snoc parent %hoon))
  ?.  parent-exists
    (pure:m [%text 'No tests found'])
  =/  test-files=(list path)  ~[(snoc parent %hoon)]
  (do-tests dek test-files `arm-name)
--
