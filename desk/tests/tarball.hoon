/+  *test, tarball
|%
++  test-empty-ball
  %+  expect-eq
    !>  [fil=~ dir=~]
  !>  *ball:tarball
::
++  test-put-and-get
  =/  my-ball  *ball:tarball
  =/  test-content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  updated  (~(put ba:tarball my-ball) [/foo %test] test-content)
  =/  result  (~(get ba:tarball updated) /foo %test)
  %+  expect-eq
    !>  `test-content
  !>  result
::
++  test-get-nonexistent
  =/  my-ball  *ball:tarball
  =/  result  (~(get ba:tarball my-ball) /foo %nonexistent)
  %+  expect-eq
    !>  ~
  !>  result
::
++  test-has-exists
  =/  my-ball  *ball:tarball
  =/  test-content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  updated  (~(put ba:tarball my-ball) [/foo %test] test-content)
  %-  expect
  !>  (~(has ba:tarball updated) /foo %test)
::
++  test-has-not-exists
  =/  my-ball  *ball:tarball
  =/  result  (~(has ba:tarball my-ball) /foo %test)
  %+  expect-eq
    !>  %.n
  !>  result
::
++  test-del
  =/  my-ball  *ball:tarball
  =/  test-content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %test] test-content)
  =/  g2  (~(del ba:tarball g1) /foo %test)
  =/  result  (~(get ba:tarball g2) /foo %test)
  %+  expect-eq
    !>  ~
  !>  result
::
++  test-lis
  =/  my-ball  *ball:tarball
  =/  test1=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  test2=content:tarball  [~ [%mime !>([/text/html [3 'bye']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %test] test1)
  =/  g2  (~(put ba:tarball g1) [/foo %other] test2)
  =/  files  (~(lis ba:tarball g2) /foo)
  ::  Check that both files are in the list
  ;:  weld
    %-  expect
    !>  (~(has in (~(gas in *(set @ta)) files)) %test)
    %-  expect
    !>  (~(has in (~(gas in *(set @ta)) files)) %other)
  ==
::
++  test-multiple-paths
  =/  my-ball  *ball:tarball
  =/  content1=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  content2=content:tarball  [~ [%mime !>([/text/html [3 'bye']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %test] content1)
  =/  g2  (~(put ba:tarball g1) [/bar %other] content2)
  ;:  weld
    %+  expect-eq
      !>  `content1
    !>  (~(get ba:tarball g2) /foo %test)
    %+  expect-eq
      !>  `content2
    !>  (~(get ba:tarball g2) /bar %other)
  ==
::
++  test-got
  =/  my-ball  *ball:tarball
  =/  test-content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  updated  (~(put ba:tarball my-ball) [/foo %test] test-content)
  %+  expect-eq
    !>  test-content
  !>  (~(got ba:tarball updated) /foo %test)
::
++  test-got-crash
  =/  my-ball  *ball:tarball
  %-  expect-fail
  |.((~(got ba:tarball my-ball) /foo %nonexistent))
::
++  test-gut
  =/  my-ball  *ball:tarball
  =/  default=content:tarball  [~ [%mime !>([/text/plain [7 'default']])]]
  =/  result  (~(gut ba:tarball my-ball) [/foo %test] default)
  %+  expect-eq
    !>  default
  !>  result
::
++  test-wyt
  =/  my-ball  *ball:tarball
  =/  content1=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  content2=content:tarball  [~ [%mime !>([/text/html [3 'bye']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %test] content1)
  =/  g2  (~(put ba:tarball g1) [/bar %other] content2)
  %+  expect-eq
    !>  2
  !>  ~(wyt ba:tarball g2)
::
++  test-gas
  =/  my-ball  *ball:tarball
  =/  files=(list [rail:tarball content:tarball])
    :~  [[/foo %test] [~ [%mime !>([/text/plain [5 'hello']])]]]
        [[/foo %other] [~ [%mime !>([/text/html [3 'bye']])]]]
        [[/bar %thing] [~ [%mime !>([/text/css [4 'hmm']])]]]
    ==
  =/  updated  (~(gas ba:tarball my-ball) files)
  ;:  weld
    %+  expect-eq
      !>  `[~ [%mime !>([/text/plain [5 'hello']])]]
    !>  (~(get ba:tarball updated) /foo %test)
    %+  expect-eq
      !>  `[~ [%mime !>([/text/css [4 'hmm']])]]
    !>  (~(get ba:tarball updated) /bar %thing)
  ==
::
++  test-tap
  =/  my-ball  *ball:tarball
  =/  content1=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  content2=content:tarball  [~ [%mime !>([/text/html [3 'bye']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %test] content1)
  =/  g2  (~(put ba:tarball g1) [/foo %other] content2)
  =/  result  ~(tap ba:tarball g2)
  %-  expect
  !>  =((lent result) 2)
::
++  test-run
  =/  my-ball  *ball:tarball
  =/  content1=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %test] content1)
  ::  Identity transform - run should preserve content
  =/  updated  (~(run ba:tarball g1) |=(c=content:tarball c))
  =/  result  (~(got ba:tarball updated) /foo %test)
  %+  expect-eq
    !>  content1
  !>  result
::
++  test-rep
  =/  my-ball  *ball:tarball
  =/  content1=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  content2=content:tarball  [~ [%mime !>([/text/html [3 'bye']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %test] content1)
  =/  g2  (~(put ba:tarball g1) [/bar %other] content2)
  ::  Count all entries
  =/  total  (~(rep ba:tarball g2) |=([[* c=content:tarball] acc=@ud] (add acc 1)))
  %+  expect-eq
    !>  2
  !>  total
::
++  test-all
  =/  my-ball  *ball:tarball
  =/  content1=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  content2=content:tarball  [~ [%mime !>([/text/plain [3 'bye']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %test] content1)
  =/  g2  (~(put ba:tarball g1) [/bar %other] content2)
  ::  Check all are mime cages (all content is now just cage)
  %-  expect
  !>  (~(all ba:tarball g2) |=(c=content:tarball =(%mime p.cage.c)))
::
++  test-all-false
  =/  my-ball  *ball:tarball
  =/  content1=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  content2=content:tarball  [~ [%mime !>([/text/html [3 'bye']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %test] content1)
  =/  g2  (~(put ba:tarball g1) [/bar %other] content2)
  ::  Check if all match false predicate (should be false)
  %+  expect-eq
    !>  %.n
  !>  (~(all ba:tarball g2) |=(c=content:tarball %.n))
::
++  test-put-overwrite
  =/  my-ball  *ball:tarball
  =/  content1=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  content2=content:tarball  [~ [%mime !>([/text/html [3 'bye']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %test] content1)
  =/  g2  (~(put ba:tarball g1) [/foo %test] content2)
  =/  result  (~(get ba:tarball g2) /foo %test)
  %+  expect-eq
    !>  `content2
  !>  result
::
++  test-del-nonexistent
  =/  my-ball  *ball:tarball
  =/  result  (~(del ba:tarball my-ball) /foo %nonexistent)
  %+  expect-eq
    !>  my-ball
  !>  result
::
++  test-lis-empty
  =/  my-ball  *ball:tarball
  =/  result  (~(lis ba:tarball my-ball) /foo)
  %+  expect-eq
    !>  ~
  !>  result
::
++  test-gut-exists
  =/  my-ball  *ball:tarball
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  default=content:tarball  [~ [%mime !>([/text/html [7 'default']])]]
  =/  updated  (~(put ba:tarball my-ball) [/foo %test] content)
  =/  result  (~(gut ba:tarball updated) [/foo %test] default)
  %+  expect-eq
    !>  content
  !>  result
::
++  test-wyt-empty
  =/  my-ball  *ball:tarball
  %+  expect-eq
    !>  0
  !>  ~(wyt ba:tarball my-ball)
::
++  test-tap-empty
  =/  my-ball  *ball:tarball
  %+  expect-eq
    !>  ~
  !>  ~(tap ba:tarball my-ball)
::
++  test-run-empty
  =/  my-ball  *ball:tarball
  =/  result  (~(run ba:tarball my-ball) |=(c=content:tarball c))
  %+  expect-eq
    !>  my-ball
  !>  result
::
++  test-gas-empty
  =/  my-ball  *ball:tarball
  =/  result  (~(gas ba:tarball my-ball) ~)
  %+  expect-eq
    !>  my-ball
  !>  result
::
++  test-rep-empty
  =/  my-ball  *ball:tarball
  =/  result  (~(rep ba:tarball my-ball) |=([[* c=content:tarball] acc=@ud] acc))
  %+  expect-eq
    !>  0
  !>  result
::
++  test-all-empty
  =/  my-ball  *ball:tarball
  ::  Vacuous truth - all files match predicate when there are no files
  %+  expect-eq
    !>  %.y
  !>  (~(all ba:tarball my-ball) |=(c=content:tarball %.n))
::
++  test-any-empty
  =/  my-ball  *ball:tarball
  %+  expect-eq
    !>  %.n
  !>  (~(any ba:tarball my-ball) |=(c=content:tarball %.y))
::
++  test-any-none-match
  =/  my-ball  *ball:tarball
  =/  content1=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  content2=content:tarball  [~ [%mime !>([/text/plain [3 'bye']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %test] content1)
  =/  g2  (~(put ba:tarball g1) [/bar %other] content2)
  ::  Check if any match false predicate (should be false)
  %+  expect-eq
    !>  %.n
  !>  (~(any ba:tarball g2) |=(c=content:tarball %.n))
::
++  test-lop-nonexistent
  =/  my-ball  *ball:tarball
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo/bar %test] content)
  =/  result  (~(lop ba:tarball g1) /baz)
  ::  Should be no-op, ball unchanged
  %+  expect-eq
    !>  g1
  !>  result
::
++  test-dip-nonexistent
  =/  my-ball  *ball:tarball
  =/  result  (~(dip ba:tarball my-ball) /nonexistent)
  %+  expect-eq
    !>  [fil=~ dir=~]
  !>  result
::
++  test-any
  =/  my-ball  *ball:tarball
  =/  content1=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  content2=content:tarball  [~ [%mime !>([/text/html [3 'bye']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %test] content1)
  =/  g2  (~(put ba:tarball g1) [/bar %other] content2)
  ::  Check if any are mime cages (all content is now just cage)
  %-  expect
  !>  (~(any ba:tarball g2) |=(c=content:tarball =(%mime p.cage.c)))
::
++  test-lop
  =/  my-ball  *ball:tarball
  =/  content1=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  content2=content:tarball  [~ [%mime !>([/text/html [3 'bye']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo/bar %test] content1)
  =/  g2  (~(put ba:tarball g1) [/foo/bar %other] content2)
  ::  Delete entire /foo subtree
  =/  updated  (~(lop ba:tarball g2) /foo)
  %+  expect-eq
    !>  ~
  !>  (~(get ba:tarball updated) /foo/bar %test)
::
++  test-dip
  =/  my-ball  *ball:tarball
  =/  content1=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  content2=content:tarball  [~ [%mime !>([/text/html [3 'bye']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo/bar %test] content1)
  =/  g2  (~(put ba:tarball g1) [/foo/bar %other] content2)
  ::  Get directory at /foo/bar as a ball
  =/  subball  (~(dip ba:tarball g2) /foo/bar)
  =/  files  (~(get of subball) /)
  %-  expect
  !>  ?=(^ files)
::
++  test-dap-empty-root
  ::  Root path ALWAYS exists, even in empty ball
  =/  my-ball  *ball:tarball
  =/  dap-result  (~(dap ba:tarball my-ball) /)
  =/  dip-result  (~(dip ba:tarball my-ball) /)
  ;:  weld
    ::  dap should return [~ ball] - root exists
    %-  expect
    !>  ?=(^ dap-result)
    ::  dip returns the ball itself
    %+  expect-eq
      !>  my-ball
    !>  dip-result
  ==
::
++  test-dap-nonexistent-in-empty
  ::  Non-existent path in empty ball
  =/  my-ball  *ball:tarball
  =/  dap-result  (~(dap ba:tarball my-ball) /foo)
  =/  dip-result  (~(dip ba:tarball my-ball) /foo)
  ;:  weld
    ::  dap should return ~ - path doesn't exist
    %+  expect-eq
      !>  ~
    !>  dap-result
    ::  dip returns [~ ~] - went off the rails
    %+  expect-eq
      !>  [fil=~ dir=~]
    !>  dip-result
  ==
::
++  test-dap-exists-with-files
  ::  Path exists when files are present
  =/  my-ball  *ball:tarball
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo/bar %test] content)
  =/  dap-result  (~(dap ba:tarball g1) /foo/bar)
  =/  dip-result  (~(dip ba:tarball g1) /foo/bar)
  ;:  weld
    ::  dap should return [~ ball] - path exists
    %-  expect
    !>  ?=(^ dap-result)
    ::  dip returns the node at /foo/bar
    %-  expect
    !>  ?=(^ fil.dip-result)
  ==
::
++  test-dap-exists-after-delete
  ::  Path still exists after deleting files (structure remains)
  =/  my-ball  *ball:tarball
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo/bar %test] content)
  =/  g2  (~(del ba:tarball g1) /foo/bar %test)
  =/  dap-result  (~(dap ba:tarball g2) /foo/bar)
  =/  dip-result  (~(dip ba:tarball g2) /foo/bar)
  ;:  weld
    ::  dap should return [~ ball] - path exists (but empty)
    %-  expect
    !>  ?=(^ dap-result)
    ::  dip returns node with empty lump (empty metadata, no neck, empty contents)
    %+  expect-eq
      !>  [fil=[~ [metadata=~ neck=~ contents=~]] dir=~]
    !>  dip-result
  ==
::
++  test-dap-nonexistent-sibling
  ::  Path doesn't exist if we never created it
  =/  my-ball  *ball:tarball
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %test] content)
  =/  dap-result  (~(dap ba:tarball g1) /bar)
  =/  dip-result  (~(dip ba:tarball g1) /bar)
  ;:  weld
    ::  dap should return ~ - path doesn't exist
    %+  expect-eq
      !>  ~
    !>  dap-result
    ::  dip returns [~ ~] - went off the rails
    %+  expect-eq
      !>  [fil=~ dir=~]
    !>  dip-result
  ==
::
++  test-dap-nonexistent-child
  ::  Path doesn't exist if we go deeper than structure
  =/  my-ball  *ball:tarball
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %test] content)
  =/  dap-result  (~(dap ba:tarball g1) /foo/bar)
  =/  dip-result  (~(dip ba:tarball g1) /foo/bar)
  ;:  weld
    ::  dap should return ~ - path doesn't exist
    %+  expect-eq
      !>  ~
    !>  dap-result
    ::  dip returns [~ ~] - went off the rails
    %+  expect-eq
      !>  [fil=~ dir=~]
    !>  dip-result
  ==
::
++  test-dap-parent-exists
  ::  Parent path exists when child has files
  =/  my-ball  *ball:tarball
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo/bar/baz %test] content)
  =/  dap-result  (~(dap ba:tarball g1) /foo)
  =/  dip-result  (~(dip ba:tarball g1) /foo)
  ;:  weld
    ::  dap should return [~ ball] - path exists
    %-  expect
    !>  ?=(^ dap-result)
    ::  dip returns node with subdirectories
    %-  expect
    !>  !=(~ dir.dip-result)
  ==
::
::  parse-symlink tests
::
++  test-parse-symlink-absolute-simple
  =/  result  (parse-symlink:tarball '/foo')
  %+  expect-eq
    !>  `[%& /foo]
  !>  result
::
++  test-parse-symlink-absolute-multi
  =/  result  (parse-symlink:tarball '/foo/bar/baz')
  %+  expect-eq
    !>  `[%& /foo/bar/baz]
  !>  result
::
++  test-parse-symlink-absolute-root
  =/  result  (parse-symlink:tarball '/')
  %+  expect-eq
    !>  `[%& ~]
  !>  result
::
++  test-parse-symlink-absolute-two-level
  =/  result  (parse-symlink:tarball '/a/b')
  %+  expect-eq
    !>  `[%& /a/b]
  !>  result
::
++  test-parse-symlink-relative-simple
  =/  result  (parse-symlink:tarball 'foo')
  %+  expect-eq
    !>  `[%| [0 /foo]]
  !>  result
::
++  test-parse-symlink-relative-multi
  =/  result  (parse-symlink:tarball 'foo/bar')
  %+  expect-eq
    !>  `[%| [0 /foo/bar]]
  !>  result
::
++  test-parse-symlink-relative-three
  =/  result  (parse-symlink:tarball 'foo/bar/baz')
  %+  expect-eq
    !>  `[%| [0 /foo/bar/baz]]
  !>  result
::
++  test-parse-symlink-relative-with-dots
  =/  result  (parse-symlink:tarball 'foo.txt')
  ::  Just check it parses successfully
  %+  expect-eq
    !>  `[%| [0 /'foo.txt']]
  !>  result
::
++  test-parse-symlink-up-one
  =/  result  (parse-symlink:tarball '../foo')
  %+  expect-eq
    !>  `[%| [1 /foo]]
  !>  result
::
++  test-parse-symlink-up-two
  =/  result  (parse-symlink:tarball '../../foo')
  %+  expect-eq
    !>  `[%| [2 /foo]]
  !>  result
::
++  test-parse-symlink-up-three
  =/  result  (parse-symlink:tarball '../../../foo')
  %+  expect-eq
    !>  `[%| [3 /foo]]
  !>  result
::
++  test-parse-symlink-up-with-multi-path
  =/  result  (parse-symlink:tarball '../foo/bar')
  %+  expect-eq
    !>  `[%| [1 /foo/bar]]
  !>  result
::
++  test-parse-symlink-up-two-with-path
  =/  result  (parse-symlink:tarball '../../foo/bar/baz')
  %+  expect-eq
    !>  `[%| [2 /foo/bar/baz]]
  !>  result
::
++  test-parse-symlink-just-one-up
  =/  result  (parse-symlink:tarball '..')
  %+  expect-eq
    !>  `[%| [1 ~]]
  !>  result
::
++  test-parse-symlink-just-two-up
  =/  result  (parse-symlink:tarball '../..')
  %+  expect-eq
    !>  `[%| [2 ~]]
  !>  result
::
++  test-parse-symlink-just-three-up
  =/  result  (parse-symlink:tarball '../../..')
  %+  expect-eq
    !>  `[%| [3 ~]]
  !>  result
::
++  test-parse-symlink-empty
  =/  result  (parse-symlink:tarball '')
  %+  expect-eq
    !>  `[%| [0 ~]]
  !>  result
::
++  test-parse-symlink-absolute-trailing-slash
  ::  stap parser handles trailing slashes
  =/  result  (parse-symlink:tarball '/foo/')
  %-  expect
  !>  ?=(^ result)
::
++  test-parse-symlink-relative-complex
  =/  result  (parse-symlink:tarball 'a/b/c/d')
  %+  expect-eq
    !>  `[%| [0 /a/b/c/d]]
  !>  result
::
++  test-parse-symlink-up-four
  =/  result  (parse-symlink:tarball '../../../../foo')
  %+  expect-eq
    !>  `[%| [4 /foo]]
  !>  result
::
++  test-parse-symlink-up-many-no-path
  =/  result  (parse-symlink:tarball '../../../..')
  %+  expect-eq
    !>  `[%| [4 ~]]
  !>  result
::
++  test-parse-symlink-single-char
  =/  result  (parse-symlink:tarball 'a')
  %+  expect-eq
    !>  `[%| [0 /a]]
  !>  result
::
++  test-parse-symlink-absolute-single-char
  =/  result  (parse-symlink:tarball '/x')
  %+  expect-eq
    !>  `[%& /x]
  !>  result
::
++  test-parse-symlink-up-then-simple
  =/  result  (parse-symlink:tarball '../x')
  %+  expect-eq
    !>  `[%| [1 /x]]
  !>  result
::
++  test-parse-symlink-numbers-in-path
  =/  result  (parse-symlink:tarball 'foo123/bar456')
  %+  expect-eq
    !>  `[%| [0 /foo123/bar456]]
  !>  result
::
++  test-parse-symlink-hyphens-in-path
  =/  result  (parse-symlink:tarball 'foo-bar/baz-qux')
  %+  expect-eq
    !>  `[%| [0 /foo-bar/baz-qux]]
  !>  result
::
++  test-parse-symlink-absolute-deep
  =/  result  (parse-symlink:tarball '/a/b/c/d/e/f')
  %+  expect-eq
    !>  `[%& /a/b/c/d/e/f]
  !>  result
::
++  test-parse-symlink-up-mixed
  =/  result  (parse-symlink:tarball '../foo/../bar')
  ::  Should parse but normalize differently - just check it parses
  %-  expect
  !>  ?=(^ result)
::
::  encode-symlink tests
::
++  test-encode-symlink-absolute-simple
  =/  result  (encode-symlink:tarball [%& /foo])
  %+  expect-eq
    !>  '/foo'
  !>  result
::
++  test-encode-symlink-absolute-multi
  =/  result  (encode-symlink:tarball [%& /foo/bar/baz])
  %+  expect-eq
    !>  '/foo/bar/baz'
  !>  result
::
++  test-encode-symlink-absolute-root
  =/  result  (encode-symlink:tarball [%& ~])
  %+  expect-eq
    !>  '/'
  !>  result
::
++  test-encode-symlink-relative-simple
  =/  result  (encode-symlink:tarball [%| [0 /foo]])
  %+  expect-eq
    !>  'foo'
  !>  result
::
++  test-encode-symlink-relative-multi
  =/  result  (encode-symlink:tarball [%| [0 /foo/bar]])
  %+  expect-eq
    !>  'foo/bar'
  !>  result
::
++  test-encode-symlink-relative-empty
  =/  result  (encode-symlink:tarball [%| [0 ~]])
  %+  expect-eq
    !>  ''
  !>  result
::
++  test-encode-symlink-up-one
  =/  result  (encode-symlink:tarball [%| [1 /foo]])
  %+  expect-eq
    !>  '../foo'
  !>  result
::
++  test-encode-symlink-up-two
  =/  result  (encode-symlink:tarball [%| [2 /foo]])
  %+  expect-eq
    !>  '../../foo'
  !>  result
::
++  test-encode-symlink-up-three
  =/  result  (encode-symlink:tarball [%| [3 /foo]])
  %+  expect-eq
    !>  '../../../foo'
  !>  result
::
++  test-encode-symlink-just-one-up
  =/  result  (encode-symlink:tarball [%| [1 ~]])
  %+  expect-eq
    !>  '..'
  !>  result
::
++  test-encode-symlink-just-two-up
  =/  result  (encode-symlink:tarball [%| [2 ~]])
  %+  expect-eq
    !>  '../..'
  !>  result
::
++  test-encode-symlink-just-three-up
  =/  result  (encode-symlink:tarball [%| [3 ~]])
  %+  expect-eq
    !>  '../../..'
  !>  result
::
++  test-encode-symlink-up-with-multi-path
  =/  result  (encode-symlink:tarball [%| [1 /foo/bar]])
  %+  expect-eq
    !>  '../foo/bar'
  !>  result
::
++  test-encode-symlink-up-four-with-path
  =/  result  (encode-symlink:tarball [%| [4 /foo]])
  %+  expect-eq
    !>  '../../../../foo'
  !>  result
::
::  Round-trip tests: parse -> encode should give back original
::
++  test-roundtrip-absolute-simple
  =/  original  '/foo'
  =/  parsed  (parse-symlink:tarball original)
  ?~  parsed  !!
  =/  encoded  (encode-symlink:tarball u.parsed)
  %+  expect-eq
    !>  original
  !>  encoded
::
++  test-roundtrip-absolute-multi
  =/  original  '/foo/bar/baz'
  =/  parsed  (parse-symlink:tarball original)
  ?~  parsed  !!
  =/  encoded  (encode-symlink:tarball u.parsed)
  %+  expect-eq
    !>  original
  !>  encoded
::
++  test-roundtrip-absolute-root
  =/  original  '/'
  =/  parsed  (parse-symlink:tarball original)
  ?~  parsed  !!
  =/  encoded  (encode-symlink:tarball u.parsed)
  %+  expect-eq
    !>  original
  !>  encoded
::
++  test-roundtrip-relative-simple
  =/  original  'foo'
  =/  parsed  (parse-symlink:tarball original)
  ?~  parsed  !!
  =/  encoded  (encode-symlink:tarball u.parsed)
  %+  expect-eq
    !>  original
  !>  encoded
::
++  test-roundtrip-relative-multi
  =/  original  'foo/bar'
  =/  parsed  (parse-symlink:tarball original)
  ?~  parsed  !!
  =/  encoded  (encode-symlink:tarball u.parsed)
  %+  expect-eq
    !>  original
  !>  encoded
::
++  test-roundtrip-empty
  =/  original  ''
  =/  parsed  (parse-symlink:tarball original)
  ?~  parsed  !!
  =/  encoded  (encode-symlink:tarball u.parsed)
  %+  expect-eq
    !>  original
  !>  encoded
::
++  test-roundtrip-up-one
  =/  original  '../foo'
  =/  parsed  (parse-symlink:tarball original)
  ?~  parsed  !!
  =/  encoded  (encode-symlink:tarball u.parsed)
  %+  expect-eq
    !>  original
  !>  encoded
::
++  test-roundtrip-up-two
  =/  original  '../../foo'
  =/  parsed  (parse-symlink:tarball original)
  ?~  parsed  !!
  =/  encoded  (encode-symlink:tarball u.parsed)
  %+  expect-eq
    !>  original
  !>  encoded
::
++  test-roundtrip-just-one-up
  =/  original  '..'
  =/  parsed  (parse-symlink:tarball original)
  ?~  parsed  !!
  =/  encoded  (encode-symlink:tarball u.parsed)
  %+  expect-eq
    !>  original
  !>  encoded
::
++  test-roundtrip-just-two-up
  =/  original  '../..'
  =/  parsed  (parse-symlink:tarball original)
  ?~  parsed  !!
  =/  encoded  (encode-symlink:tarball u.parsed)
  %+  expect-eq
    !>  original
  !>  encoded
::
++  test-roundtrip-complex
  =/  original  '../../foo/bar/baz'
  =/  parsed  (parse-symlink:tarball original)
  ?~  parsed  !!
  =/  encoded  (encode-symlink:tarball u.parsed)
  %+  expect-eq
    !>  original
  !>  encoded
::
::  resolve-symlink tests
::
++  test-resolve-symlink-absolute
  =/  result  (resolve-symlink:tarball [%& /absolute/path] /foo/bar)
  %+  expect-eq
    !>  /absolute/path
  !>  result
::
++  test-resolve-symlink-absolute-from-root
  =/  result  (resolve-symlink:tarball [%& /foo] ~)
  %+  expect-eq
    !>  /foo
  !>  result
::
++  test-resolve-symlink-relative-simple
  =/  result  (resolve-symlink:tarball [%| [0 /baz]] /foo/bar)
  %+  expect-eq
    !>  /foo/bar/baz
  !>  result
::
++  test-resolve-symlink-relative-multi
  =/  result  (resolve-symlink:tarball [%| [0 /baz/qux]] /foo/bar)
  %+  expect-eq
    !>  /foo/bar/baz/qux
  !>  result
::
++  test-resolve-symlink-up-one
  =/  result  (resolve-symlink:tarball [%| [1 /baz]] /foo/bar)
  %+  expect-eq
    !>  /foo/baz
  !>  result
::
++  test-resolve-symlink-up-two
  =/  result  (resolve-symlink:tarball [%| [2 /baz]] /foo/bar/qux)
  %+  expect-eq
    !>  /foo/baz
  !>  result
::
++  test-resolve-symlink-up-to-root
  =/  result  (resolve-symlink:tarball [%| [2 /baz]] /foo/bar)
  %+  expect-eq
    !>  /baz
  !>  result
::
++  test-resolve-symlink-just-up-one
  =/  result  (resolve-symlink:tarball [%| [1 ~]] /foo/bar)
  %+  expect-eq
    !>  /foo
  !>  result
::
++  test-resolve-symlink-just-up-two
  =/  result  (resolve-symlink:tarball [%| [2 ~]] /foo/bar/baz)
  %+  expect-eq
    !>  /foo
  !>  result
::
++  test-resolve-symlink-current-dir
  =/  result  (resolve-symlink:tarball [%| [0 ~]] /foo/bar)
  %+  expect-eq
    !>  /foo/bar
  !>  result
::
++  test-resolve-symlink-relative-from-root
  =/  result  (resolve-symlink:tarball [%| [0 /foo]] ~)
  %+  expect-eq
    !>  /foo
  !>  result
::
++  test-resolve-symlink-up-past-root
  ::  Going up past root should just give root
  =/  result  (resolve-symlink:tarball [%| [5 /foo]] /bar)
  %+  expect-eq
    !>  /foo
  !>  result
::
++  test-resolve-symlink-complex
  =/  result  (resolve-symlink:tarball [%| [1 /sibling/child]] /foo/bar/baz)
  %+  expect-eq
    !>  /foo/bar/sibling/child
  !>  result
::
::  da-oct round-trip tests
::
++  test-da-oct-epoch
  ::  Unix epoch ~1970.1.1 should convert to '0'
  =/  epoch  ~1970.1.1
  =/  octal-result  (da-oct:tarball epoch)
  %+  expect-eq
    !>  '0'
  !>  octal-result
::
++  test-da-oct-roundtrip-epoch
  ::  Round-trip: @da -> octal -> @da
  =/  original  ~1970.1.1
  =/  octal-text  (da-oct:tarball original)
  =/  unix-secs  (rash octal-text oct:tarball)
  =/  restored  (add ~1970.1.1 (mul unix-secs ~s1))
  %+  expect-eq
    !>  original
  !>  restored
::
++  test-da-oct-roundtrip-2024
  ::  Test with a realistic date
  =/  original  ~2024.1.1
  =/  octal-text  (da-oct:tarball original)
  =/  unix-secs  (rash octal-text oct:tarball)
  =/  restored  (add ~1970.1.1 (mul unix-secs ~s1))
  %+  expect-eq
    !>  original
  !>  restored
::
++  test-da-oct-roundtrip-2025
  =/  original  ~2025.10.14
  =/  octal-text  (da-oct:tarball original)
  =/  unix-secs  (rash octal-text oct:tarball)
  =/  restored  (add ~1970.1.1 (mul unix-secs ~s1))
  %+  expect-eq
    !>  original
  !>  restored
::
++  test-da-oct-roundtrip-future
  ::  Test with a future date
  =/  original  ~2030.12.31
  =/  octal-text  (da-oct:tarball original)
  =/  unix-secs  (rash octal-text oct:tarball)
  =/  restored  (add ~1970.1.1 (mul unix-secs ~s1))
  %+  expect-eq
    !>  original
  !>  restored
::
++  test-da-oct-year-2000
  =/  original  ~2000.1.1
  =/  octal-text  (da-oct:tarball original)
  =/  unix-secs  (rash octal-text oct:tarball)
  =/  restored  (add ~1970.1.1 (mul unix-secs ~s1))
  %+  expect-eq
    !>  original
  !>  restored
::
++  test-da-oct-year-1990
  =/  original  ~1990.6.15
  =/  octal-text  (da-oct:tarball original)
  =/  unix-secs  (rash octal-text oct:tarball)
  =/  restored  (add ~1970.1.1 (mul unix-secs ~s1))
  %+  expect-eq
    !>  original
  !>  restored
::
++  test-da-oct-is-octal-format
  ::  Verify the output is actually octal (only digits 0-7)
  =/  original  ~2024.1.1
  =/  octal-text  (da-oct:tarball original)
  =/  text-tape  (trip octal-text)
  ::  All characters should be octal digits (0-7)
  %-  expect
  !>  %+  levy  text-tape
      |=  c=@t
      ?&  (gte c '0')
          (lte c '7')
      ==
::
++  test-da-oct-monotonic
  ::  Later dates should have larger octal values
  =/  earlier  ~2020.1.1
  =/  later    ~2025.1.1
  =/  earlier-oct  (rash (da-oct:tarball earlier) oct:tarball)
  =/  later-oct    (rash (da-oct:tarball later) oct:tarball)
  %-  expect
  !>  (gth later-oct earlier-oct)
::
::  parse-extension tests
::
++  test-parse-extension-simple
  =/  result  (parse-extension:tarball 'data.json')
  %+  expect-eq
    !>  `%json
  !>  result
::
++  test-parse-extension-multiple-dots
  =/  result  (parse-extension:tarball 'my.file.txt')
  %+  expect-eq
    !>  `%txt
  !>  result
::
++  test-parse-extension-no-extension
  =/  result  (parse-extension:tarball 'readme')
  %+  expect-eq
    !>  ~
  !>  result
::
++  test-parse-extension-hidden-file
  =/  result  (parse-extension:tarball '.gitignore')
  %+  expect-eq
    !>  `%gitignore
  !>  result
::
++  test-parse-extension-with-hyphen
  =/  result  (parse-extension:tarball 'page.html-css')
  %+  expect-eq
    !>  `%html-css
  !>  result
::
++  test-parse-extension-with-number
  =/  result  (parse-extension:tarball 'file.mp3')
  %+  expect-eq
    !>  `%mp3
  !>  result
::
++  test-parse-extension-uppercase
  =/  result  (parse-extension:tarball 'IMAGE.PNG')
  %+  expect-eq
    !>  `%png
  !>  result
::
++  test-parse-extension-mixed-case
  =/  result  (parse-extension:tarball 'File.TxT')
  %+  expect-eq
    !>  `%txt
  !>  result
::
++  test-parse-extension-single-char
  =/  result  (parse-extension:tarball 'makefile.c')
  %+  expect-eq
    !>  `%c
  !>  result
::
++  test-parse-extension-long-ext
  =/  result  (parse-extension:tarball 'archive.tar-gz')
  %+  expect-eq
    !>  `%tar-gz
  !>  result
::
++  test-parse-extension-path-like
  =/  result  (parse-extension:tarball 'path/to/file.md')
  ::  Note: this is just a filename, should still extract .md
  %+  expect-eq
    !>  `%md
  !>  result
::
++  test-parse-extension-complex-hyphen
  =/  result  (parse-extension:tarball 'style.css-min')
  %+  expect-eq
    !>  `%css-min
  !>  result
::
++  test-parse-extension-alphanumeric
  =/  result  (parse-extension:tarball 'video.mp4')
  %+  expect-eq
    !>  `%mp4
  !>  result
::
::  mime-to-cage tests
::
++  test-mime-to-cage-no-extension
  =/  conversions  *(map mars:clay tube:clay)
  =/  test-mime  [/text/plain [5 'hello']]
  =/  result  (mime-to-cage:tarball conversions 'readme' test-mime)
  %+  expect-eq
    !>  ~
  !>  result
::
++  test-mime-to-cage-jammed-no-ext
  =/  conversions  *(map mars:clay tube:clay)
  =/  test-data  42
  =/  jammed  (jam test-data)
  =/  test-mime  [/application/x-urb-jam (as-octs:mimes:html jammed)]
  =/  result  (mime-to-cage:tarball conversions 'data' test-mime)
  ::  No extension - should return ~
  %+  expect-eq
    !>  ~
  !>  result
::
++  test-mime-to-cage-jammed-with-ext
  =/  conversions  *(map mars:clay tube:clay)
  =/  test-data  [%hello %world]
  =/  jammed  (jam test-data)
  =/  test-mime  [/application/x-urb-jam (as-octs:mimes:html jammed)]
  =/  result  (mime-to-cage:tarball conversions 'data.jam' test-mime)
  ::  No conversion for .jam - should return ~
  %+  expect-eq
    !>  ~
  !>  result
::
++  test-mime-to-cage-no-conversion
  =/  conversions  *(map mars:clay tube:clay)
  =/  test-mime  [/text/plain [5 'hello']]
  =/  result  (mime-to-cage:tarball conversions 'data.txt' test-mime)
  %+  expect-eq
    !>  ~
  !>  result
::
++  test-mime-to-cage-with-conversion
  ::  Mock a conversion from mime to json mark
  =/  mock-tube=$-(vase vase)
    |=  v=vase
    !>([%array ~[[%string 'test']]])
  =/  conversions=(map mars:clay tube:clay)
    (~(put by *(map mars:clay tube:clay)) [%mime %json] mock-tube)
  =/  test-mime  [/application/json [2 '{}']]
  =/  result  (mime-to-cage:tarball conversions 'data.json' test-mime)
  ?~  result  !!
  ;:  weld
    %+  expect-eq
      !>  %json
    !>  p.u.result
    %+  expect-eq
      !>  !>([%array ~[[%string 'test']]])
    !>  q.u.result
  ==
::
++  test-mime-to-cage-uppercase-ext
  =/  conversions  *(map mars:clay tube:clay)
  =/  test-mime  [/text/plain [5 'HELLO']]
  =/  result  (mime-to-cage:tarball conversions 'FILE.TXT' test-mime)
  ::  Extension should be normalized to lowercase, but no conversion so returns ~
  %+  expect-eq
    !>  ~
  !>  result
::
++  test-mime-to-cage-hyphenated-ext
  =/  conversions  *(map mars:clay tube:clay)
  =/  test-mime  [/text/html [10 '<p>test</p>']]
  =/  result  (mime-to-cage:tarball conversions 'page.html-min' test-mime)
  %+  expect-eq
    !>  ~
  !>  result
::
++  test-mime-to-cage-jammed-complex
  =/  conversions  *(map mars:clay tube:clay)
  =/  test-data=(list @ud)  ~[1 2 3 4 5]
  =/  jammed  (jam test-data)
  =/  test-mime  [/application/x-urb-jam (as-octs:mimes:html jammed)]
  =/  result  (mime-to-cage:tarball conversions 'list.dat' test-mime)
  ::  No conversion for .dat - should return ~
  %+  expect-eq
    !>  ~
  !>  result
::
++  test-mime-to-cage-empty-conversions
  =/  conversions  *(map mars:clay tube:clay)
  =/  test-mime  [/text/css [4 'body']]
  =/  result  (mime-to-cage:tarball conversions 'style.css' test-mime)
  %+  expect-eq
    !>  ~
  !>  result
::
++  test-mime-to-cage-multiple-dots
  =/  conversions  *(map mars:clay tube:clay)
  =/  test-mime  [/text/plain [3 'hi']]
  =/  result  (mime-to-cage:tarball conversions 'my.backup.txt' test-mime)
  %+  expect-eq
    !>  ~
  !>  result
::
++  test-mime-to-cage-conversion-priority
  ::  With conversion available, should use it
  =/  mock-tube=$-(vase vase)
    |=  v=vase
    !>('converted')
  =/  conversions=(map mars:clay tube:clay)
    (~(put by *(map mars:clay tube:clay)) [%mime %md] mock-tube)
  =/  test-mime  [/text/markdown [6 '# Test']]
  =/  result  (mime-to-cage:tarball conversions 'readme.md' test-mime)
  ?~  result  !!
  ;:  weld
    %+  expect-eq
      !>  %md
    !>  p.u.result
    %+  expect-eq
      !>  !>('converted')
    !>  q.u.result
  ==
::
++  test-mime-to-cage-conversion-ignores-mime-type
  ::  Extension determines conversion, not mime type
  =/  mock-tube=$-(vase vase)
    |=  v=vase
    !>('converted-json')
  =/  conversions=(map mars:clay tube:clay)
    (~(put by *(map mars:clay tube:clay)) [%mime %json] mock-tube)
  =/  test-data  %test-atom
  =/  jammed  (jam test-data)
  =/  test-mime  [/application/x-urb-jam (as-octs:mimes:html jammed)]
  =/  result  (mime-to-cage:tarball conversions 'data.json' test-mime)
  ::  Should use .json conversion even though mime type is x-urb-jam
  ?~  result  !!
  ;:  weld
    %+  expect-eq
      !>  %json
    !>  p.u.result
    %+  expect-eq
      !>  !>('converted-json')
    !>  q.u.result
  ==
::
::  clear-temp tests
::
++  test-clear-temp-empty-ball
  ::  Empty ball should stay empty
  =/  my-ball  *ball:tarball
  =/  result  ~(clear-temp ba:tarball my-ball)
  %+  expect-eq
    !>  my-ball
  !>  result
::
++  test-clear-temp-removes-temp-cages
  ::  %temp cages should be removed
  =/  my-ball  *ball:tarball
  =/  temp-content=content:tarball  [~ [%temp !>('ephemeral')]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %temp-file] temp-content)
  =/  result  ~(clear-temp ba:tarball g1)
  ;:  weld
    ::  temp file should be gone
    %+  expect-eq
      !>  ~
    !>  (~(get ba:tarball result) /foo %temp-file)
    ::  count should be 0
    %+  expect-eq
      !>  0
    !>  ~(wyt ba:tarball result)
  ==
::
++  test-clear-temp-keeps-non-temp
  ::  Non-%temp cages should be preserved
  =/  my-ball  *ball:tarball
  =/  mime-content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  temp-content=content:tarball  [~ [%temp !>('ephemeral')]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %keep-file] mime-content)
  =/  g2  (~(put ba:tarball g1) [/foo %temp-file] temp-content)
  =/  result  ~(clear-temp ba:tarball g2)
  ;:  weld
    ::  mime file should remain
    %+  expect-eq
      !>  `mime-content
    !>  (~(get ba:tarball result) /foo %keep-file)
    ::  temp file should be gone
    %+  expect-eq
      !>  ~
    !>  (~(get ba:tarball result) /foo %temp-file)
    ::  count should be 1
    %+  expect-eq
      !>  1
    !>  ~(wyt ba:tarball result)
  ==
::
++  test-clear-temp-multiple-dirs
  ::  Should clear %temp from all directories
  =/  my-ball  *ball:tarball
  =/  temp1=content:tarball  [~ [%temp !>('t1')]]
  =/  temp2=content:tarball  [~ [%temp !>('t2')]]
  =/  keep=content:tarball   [~ [%mime !>([/text/plain [4 'keep']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %temp1] temp1)
  =/  g2  (~(put ba:tarball g1) [/bar %temp2] temp2)
  =/  g3  (~(put ba:tarball g2) [/baz %keep] keep)
  =/  result  ~(clear-temp ba:tarball g3)
  ;:  weld
    %+  expect-eq
      !>  ~
    !>  (~(get ba:tarball result) /foo %temp1)
    %+  expect-eq
      !>  ~
    !>  (~(get ba:tarball result) /bar %temp2)
    %+  expect-eq
      !>  `keep
    !>  (~(get ba:tarball result) /baz %keep)
    %+  expect-eq
      !>  1
    !>  ~(wyt ba:tarball result)
  ==
::
::  lss tests (list subdirectories)
::
++  test-lss-empty
  ::  Empty ball has no subdirectories at root
  =/  my-ball  *ball:tarball
  %+  expect-eq
    !>  ~
  !>  (~(lss ba:tarball my-ball) /)
::
++  test-lss-with-subdirs
  ::  Should list subdirectories
  =/  my-ball  *ball:tarball
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo/bar %test] content)
  =/  g2  (~(put ba:tarball g1) [/baz %test] content)
  =/  dirs  (~(lss ba:tarball g2) /)
  =/  dir-set  (~(gas in *(set @ta)) dirs)
  ;:  weld
    %-  expect
    !>  (~(has in dir-set) %foo)
    %-  expect
    !>  (~(has in dir-set) %baz)
    %+  expect-eq
      !>  2
    !>  ~(wyt in dir-set)
  ==
::
++  test-lss-nested
  ::  Should list only immediate children
  =/  my-ball  *ball:tarball
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo/bar/baz %test] content)
  =/  dirs-at-root  (~(lss ba:tarball g1) /)
  =/  dirs-at-foo   (~(lss ba:tarball g1) /foo)
  ;:  weld
    ::  At root: only /foo
    %+  expect-eq
      !>  ~[%foo]
    !>  dirs-at-root
    ::  At /foo: only /bar
    %+  expect-eq
      !>  ~[%bar]
    !>  dirs-at-foo
  ==
::
++  test-lss-nonexistent-path
  ::  Non-existent path returns empty
  =/  my-ball  *ball:tarball
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo %test] content)
  %+  expect-eq
    !>  ~
  !>  (~(lss ba:tarball g1) /nonexistent)
::
::  mkd tests (make directory with metadata and neck)
::
++  test-mkd-simple
  ::  Create empty directory
  =/  my-ball  *ball:tarball
  =/  result  (~(mkd ba:tarball my-ball) /foo ~ ~)
  =/  dap-result  (~(dap ba:tarball result) /foo)
  %-  expect
  !>  ?=(^ dap-result)
::
++  test-mkd-with-metadata
  ::  Create directory with metadata
  =/  my-ball  *ball:tarball
  =/  meta=(map @t @t)  (~(gas by *(map @t @t)) ~[['mtime' '12345']])
  =/  result  (~(mkd ba:tarball my-ball) /foo meta ~)
  =/  sub  (~(dip ba:tarball result) /foo)
  ?~  fil.sub  !!
  %+  expect-eq
    !>  `'12345'
  !>  (~(get by metadata.u.fil.sub) 'mtime')
::
++  test-mkd-with-neck
  ::  Create directory with neck (mark)
  =/  my-ball  *ball:tarball
  =/  result  (~(mkd ba:tarball my-ball) /tasks ~ `%worker)
  =/  sub  (~(dip ba:tarball result) /tasks)
  ?~  fil.sub  !!
  %+  expect-eq
    !>  `%worker
  !>  neck.u.fil.sub
::
++  test-mkd-with-metadata-and-neck
  ::  Create directory with both metadata and neck
  =/  my-ball  *ball:tarball
  =/  meta=(map @t @t)  (~(gas by *(map @t @t)) ~[['mtime' '12345'] ['owner' 'zod']])
  =/  result  (~(mkd ba:tarball my-ball) /tasks meta `%executor)
  =/  sub  (~(dip ba:tarball result) /tasks)
  ?~  fil.sub  !!
  ;:  weld
    %+  expect-eq
      !>  `%executor
    !>  neck.u.fil.sub
    %+  expect-eq
      !>  `'12345'
    !>  (~(get by metadata.u.fil.sub) 'mtime')
    %+  expect-eq
      !>  `'zod'
    !>  (~(get by metadata.u.fil.sub) 'owner')
  ==
::
++  test-mkd-nested
  ::  Create nested directories
  =/  my-ball  *ball:tarball
  =/  g1  (~(mkd ba:tarball my-ball) /foo ~ ~)
  =/  g2  (~(mkd ba:tarball g1) /foo/bar ~ `%special)
  =/  sub  (~(dip ba:tarball g2) /foo/bar)
  ?~  fil.sub  !!
  %+  expect-eq
    !>  `%special
  !>  neck.u.fil.sub
::
::  pub tests (put subtree at path)
::
++  test-pub-at-root
  ::  Pub at root replaces entire ball
  =/  my-ball  *ball:tarball
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  sub-ball  (~(put ba:tarball *ball:tarball) [/ %test] content)
  =/  result  (~(pub ba:tarball my-ball) / sub-ball)
  %+  expect-eq
    !>  `content
  !>  (~(get ba:tarball result) / %test)
::
++  test-pub-at-path
  ::  Pub at path inserts subtree
  =/  my-ball  *ball:tarball
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  sub-ball  (~(put ba:tarball *ball:tarball) [/ %test] content)
  =/  result  (~(pub ba:tarball my-ball) /foo/bar sub-ball)
  %+  expect-eq
    !>  `content
  !>  (~(get ba:tarball result) /foo/bar %test)
::
++  test-pub-replaces-existing
  ::  Pub replaces existing subtree
  =/  my-ball  *ball:tarball
  =/  old=content:tarball  [~ [%mime !>([/text/plain [3 'old']])]]
  =/  new=content:tarball  [~ [%mime !>([/text/plain [3 'new']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo/bar %file] old)
  =/  sub-ball  (~(put ba:tarball *ball:tarball) [/ %file] new)
  =/  result  (~(pub ba:tarball g1) /foo/bar sub-ball)
  %+  expect-eq
    !>  `new
  !>  (~(get ba:tarball result) /foo/bar %file)
::
++  test-pub-preserves-siblings
  ::  Pub at path should preserve sibling directories
  =/  my-ball  *ball:tarball
  =/  sibling=content:tarball  [~ [%mime !>([/text/plain [7 'sibling']])]]
  =/  new=content:tarball  [~ [%mime !>([/text/plain [3 'new']])]]
  =/  g1  (~(put ba:tarball my-ball) [/foo/sibling %file] sibling)
  =/  sub-ball  (~(put ba:tarball *ball:tarball) [/ %file] new)
  =/  result  (~(pub ba:tarball g1) /foo/target sub-ball)
  ;:  weld
    ::  New file should exist
    %+  expect-eq
      !>  `new
    !>  (~(get ba:tarball result) /foo/target %file)
    ::  Sibling should remain
    %+  expect-eq
      !>  `sibling
    !>  (~(get ba:tarball result) /foo/sibling %file)
  ==
::
++  test-pub-deep-subtree
  ::  Pub a multi-level subtree
  =/  my-ball  *ball:tarball
  =/  content1=content:tarball  [~ [%mime !>([/text/plain [2 'c1']])]]
  =/  content2=content:tarball  [~ [%mime !>([/text/plain [2 'c2']])]]
  =/  sub-ball  *ball:tarball
  =.  sub-ball  (~(put ba:tarball sub-ball) [/deep/nested %file1] content1)
  =.  sub-ball  (~(put ba:tarball sub-ball) [/other %file2] content2)
  =/  result  (~(pub ba:tarball my-ball) /root sub-ball)
  ;:  weld
    %+  expect-eq
      !>  `content1
    !>  (~(get ba:tarball result) /root/deep/nested %file1)
    %+  expect-eq
      !>  `content2
    !>  (~(get ba:tarball result) /root/other %file2)
  ==
::
::  lump creation tests (put/mkd/pub ensure directories have lumps)
::
++  test-put-creates-intermediate-lumps
  ::  Put at deep path should create lumps for intermediate directories
  =/  my-ball  *ball:tarball
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  result  (~(put ba:tarball my-ball) [/a/b/c %file] content)
  ::  Check intermediate directories have lumps
  =/  at-a  (~(dip ba:tarball result) /a)
  =/  at-ab  (~(dip ba:tarball result) /a/b)
  ;:  weld
    %-  expect
    !>  ?=(^ fil.at-a)
    %-  expect
    !>  ?=(^ fil.at-ab)
  ==
::
++  test-put-preserves-existing-lumps
  ::  Put should not overwrite existing lumps on intermediate directories
  =/  my-ball  *ball:tarball
  =/  meta=(map @t @t)  (~(gas by *(map @t @t)) ~[['key' 'value']])
  =/  g1  (~(mkd ba:tarball my-ball) /a meta `%special)
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  result  (~(put ba:tarball g1) [/a/b/c %file] content)
  =/  at-a  (~(dip ba:tarball result) /a)
  ?~  fil.at-a  !!
  ;:  weld
    ::  Neck should be preserved
    %+  expect-eq
      !>  `%special
    !>  neck.u.fil.at-a
    ::  Metadata should be preserved
    %+  expect-eq
      !>  `'value'
    !>  (~(get by metadata.u.fil.at-a) 'key')
  ==
::
++  test-put-at-root
  ::  Put at root (empty path) should work correctly
  =/  my-ball  *ball:tarball
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  result  (~(put ba:tarball my-ball) [/ %file] content)
  ;:  weld
    ::  File should exist
    %+  expect-eq
      !>  `content
    !>  (~(get ba:tarball result) / %file)
    ::  Root should have a lump
    %-  expect
    !>  ?=(^ fil.result)
  ==
::
++  test-put-multiple-paths-independent
  ::  Multiple puts to different paths should not interfere
  =/  my-ball  *ball:tarball
  =/  meta=(map @t @t)  (~(gas by *(map @t @t)) ~[['key' 'value']])
  =/  g1  (~(mkd ba:tarball my-ball) /x meta `%first)
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  g2  (~(put ba:tarball g1) [/y/z %file] content)
  ::  /x should still have its original lump
  =/  at-x  (~(dip ba:tarball g2) /x)
  =/  at-y  (~(dip ba:tarball g2) /y)
  ?~  fil.at-x  !!
  ;:  weld
    %+  expect-eq
      !>  `%first
    !>  neck.u.fil.at-x
    ::  /y should have a lump too
    %-  expect
    !>  ?=(^ fil.at-y)
  ==
::
++  test-put-deep-nesting
  ::  Put at very deep path should create lumps at all levels
  =/  my-ball  *ball:tarball
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  result  (~(put ba:tarball my-ball) [/a/b/c/d/e %file] content)
  =/  at-a  (~(dip ba:tarball result) /a)
  =/  at-ab  (~(dip ba:tarball result) /a/b)
  =/  at-abc  (~(dip ba:tarball result) /a/b/c)
  =/  at-abcd  (~(dip ba:tarball result) /a/b/c/d)
  ;:  weld
    %-  expect
    !>  ?=(^ fil.at-a)
    %-  expect
    !>  ?=(^ fil.at-ab)
    %-  expect
    !>  ?=(^ fil.at-abc)
    %-  expect
    !>  ?=(^ fil.at-abcd)
  ==
::
++  test-mkd-creates-intermediate-lumps
  ::  mkd at deep path should create lumps for intermediate directories
  =/  my-ball  *ball:tarball
  =/  result  (~(mkd ba:tarball my-ball) /a/b/c ~ `%target)
  ::  Check intermediate directories have lumps
  =/  at-a  (~(dip ba:tarball result) /a)
  =/  at-ab  (~(dip ba:tarball result) /a/b)
  ;:  weld
    %-  expect
    !>  ?=(^ fil.at-a)
    %-  expect
    !>  ?=(^ fil.at-ab)
  ==
::
++  test-mkd-preserves-existing-lumps
  ::  mkd should not overwrite existing lumps on intermediate directories
  =/  my-ball  *ball:tarball
  =/  meta=(map @t @t)  (~(gas by *(map @t @t)) ~[['key' 'value']])
  =/  g1  (~(mkd ba:tarball my-ball) /a meta `%special)
  =/  result  (~(mkd ba:tarball g1) /a/b/c ~ `%target)
  =/  at-a  (~(dip ba:tarball result) /a)
  =/  at-abc  (~(dip ba:tarball result) /a/b/c)
  ?~  fil.at-a  !!
  ?~  fil.at-abc  !!
  ;:  weld
    ::  /a neck should be preserved
    %+  expect-eq
      !>  `%special
    !>  neck.u.fil.at-a
    ::  /a metadata should be preserved
    %+  expect-eq
      !>  `'value'
    !>  (~(get by metadata.u.fil.at-a) 'key')
    ::  /a/b/c should have the target neck
    %+  expect-eq
      !>  `%target
    !>  neck.u.fil.at-abc
  ==
::
++  test-pub-creates-intermediate-lumps
  ::  pub at deep path should create lumps for intermediate directories
  =/  my-ball  *ball:tarball
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  sub-ball  (~(put ba:tarball *ball:tarball) [/ %file] content)
  =/  result  (~(pub ba:tarball my-ball) /a/b/c sub-ball)
  ::  Check intermediate directories have lumps
  =/  at-a  (~(dip ba:tarball result) /a)
  =/  at-ab  (~(dip ba:tarball result) /a/b)
  ;:  weld
    %-  expect
    !>  ?=(^ fil.at-a)
    %-  expect
    !>  ?=(^ fil.at-ab)
  ==
::
++  test-pub-preserves-existing-lumps
  ::  pub should not overwrite existing lumps on intermediate directories
  =/  my-ball  *ball:tarball
  =/  meta=(map @t @t)  (~(gas by *(map @t @t)) ~[['key' 'value']])
  =/  g1  (~(mkd ba:tarball my-ball) /a meta `%special)
  =/  content=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =/  sub-ball  (~(put ba:tarball *ball:tarball) [/ %file] content)
  =/  result  (~(pub ba:tarball g1) /a/b/c sub-ball)
  =/  at-a  (~(dip ba:tarball result) /a)
  ?~  fil.at-a  !!
  ;:  weld
    ::  Neck should be preserved
    %+  expect-eq
      !>  `%special
    !>  neck.u.fil.at-a
    ::  Metadata should be preserved
    %+  expect-eq
      !>  `'value'
    !>  (~(get by metadata.u.fil.at-a) 'key')
  ==
::
++  test-pub-subtree-lump-preserved
  ::  pub should preserve the subtree's own lump structure
  =/  my-ball  *ball:tarball
  =/  sub-meta=(map @t @t)  (~(gas by *(map @t @t)) ~[['sub-key' 'sub-value']])
  =/  sub-ball  (~(mkd ba:tarball *ball:tarball) / sub-meta `%sub-neck)
  =/  result  (~(pub ba:tarball my-ball) /target sub-ball)
  =/  at-target  (~(dip ba:tarball result) /target)
  ?~  fil.at-target  !!
  ;:  weld
    ::  Subtree's neck should be preserved
    %+  expect-eq
      !>  `%sub-neck
    !>  neck.u.fil.at-target
    ::  Subtree's metadata should be preserved
    %+  expect-eq
      !>  `'sub-value'
    !>  (~(get by metadata.u.fil.at-target) 'sub-key')
  ==
::
::  ==========================================
::  Path helper function tests
::  ==========================================
::
::  +rail-from-path tests
::
++  test-rail-from-path-single
  ::  Single element path -> rail with empty dir
  %+  expect-eq
    !>  `rail:tarball`[/ %foo]
  !>  (rail-from-path:tarball /foo)
::
++  test-rail-from-path-multi
  ::  Multi-element path -> rail with dir and name
  %+  expect-eq
    !>  `rail:tarball`[/a/b %c]
  !>  (rail-from-path:tarball /a/b/c)
::
++  test-rail-from-path-deep
  ::  Deep path
  %+  expect-eq
    !>  `rail:tarball`[/a/b/c/d %e]
  !>  (rail-from-path:tarball /a/b/c/d/e)
::
::  +rail-to-path tests
::
++  test-rail-to-path-root
  ::  File at root
  %+  expect-eq
    !>  /foo
  !>  (rail-to-path:tarball [/ %foo])
::
++  test-rail-to-path-nested
  ::  Nested file
  %+  expect-eq
    !>  /a/b/c
  !>  (rail-to-path:tarball [/a/b %c])
::
++  test-rail-roundtrip
  ::  rail-to-path and rail-from-path are inverses
  =/  pax=path  /a/b/c/d
  %+  expect-eq
    !>  pax
  !>  (rail-to-path:tarball (rail-from-path:tarball pax))
::
::  +relativize-rail tests
::
++  test-relativize-rail-simple
  ::  Relativize rail to its parent directory
  %+  expect-eq
    !>  `rail:tarball`[/c %file]
  !>  (relativize-rail:tarball /a/b [/a/b/c %file])
::
++  test-relativize-rail-root-base
  ::  Base at root
  %+  expect-eq
    !>  `rail:tarball`[/a/b %file]
  !>  (relativize-rail:tarball / [/a/b %file])
::
++  test-relativize-rail-same-dir
  ::  Base equals rail directory
  %+  expect-eq
    !>  `rail:tarball`[/ %file]
  !>  (relativize-rail:tarball /a/b [/a/b %file])
::
::  +lane-from-bend tests
::
++  test-lane-from-bend-zero-steps-file
  ::  Zero steps to file - prepends location path
  =/  loc=lane:tarball  [%| /a/b]
  =/  =bend:tarball  [0 [%& [/c %file]]]
  %+  expect-eq
    !>  `[%& [/a/b/c %file]]
  !>  (lane-from-bend:tarball loc bend)
::
++  test-lane-from-bend-zero-steps-dir
  ::  Zero steps to dir - prepends location path
  =/  loc=lane:tarball  [%| /a/b]
  =/  =bend:tarball  [0 [%| /c/d]]
  %+  expect-eq
    !>  `[%| /a/b/c/d]
  !>  (lane-from-bend:tarball loc bend)
::
++  test-lane-from-bend-one-step
  ::  Go up one step then resolve
  =/  loc=lane:tarball  [%| /a/b/c]
  =/  =bend:tarball  [1 [%& [/d %file]]]
  %+  expect-eq
    !>  `[%& [/a/b/d %file]]
  !>  (lane-from-bend:tarball loc bend)
::
++  test-lane-from-bend-two-steps
  ::  Go up two steps
  =/  loc=lane:tarball  [%| /a/b/c]
  =/  =bend:tarball  [2 [%& [/x %file]]]
  %+  expect-eq
    !>  `[%& [/a/x %file]]
  !>  (lane-from-bend:tarball loc bend)
::
++  test-lane-from-bend-exceeds-depth
  ::  Steps exceed path depth - returns ~
  =/  loc=lane:tarball  [%| /a/b]
  =/  =bend:tarball  [5 [%& [/c %file]]]
  %+  expect-eq
    !>  ~
  !>  (lane-from-bend:tarball loc bend)
::
++  test-lane-from-bend-from-file-loc
  ::  Location is a file (uses directory part)
  =/  loc=lane:tarball  [%& [/a/b %existing]]
  =/  =bend:tarball  [1 [%& [/c %file]]]
  %+  expect-eq
    !>  `[%& [/a/c %file]]
  !>  (lane-from-bend:tarball loc bend)
::
::  +lane-from-road tests
::
++  test-lane-from-road-absolute
  ::  Absolute road (lane) passes through
  =/  here=lane:tarball  [%| /anywhere]
  =/  =road:tarball  [%& [%& [/a/b %c]]]
  %+  expect-eq
    !>  `[%& [/a/b %c]]
  !>  (lane-from-road:tarball here road)
::
++  test-lane-from-road-relative
  ::  Relative road (bend) gets resolved
  =/  here=lane:tarball  [%| /a/b]
  =/  =road:tarball  [%| [1 [%& [/c %file]]]]
  %+  expect-eq
    !>  `[%& [/a/c %file]]
  !>  (lane-from-road:tarball here road)
::
::  +make-bend tests
::
++  test-make-bend-same-dir
  ::  File to sibling file in same dir - 0 steps (same directory)
  =/  here=rail:tarball  [/a/b %src]
  =/  dest=lane:tarball  [%& [/a/b %dest]]
  %+  expect-eq
    !>  `bend:tarball`[0 [%& / %dest]]
  !>  (make-bend:tarball here dest)
::
++  test-make-bend-going-up
  ::  File to file in grandparent directory - 2 steps up
  =/  here=rail:tarball  [/a/b/c %src]
  =/  dest=lane:tarball  [%& [/a %dest]]
  %+  expect-eq
    !>  `bend:tarball`[2 [%& / %dest]]
  !>  (make-bend:tarball here dest)
::
++  test-make-bend-going-down
  ::  File to file in child directory - 0 steps (dest is under here's dir)
  =/  here=rail:tarball  [/a %src]
  =/  dest=lane:tarball  [%& [/a/b/c %dest]]
  %+  expect-eq
    !>  `bend:tarball`[0 [%& /b/c %dest]]
  !>  (make-bend:tarball here dest)
::
++  test-make-bend-to-directory
  ::  File to directory - 1 step up to common ancestor /a
  =/  here=rail:tarball  [/a/b %src]
  =/  dest=lane:tarball  [%| /a/c/d]
  %+  expect-eq
    !>  `bend:tarball`[1 [%| /c/d]]
  !>  (make-bend:tarball here dest)
::
++  test-make-bend-roundtrip
  ::  make-bend + lane-from-bend should return original dest
  =/  here=rail:tarball  [/a/b %src]
  =/  dest=lane:tarball  [%& [/a/c/d %file]]
  =/  =bend:tarball  (make-bend:tarball here dest)
  =/  here-lane=lane:tarball  [%& here]
  %+  expect-eq
    !>  `dest
  !>  (lane-from-bend:tarball here-lane bend)
::
::  +make-bend-rail tests
::
++  test-make-bend-rail-basic
  ::  Convenience wrapper works
  =/  here=rail:tarball  [/a/b %src]
  =/  dest=rail:tarball  [/a/c %dest]
  %+  expect-eq
    !>  (make-bend:tarball here [%& dest])
  !>  (make-bend-rail:tarball here dest)
::
::  +prefix tests
::
++  test-prefix-common
  ::  Paths with common prefix
  %+  expect-eq
    !>  /a/b
  !>  (prefix:tarball /a/b/c /a/b/d)
::
++  test-prefix-none
  ::  No common prefix
  %+  expect-eq
    !>  /
  !>  (prefix:tarball /a/b /c/d)
::
++  test-prefix-one-empty
  ::  One path is empty
  %+  expect-eq
    !>  /
  !>  (prefix:tarball / /a/b)
::
++  test-prefix-both-empty
  ::  Both paths empty
  %+  expect-eq
    !>  /
  !>  (prefix:tarball / /)
::
++  test-prefix-full-match
  ::  One path is prefix of other
  %+  expect-eq
    !>  /a/b
  !>  (prefix:tarball /a/b /a/b/c/d)
::
++  test-prefix-identical
  ::  Identical paths
  %+  expect-eq
    !>  /a/b/c
  !>  (prefix:tarball /a/b/c /a/b/c)
::
::  +decap tests
::
++  test-decap-valid-prefix
  ::  Remove valid prefix
  %+  expect-eq
    !>  `/c/d
  !>  (decap:tarball /a/b /a/b/c/d)
::
++  test-decap-no-prefix
  ::  Prefix doesn't match
  %+  expect-eq
    !>  ~
  !>  (decap:tarball /a/b /c/d/e)
::
++  test-decap-empty-prefix
  ::  Empty prefix returns full path
  %+  expect-eq
    !>  `/a/b/c
  !>  (decap:tarball / /a/b/c)
::
++  test-decap-exact-match
  ::  Prefix equals path
  %+  expect-eq
    !>  `/
  !>  (decap:tarball /a/b /a/b)
::
++  test-decap-prefix-longer
  ::  Prefix longer than path
  %+  expect-eq
    !>  ~
  !>  (decap:tarball /a/b/c /a/b)
::
::  +validate-names tests
::
++  test-validate-names-empty-ball
  ::  Empty ball is valid
  %-  expect
  !>  ~(validate-names ba:tarball *ball:tarball)
::
++  test-validate-names-files-only
  ::  Ball with only files is valid
  =/  b=ball:tarball  *ball:tarball
  =/  c=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =.  b  (~(put ba:tarball b) [/ %foo] c)
  =.  b  (~(put ba:tarball b) [/ %bar] c)
  %-  expect
  !>  ~(validate-names ba:tarball b)
::
++  test-validate-names-dirs-only
  ::  Ball with only directories is valid
  =/  b=ball:tarball  *ball:tarball
  =/  c=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =.  b  (~(put ba:tarball b) [/foo %test] c)
  =.  b  (~(put ba:tarball b) [/bar %test] c)
  %-  expect
  !>  ~(validate-names ba:tarball b)
::
++  test-validate-names-no-collision
  ::  Ball with files and dirs, no name collision
  =/  b=ball:tarball  *ball:tarball
  =/  c=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =.  b  (~(put ba:tarball b) [/ %file1] c)
  =.  b  (~(put ba:tarball b) [/dir1 %nested] c)
  %-  expect
  !>  ~(validate-names ba:tarball b)
::
++  test-validate-names-nested-no-collision
  ::  Deeply nested structure with no collisions
  =/  b=ball:tarball  *ball:tarball
  =/  c=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  =.  b  (~(put ba:tarball b) [/a/b/c %file] c)
  =.  b  (~(put ba:tarball b) [/a/b %other] c)
  =.  b  (~(put ba:tarball b) [/a %root] c)
  %-  expect
  !>  ~(validate-names ba:tarball b)
::
++  test-put-file-collides-with-dir
  ::  Putting a file with same name as existing dir should crash
  =/  b=ball:tarball  *ball:tarball
  =/  c=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  ::  First create a directory named 'foo' by putting a file inside it
  =.  b  (~(put ba:tarball b) [/foo %nested] c)
  ::  Now try to put a file named 'foo' at root - should crash
  %-  expect-fail
  |.((~(put ba:tarball b) [/ %foo] c))
::
++  test-put-creates-dir-collides-with-file
  ::  Creating dir path that collides with existing file should crash
  =/  b=ball:tarball  *ball:tarball
  =/  c=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  ::  First create a file named 'foo' at root
  =.  b  (~(put ba:tarball b) [/ %foo] c)
  ::  Now try to create /foo/bar - 'foo' would need to be a dir, should crash
  %-  expect-fail
  |.((~(put ba:tarball b) [/foo %bar] c))
::
++  test-mkd-collides-with-file
  ::  Creating directory with same name as existing file should crash
  =/  b=ball:tarball  *ball:tarball
  =/  c=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  ::  First create a file named 'foo' at root
  =.  b  (~(put ba:tarball b) [/ %foo] c)
  ::  Now try to mkdir /foo - should crash
  %-  expect-fail
  |.((~(mkd ba:tarball b) [/foo ~ ~]))
::
++  test-nested-put-collision
  ::  Collision deeper in the tree
  =/  b=ball:tarball  *ball:tarball
  =/  c=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  ::  Create /a/b/foo as a directory
  =.  b  (~(put ba:tarball b) [/a/b/foo %nested] c)
  ::  Try to create /a/b/foo as a file - should crash
  %-  expect-fail
  |.((~(put ba:tarball b) [/a/b %foo] c))
::
++  test-valid-sibling-names
  ::  File and dir can have same name at different levels
  =/  b=ball:tarball  *ball:tarball
  =/  c=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  ::  'foo' as file at root
  =.  b  (~(put ba:tarball b) [/ %foo] c)
  ::  'foo' as directory under /bar (different parent)
  =.  b  (~(put ba:tarball b) [/bar/foo %nested] c)
  %-  expect
  !>  ~(validate-names ba:tarball b)
::
++  test-pub-rejects-invalid-subtree
  ::  pub should reject a subtree with internal name collisions
  =/  b=ball:tarball  *ball:tarball
  =/  c=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  ::  Manually construct a bad ball with 'foo' as both file and dir
  ::  (bypassing put which would crash)
  =/  bad-ball=ball:tarball
    :_  (my [%foo *ball:tarball] ~)  :: dir has 'foo'
    `[~ ~ (my [%foo c] ~)]           :: fil.contents has 'foo'
  ::  pub should crash when given this bad ball
  %-  expect-fail
  |.((~(pub ba:tarball b) / bad-ball))
::
++  test-pub-rejects-nested-invalid-subtree
  ::  pub should reject subtree with collision deep in tree
  =/  b=ball:tarball  *ball:tarball
  =/  c=content:tarball  [~ [%mime !>([/text/plain [5 'hello']])]]
  ::  Create a valid outer ball with an invalid nested ball
  =/  bad-nested=ball:tarball
    :_  (my [%bar *ball:tarball] ~)  :: dir has 'bar'
    `[~ ~ (my [%bar c] ~)]           :: fil.contents has 'bar'
  =/  bad-ball=ball:tarball
    :_  (my [%child bad-nested] ~)   :: nest bad ball under /child
    `[~ ~ ~]                         :: root is valid
  %-  expect-fail
  |.((~(pub ba:tarball b) / bad-ball))
::
::  cord-to-road tests
::
++  test-cord-to-road-absolute-file
  %+  expect-eq
    !>  `road:tarball`[%& %& /foo/bar %baz]
  !>  (cord-to-road:tarball '/foo/bar/baz')
::
++  test-cord-to-road-absolute-root-file
  %+  expect-eq
    !>  `road:tarball`[%& %& / %foo]
  !>  (cord-to-road:tarball '/foo')
::
++  test-cord-to-road-absolute-dir
  %+  expect-eq
    !>  `road:tarball`[%& %| /foo/bar]
  !>  (cord-to-road:tarball '/foo/bar/')
::
++  test-cord-to-road-empty
  %+  expect-eq
    !>  `road:tarball`[%& %| /]
  !>  (cord-to-road:tarball '')
::
++  test-cord-to-road-relative-dot-file
  %+  expect-eq
    !>  `road:tarball`[%| 0 %& / %'foo.txt']
  !>  (cord-to-road:tarball './foo.txt')
::
++  test-cord-to-road-relative-dotdot-file
  %+  expect-eq
    !>  `road:tarball`[%| 1 %& / %bar]
  !>  (cord-to-road:tarball '../bar')
::
++  test-cord-to-road-relative-dotdot-dotdot
  %+  expect-eq
    !>  `road:tarball`[%| 2 %& /baz %qux]
  !>  (cord-to-road:tarball '../../baz/qux')
::
++  test-cord-to-road-relative-dotdot-only
  %+  expect-eq
    !>  `road:tarball`[%| 1 %| /]
  !>  (cord-to-road:tarball '..')
::
++  test-cord-to-road-relative-bare
  %+  expect-eq
    !>  `road:tarball`[%| 0 %& / %'config.json']
  !>  (cord-to-road:tarball 'config.json')
::
++  test-cord-to-road-relative-dir
  %+  expect-eq
    !>  `road:tarball`[%| 0 %| /foo/bar]
  !>  (cord-to-road:tarball './foo/bar/')
::
::  road-to-cord tests
::
++  test-road-to-cord-absolute-file
  %+  expect-eq
    !>  '/foo/bar/baz'
  !>  (road-to-cord:tarball [%& %& /foo/bar %baz])
::
++  test-road-to-cord-absolute-dir
  %+  expect-eq
    !>  '/foo/bar'
  !>  (road-to-cord:tarball [%& %| /foo/bar])
::
++  test-road-to-cord-relative-dot-file
  %+  expect-eq
    !>  './foo'
  !>  (road-to-cord:tarball [%| 0 %& / %foo])
::
++  test-road-to-cord-relative-dotdot
  %+  expect-eq
    !>  '../bar'
  !>  (road-to-cord:tarball [%| 1 %& / %bar])
::
++  test-road-to-cord-roundtrip-absolute
  =/  txt=@t  '/one/two/three'
  %+  expect-eq
    !>  txt
  !>  (road-to-cord:tarball (cord-to-road:tarball txt))
::
++  test-road-to-cord-roundtrip-relative
  =/  txt=@t  '../../foo/bar'
  %+  expect-eq
    !>  txt
  !>  (road-to-cord:tarball (cord-to-road:tarball txt))
::
--
