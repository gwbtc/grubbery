/+  *test, build, tarball
|%
::  ==========================================
::  +parse-imports tests
::  ==========================================
::
++  test-parse-imports-empty
  ::  Empty source returns no imports
  =/  res  (parse-imports:build '')
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  [imports=*(list import:build) body='']
  !>  p.res
::
++  test-parse-imports-no-imports
  ::  Source with no imports returns full body
  =/  src=@t  '|=(a=@ +(a))'
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  *(list import:build)
  !>  imports.p.res
::
++  test-parse-imports-absolute
  ::  /<  foo  /lib/foo.hoon
  =/  src=@t  '/<  foo  /lib/foo.hoon\0a|=(a=@ a)'
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  ^-  (list import:build)
    :~  [%foo [%& %& /lib %'foo.hoon']]
    ==
  !>  imports.p.res
::
++  test-parse-imports-relative-dotslash
  ::  /<  bar  ./local/bar.hoon
  =/  src=@t  '/<  bar  ./local/bar.hoon\0a|=(a=@ a)'
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  ^-  (list import:build)
    :~  [%bar [%| 0 %& /local %'bar.hoon']]
    ==
  !>  imports.p.res
::
++  test-parse-imports-relative-bare
  ::  /<  bar  local/bar.hoon  (same as ./)
  =/  src=@t  '/<  bar  local/bar.hoon\0a|=(a=@ a)'
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  ^-  (list import:build)
    :~  [%bar [%| 0 %& /local %'bar.hoon']]
    ==
  !>  imports.p.res
::
++  test-parse-imports-relative-updirs
  ::  /<  baz  ../../lib/baz.hoon
  =/  src=@t  '/<  baz  ../../lib/baz.hoon\0a|=(a=@ a)'
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  ^-  (list import:build)
    :~  [%baz [%| 2 %& /lib %'baz.hoon']]
    ==
  !>  imports.p.res
::
++  test-parse-imports-multiple
  ::  Multiple imports
  =/  src=@t
    %-  crip
    ;:  weld
      "/<  foo  /lib/foo.hoon\0a"
      "/<  bar  ./bar.hoon\0a"
      "/<  baz  ../../util/baz.hoon\0a"
      "|=(a=@ a)"
    ==
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  3
  !>  (lent imports.p.res)
::
++  test-parse-imports-body-preserved
  ::  Body after imports is preserved
  =/  src=@t  '/<  foo  /lib/foo.hoon\0a|=(a=@ +(a))'
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  '|=(a=@ +(a))'
  !>  body.p.res
::
++  test-parse-imports-skip-blanks
  ::  Blank lines between imports are skipped
  =/  src=@t
    %-  crip
    ;:  weld
      "/<  foo  /lib/foo.hoon\0a"
      "\0a"
      "/<  bar  ./bar.hoon\0a"
      "|=(a=@ a)"
    ==
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  2
  !>  (lent imports.p.res)
::
++  test-parse-imports-skip-comments
  ::  Comment lines between imports are skipped
  =/  src=@t
    %-  crip
    ;:  weld
      "/<  foo  /lib/foo.hoon\0a"
      "::  this is a comment\0a"
      "/<  bar  ./bar.hoon\0a"
      "|=(a=@ a)"
    ==
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  2
  !>  (lent imports.p.res)
::
++  test-parse-imports-single-updir
  ::  /<  x  ../foo.hoon
  =/  src=@t  '/<  x  ../foo.hoon\0a~'
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  ^-  (list import:build)
    :~  [%x [%| 1 %& / %'foo.hoon']]
    ==
  !>  imports.p.res
::
++  test-parse-imports-deep-path
  ::  /<  deep  /a/b/c/d/file.hoon
  =/  src=@t  '/<  deep  /a/b/c/d/file.hoon\0a~'
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  ^-  (list import:build)
    :~  [%deep [%& %& /a/b/c/d %'file.hoon']]
    ==
  !>  imports.p.res
::
::  ==========================================
::  +import-rule unit tests
::  ==========================================
::
++  test-import-rule-absolute
  =/  res  (rust "/<  foo  /lib/foo.hoon" import-rule:build)
  %+  expect-eq
    !>  `[%foo [%& %& /lib %'foo.hoon']]
  !>  res
::
++  test-import-rule-relative
  =/  res  (rust "/<  bar  ./bar.hoon" import-rule:build)
  %+  expect-eq
    !>  `[%bar [%| 0 %& / %'bar.hoon']]
  !>  res
::
++  test-import-rule-bare-relative
  =/  res  (rust "/<  bar  bar.hoon" import-rule:build)
  %+  expect-eq
    !>  `[%bar [%| 0 %& / %'bar.hoon']]
  !>  res
::
++  test-import-rule-updirs
  =/  res  (rust "/<  baz  ../../lib/baz.hoon" import-rule:build)
  %+  expect-eq
    !>  `[%baz [%| 2 %& /lib %'baz.hoon']]
  !>  res
::
++  test-import-rule-not-import
  ::  Non-import line returns ~
  =/  res  (rust "|=(a=@ a)" import-rule:build)
  %+  expect-eq
    !>  ~
  !>  res
::
::  ==========================================
::  Path segment edge cases
::  ==========================================
::
++  test-import-rule-hyphenated-path
  ::  Hyphens in path segments
  =/  res  (rust "/<  foo  /lib/my-lib.hoon" import-rule:build)
  %+  expect-eq
    !>  `[%foo [%& %& /lib %'my-lib.hoon']]
  !>  res
::
++  test-import-rule-dotted-path
  ::  Dots in path segments (besides the extension)
  =/  res  (rust "/<  foo  /lib/foo.bar.hoon" import-rule:build)
  %+  expect-eq
    !>  `[%foo [%& %& /lib %'foo.bar.hoon']]
  !>  res
::
++  test-import-rule-hyphenated-name
  ::  Hyphenated import name
  =/  res  (rust "/<  my-lib  /lib/foo.hoon" import-rule:build)
  %+  expect-eq
    !>  `[%my-lib [%& %& /lib %'foo.hoon']]
  !>  res
::
++  test-import-rule-deep-relative
  ::  Deep relative path ./a/b/c/file.hoon
  =/  res  (rust "/<  foo  ./a/b/c/file.hoon" import-rule:build)
  %+  expect-eq
    !>  `[%foo [%| 0 %& /a/b/c %'file.hoon']]
  !>  res
::
++  test-import-rule-single-segment-absolute
  ::  Single segment absolute /foo.hoon
  =/  res  (rust "/<  foo  /foo.hoon" import-rule:build)
  %+  expect-eq
    !>  `[%foo [%& %& / %'foo.hoon']]
  !>  res
::
++  test-import-rule-extra-whitespace
  ::  Extra whitespace between tokens
  =/  res  (rust "/<  foo    /lib/foo.hoon" import-rule:build)
  %+  expect-eq
    !>  `[%foo [%& %& /lib %'foo.hoon']]
  !>  res
::
::  ==========================================
::  parse-imports edge cases
::  ==========================================
::
++  test-parse-imports-only-imports
  ::  All imports, no body
  =/  src=@t  '/<  foo  /lib/foo.hoon'
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  1
  !>  (lent imports.p.res)
::
++  test-parse-imports-only-body
  ::  Just a twig, no newline prefix
  =/  src=@t  '~'
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  ;:  weld
    %+  expect-eq
      !>  *(list import:build)
    !>  imports.p.res
  ::
    %+  expect-eq
      !>  '~'
    !>  body.p.res
  ==
::
++  test-parse-imports-preserves-order
  ::  Imports returned in source order
  =/  src=@t
    %-  crip
    ;:  weld
      "/<  alpha  /lib/alpha.hoon\0a"
      "/<  beta  /lib/beta.hoon\0a"
      "/<  gamma  /lib/gamma.hoon\0a"
      "~"
    ==
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  ^-  (list @tas)
    ~[%alpha %beta %gamma]
  !>  (turn imports.p.res |=(i=import:build name.i))
::
++  test-parse-imports-multiline-body
  ::  Body with multiple lines preserved
  =/  src=@t
    %-  crip
    ;:  weld
      "/<  foo  /lib/foo.hoon\0a"
      "|%\0a"
      "++  bar  42\0a"
      "--"
    ==
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  ;:  weld
    %+  expect-eq
      !>  1
    !>  (lent imports.p.res)
  ::
    %+  expect-eq
      !>  (crip ;:(weld "|%\0a" "++  bar  42\0a" "--"))
    !>  body.p.res
  ==
::
++  test-parse-imports-whitespace-only-lines
  ::  Lines with only spaces between imports are skipped
  =/  src=@t
    %-  crip
    ;:  weld
      "/<  foo  /lib/foo.hoon\0a"
      "    \0a"
      "/<  bar  ./bar.hoon\0a"
      "~"
    ==
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  2
  !>  (lent imports.p.res)
::
++  test-parse-imports-comment-after-imports
  ::  Comment after last import stops import parsing (becomes body)
  =/  src=@t
    %-  crip
    ;:  weld
      "/<  foo  /lib/foo.hoon\0a"
      "::  body starts here\0a"
      "|=(a=@ a)"
    ==
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  ::  Comment between import and body gets skipped, so only 1 import
  ::  and the body starts at the hoon code
  %+  expect-eq
    !>  1
  !>  (lent imports.p.res)
::
++  test-parse-imports-mixed-paths
  ::  Mix of absolute, relative, and updir imports
  =/  src=@t
    %-  crip
    ;:  weld
      "/<  abs  /lib/abs.hoon\0a"
      "/<  rel  ./rel.hoon\0a"
      "/<  bare  bare.hoon\0a"
      "/<  up  ../up.hoon\0a"
      "/<  up2  ../../dir/up2.hoon\0a"
      "~"
    ==
  =/  res  (parse-imports:build src)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  ^-  (list import:build)
    :~  [%abs [%& %& /lib %'abs.hoon']]
        [%rel [%| 0 %& / %'rel.hoon']]
        [%bare [%| 0 %& / %'bare.hoon']]
        [%up [%| 1 %& / %'up.hoon']]
        [%up2 [%| 2 %& /dir %'up2.hoon']]
    ==
  !>  imports.p.res
::
::  ==========================================
::  +strip and +is-comment unit tests
::  ==========================================
::
++  test-strip-spaces
  %+  expect-eq
    !>  "abc"
  !>  (strip:build "  a b c  ")
::
++  test-strip-empty
  %+  expect-eq
    !>  ""
  !>  (strip:build "")
::
++  test-strip-all-spaces
  %+  expect-eq
    !>  ""
  !>  (strip:build "     ")
::
++  test-is-comment-yes
  %+  expect-eq
    !>  %.y
  !>  (is-comment:build "::  hello")
::
++  test-is-comment-no
  %+  expect-eq
    !>  %.n
  !>  (is-comment:build "|=(a=@ a)")
::
++  test-is-comment-single-colon
  %+  expect-eq
    !>  %.n
  !>  (is-comment:build ":")
::
++  test-is-comment-empty
  %+  expect-eq
    !>  %.n
  !>  (is-comment:build "")
::
::  ==========================================
::  +resolve-import tests
::  ==========================================
::
++  test-resolve-import-absolute
  ::  Absolute import resolves regardless of source location
  =/  here=rail:tarball  [/app %'my.hoon']
  =/  imp=import:build  [%foo [%& %& /lib %'foo.hoon']]
  %+  expect-eq
    !>  `[%foo [/lib %'foo.hoon']]
  !>  (resolve-import:build here imp)
::
++  test-resolve-import-relative
  ::  ./bar.hoon from /app/my.hoon → /app/bar.hoon
  =/  here=rail:tarball  [/app %'my.hoon']
  =/  imp=import:build  [%bar [%| 0 %& / %'bar.hoon']]
  %+  expect-eq
    !>  `[%bar [/app %'bar.hoon']]
  !>  (resolve-import:build here imp)
::
++  test-resolve-import-updir
  ::  ../lib/util.hoon from /app/my.hoon → /lib/util.hoon
  =/  here=rail:tarball  [/app %'my.hoon']
  =/  imp=import:build  [%util [%| 1 %& /lib %'util.hoon']]
  %+  expect-eq
    !>  `[%util [/lib %'util.hoon']]
  !>  (resolve-import:build here imp)
::
++  test-resolve-import-updir-too-far
  ::  Walking up past root returns ~
  =/  here=rail:tarball  [/ %'my.hoon']
  =/  imp=import:build  [%x [%| 2 %& / %'x.hoon']]
  %+  expect-eq
    !>  ~
  !>  (resolve-import:build here imp)
::
::  ==========================================
::  +topo-sort tests
::  ==========================================
::
++  test-topo-sort-empty
  =/  deps=(map rail:tarball (set rail:tarball))  ~
  =/  res  (topo-sort:build deps)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  *(list rail:tarball)
  !>  p.res
::
++  test-topo-sort-no-deps
  ::  Three files with no deps — all appear (any order)
  =/  deps=(map rail:tarball (set rail:tarball))
    %-  ~(gas by *(map rail:tarball (set rail:tarball)))
    :~  [[/ %'a.hoon'] ~]
        [[/ %'b.hoon'] ~]
        [[/ %'c.hoon'] ~]
    ==
  =/  res  (topo-sort:build deps)
  ?>  ?=(%& -.res)
  %+  expect-eq
    !>  3
  !>  (lent p.res)
::
++  test-topo-sort-linear
  ::  a → b → c: c first, then b, then a
  =/  deps=(map rail:tarball (set rail:tarball))
    %-  ~(gas by *(map rail:tarball (set rail:tarball)))
    :~  [[/ %'a.hoon'] (~(gas in *(set rail:tarball)) ~[[/ %'b.hoon']])]
        [[/ %'b.hoon'] (~(gas in *(set rail:tarball)) ~[[/ %'c.hoon']])]
        [[/ %'c.hoon'] ~]
    ==
  =/  res  (topo-sort:build deps)
  ?>  ?=(%& -.res)
  ::  c must come before b, b before a
  =/  order=(list rail:tarball)  p.res
  =/  idx-c=@ud  (need (find ~[[/ %'c.hoon']] order))
  =/  idx-b=@ud  (need (find ~[[/ %'b.hoon']] order))
  =/  idx-a=@ud  (need (find ~[[/ %'a.hoon']] order))
  ;:  weld
    (expect !>(=(%.y (lth idx-c idx-b))))
    (expect !>(=(%.y (lth idx-b idx-a))))
  ==
::
++  test-topo-sort-cycle
  ::  a → b → a: cycle detected
  =/  deps=(map rail:tarball (set rail:tarball))
    %-  ~(gas by *(map rail:tarball (set rail:tarball)))
    :~  [[/ %'a.hoon'] (~(gas in *(set rail:tarball)) ~[[/ %'b.hoon']])]
        [[/ %'b.hoon'] (~(gas in *(set rail:tarball)) ~[[/ %'a.hoon']])]
    ==
  =/  res  (topo-sort:build deps)
  (expect !>(=(%.y ?=(%| -.res))))
::
++  test-topo-sort-diamond
  ::  a→b, a→c, b→d, c→d: d first, b and c middle, a last
  =/  deps=(map rail:tarball (set rail:tarball))
    %-  ~(gas by *(map rail:tarball (set rail:tarball)))
    :~  [[/ %'a.hoon'] (~(gas in *(set rail:tarball)) ~[[/ %'b.hoon'] [/ %'c.hoon']])]
        [[/ %'b.hoon'] (~(gas in *(set rail:tarball)) ~[[/ %'d.hoon']])]
        [[/ %'c.hoon'] (~(gas in *(set rail:tarball)) ~[[/ %'d.hoon']])]
        [[/ %'d.hoon'] ~]
    ==
  =/  res  (topo-sort:build deps)
  ?>  ?=(%& -.res)
  =/  order=(list rail:tarball)  p.res
  =/  idx-d=@ud  (need (find ~[[/ %'d.hoon']] order))
  =/  idx-b=@ud  (need (find ~[[/ %'b.hoon']] order))
  =/  idx-c=@ud  (need (find ~[[/ %'c.hoon']] order))
  =/  idx-a=@ud  (need (find ~[[/ %'a.hoon']] order))
  ;:  weld
    (expect !>(=(%.y (lth idx-d idx-b))))
    (expect !>(=(%.y (lth idx-d idx-c))))
    (expect !>(=(%.y (lth idx-b idx-a))))
    (expect !>(=(%.y (lth idx-c idx-a))))
    %+  expect-eq
      !>  4
    !>  (lent order)
  ==
::
::  ==========================================
::  +find-hoon-sources tests
::  ==========================================
::
++  test-find-hoon-sources-basic
  ::  Finds %hoon files, ignores others
  =/  =ball:tarball
    =/  b=ball:tarball  *ball:tarball
    =.  b  (~(put ba:tarball b) [/ %'foo.hoon'] [~ [%hoon !>('|=(a=@ a)')]])
    =.  b  (~(put ba:tarball b) [/ %'data.json'] [~ [%json !>(*json)]])
    b
  =/  sources  (find-hoon-sources:build ball)
  ;:  weld
    %+  expect-eq
      !>  1
    !>  ~(wyt by sources)
  ::
    (expect !>(=(%.y (~(has by sources) [/ %'foo.hoon']))))
  ::
    (expect !>(=(%.y !(~(has by sources) [/ %'data.json']))))
  ==
::
++  test-find-hoon-sources-empty
  ::  Empty ball produces empty source map
  =/  sources  (find-hoon-sources:build *ball:tarball)
  %+  expect-eq
    !>  0
  !>  ~(wyt by sources)
::
++  test-find-hoon-sources-nested
  ::  Finds hoon files in subdirectories
  =/  =ball:tarball  *ball:tarball
  =.  ball  (~(put ba:tarball ball) [/lib %'foo.hoon'] [~ [%hoon !>('1')]])
  =.  ball  (~(put ba:tarball ball) [/lib/deep %'bar.hoon'] [~ [%hoon !>('2')]])
  =.  ball  (~(put ba:tarball ball) [/ %'top.hoon'] [~ [%hoon !>('3')]])
  =/  sources  (find-hoon-sources:build ball)
  %+  expect-eq
    !>  3
  !>  ~(wyt by sources)
::
::  ==========================================
::  +build-all tests
::  ==========================================
::
++  test-build-all-single-file
  ::  Single hoon file with no imports compiles
  =/  =ball:tarball
    (~(put ba:tarball *ball:tarball) [/ %'foo.hoon'] [~ [%hoon !>('|=(a=@ +(a))')]])
  =/  res  (build-all:build !>(~) ball *build-cache:build)
  =/  foo-res  (~(get by results.res) [/ %'foo.hoon'])
  (expect !>(=(%.y ?=([~ %& *] foo-res))))
::
++  test-build-all-syntax-error
  ::  Bad syntax produces a tang error
  =/  =ball:tarball
    (~(put ba:tarball *ball:tarball) [/ %'bad.hoon'] [~ [%hoon !>('|=(')]])
  =/  res  (build-all:build !>(~) ball *build-cache:build)
  =/  bad-res  (~(get by results.res) [/ %'bad.hoon'])
  (expect !>(=(%.y ?=([~ %| *] bad-res))))
::
++  test-build-all-with-dep
  ::  File B imports file A; B can use A's gate
  =/  =ball:tarball  *ball:tarball
  =.  ball
    (~(put ba:tarball ball) [/lib %'add1.hoon'] [~ [%hoon !>('|=(a=@ +(a))')]])
  =.  ball
    (~(put ba:tarball ball) [/ %'main.hoon'] [~ [%hoon !>('/<  add1  /lib/add1.hoon\0a(add1 5)')]])
  =/  res  (build-all:build !>(~) ball *build-cache:build)
  =/  main-res  (~(get by results.res) [/ %'main.hoon'])
  (expect !>(=(%.y ?=([~ %& *] main-res))))
::
++  test-build-all-missing-dep
  ::  Import pointing to nonexistent file → error
  =/  =ball:tarball
    (~(put ba:tarball *ball:tarball) [/ %'main.hoon'] [~ [%hoon !>('/<  missing  /lib/nope.hoon\0a~')]])
  =/  res  (build-all:build !>(~) ball *build-cache:build)
  =/  main-res  (~(get by results.res) [/ %'main.hoon'])
  (expect !>(=(%.y ?=([~ %| *] main-res))))
::
++  test-build-all-cache-hit
  ::  Second build with same content uses cache
  =/  =ball:tarball
    (~(put ba:tarball *ball:tarball) [/ %'foo.hoon'] [~ [%hoon !>('|=(a=@ +(a))')]])
  =/  res1  (build-all:build !>(~) ball *build-cache:build)
  =/  res2  (build-all:build !>(~) ball cache.res1)
  =/  foo1  (~(got by results.res1) [/ %'foo.hoon'])
  =/  foo2  (~(got by results.res2) [/ %'foo.hoon'])
  ::  Both succeed and produce same noun
  ;:  weld
    (expect !>(=(%.y ?=(%& -.foo1))))
    (expect !>(=(%.y ?=(%& -.foo2))))
    ?>  ?=(%& -.foo1)
    ?>  ?=(%& -.foo2)
    (expect !>(=(%.y =(q.p.foo1 q.p.foo2))))
  ==
::
++  test-build-all-cache-miss
  ::  Changing source content causes cache miss (different result)
  =/  ball1=ball:tarball
    (~(put ba:tarball *ball:tarball) [/ %'foo.hoon'] [~ [%hoon !>('|=(a=@ +(a))')]])
  =/  res1  (build-all:build !>(~) ball1 *build-cache:build)
  =/  ball2=ball:tarball
    (~(put ba:tarball *ball:tarball) [/ %'foo.hoon'] [~ [%hoon !>('|=(a=@ +(+(a)))')]])
  =/  res2  (build-all:build !>(~) ball2 cache.res1)
  =/  foo1  (~(got by results.res1) [/ %'foo.hoon'])
  =/  foo2  (~(got by results.res2) [/ %'foo.hoon'])
  ?>  ?=(%& -.foo1)
  ?>  ?=(%& -.foo2)
  ::  Both compile but produce different nouns
  (expect !>(=(%.y !=(q.p.foo1 q.p.foo2))))
::
++  test-build-all-circular-dep
  ::  Two files importing each other → circular dependency errors
  =/  =ball:tarball  *ball:tarball
  =.  ball
    (~(put ba:tarball ball) [/ %'a.hoon'] [~ [%hoon !>('/<  b  ./b.hoon\0a~')]])
  =.  ball
    (~(put ba:tarball ball) [/ %'b.hoon'] [~ [%hoon !>('/<  a  ./a.hoon\0a~')]])
  =/  res  (build-all:build !>(~) ball *build-cache:build)
  =/  a-res  (~(get by results.res) [/ %'a.hoon'])
  =/  b-res  (~(get by results.res) [/ %'b.hoon'])
  ;:  weld
    (expect !>(=(%.y ?=([~ %| *] a-res))))
    (expect !>(=(%.y ?=([~ %| *] b-res))))
  ==
::
++  test-build-all-dep-failure
  ::  If a dep fails, dependents get dep-failed error
  =/  =ball:tarball  *ball:tarball
  =.  ball
    (~(put ba:tarball ball) [/lib %'bad.hoon'] [~ [%hoon !>('|=(')]])
  =.  ball
    (~(put ba:tarball ball) [/ %'main.hoon'] [~ [%hoon !>('/<  bad  /lib/bad.hoon\0a(bad 1)')]])
  =/  res  (build-all:build !>(~) ball *build-cache:build)
  =/  bad-res  (~(get by results.res) [/lib %'bad.hoon'])
  =/  main-res  (~(get by results.res) [/ %'main.hoon'])
  ;:  weld
    (expect !>(=(%.y ?=([~ %| *] bad-res))))
    (expect !>(=(%.y ?=([~ %| *] main-res))))
  ==
::
++  test-build-all-multi-level-deps
  ::  a→b→c: three-level chain compiles correctly
  =/  =ball:tarball  *ball:tarball
  =.  ball
    (~(put ba:tarball ball) [/lib %'c.hoon'] [~ [%hoon !>('|=(a=@ +(a))')]])
  =.  ball
    (~(put ba:tarball ball) [/lib %'b.hoon'] [~ [%hoon !>('/<  c  /lib/c.hoon\0a|=(a=@ (c a))')]])
  =.  ball
    (~(put ba:tarball ball) [/ %'a.hoon'] [~ [%hoon !>('/<  b  /lib/b.hoon\0a(b 5)')]])
  =/  res  (build-all:build !>(~) ball *build-cache:build)
  =/  a-res  (~(get by results.res) [/ %'a.hoon'])
  =/  b-res  (~(get by results.res) [/lib %'b.hoon'])
  =/  c-res  (~(get by results.res) [/lib %'c.hoon'])
  ;:  weld
    (expect !>(=(%.y ?=([~ %& *] a-res))))
    (expect !>(=(%.y ?=([~ %& *] b-res))))
    (expect !>(=(%.y ?=([~ %& *] c-res))))
  ==
::
++  test-build-all-diamond-dep
  ::  a→b, a→c, b→d, c→d: diamond compiles, d built once
  =/  =ball:tarball  *ball:tarball
  =.  ball
    (~(put ba:tarball ball) [/lib %'d.hoon'] [~ [%hoon !>('|=(a=@ +(a))')]])
  =.  ball
    (~(put ba:tarball ball) [/lib %'b.hoon'] [~ [%hoon !>('/<  d  /lib/d.hoon\0a|=(a=@ (d a))')]])
  =.  ball
    (~(put ba:tarball ball) [/lib %'c.hoon'] [~ [%hoon !>('/<  d  /lib/d.hoon\0a|=(a=@ (d (d a)))')]])
  =.  ball
    (~(put ba:tarball ball) [/ %'a.hoon'] [~ [%hoon !>('/<  b  /lib/b.hoon\0a/<  c  /lib/c.hoon\0a[(b 1) (c 1)]')]])
  =/  res  (build-all:build !>(~) ball *build-cache:build)
  =/  a-res  (~(get by results.res) [/ %'a.hoon'])
  ;:  weld
    (expect !>(=(%.y ?=([~ %& *] a-res))))
    (expect !>(=(%.y ?=([~ %& *] (~(get by results.res) [/lib %'d.hoon'])))))
    (expect !>(=(%.y ?=([~ %& *] (~(get by results.res) [/lib %'b.hoon'])))))
    (expect !>(=(%.y ?=([~ %& *] (~(get by results.res) [/lib %'c.hoon'])))))
  ==
--
