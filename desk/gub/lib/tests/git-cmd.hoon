/<  test  /lib/test.hoon
/<  action  /lib/git/action.hoon
::  tests for +parse-command: string -> (unit git-command)
::
%-  run-tests:test
!>
|%
::  +chk: assert a command string parses to the expected command (or ~).
::
++  chk
  |=  [want=(unit git-command:action) in=@t]
  ^-  tang
  (expect-eq:test !>(want) !>((parse-command:action in)))
::
++  test-pull  |.((chk [~ %pull ~] 'pull'))
++  test-stash  |.((chk [~ %stash ~] 'stash'))
++  test-stash-pop  |.((chk [~ %stash-pop ~] 'stash pop'))
++  test-stash-list  |.((chk [~ %stash-list ~] 'stash list'))
::  "stash pop" must NOT be swallowed by the bare "stash" rule
++  test-stash-pop-not-shadowed  |.((chk [~ %stash-pop ~] 'stash    pop'))
::  commit — quoted, bare, and --message forms
++  test-commit-quoted  |.((chk [~ %commit 'hello world'] 'commit -m "hello world"'))
++  test-commit-bare  |.((chk [~ %commit 'hi'] 'commit -m hi'))
++  test-commit-long  |.((chk [~ %commit 'foo'] 'commit --message "foo"'))
++  test-commit-long-eq  |.((chk [~ %commit 'bar'] 'commit --message=bar'))
::  commit — a body: repeated -m joins paragraphs with a blank line (git's
::  convention), and a quoted value may itself span lines
++  test-commit-paragraphs
  |.((chk [~ %commit (crip "subject\0a\0abody")] 'commit -m "subject" -m "body"'))
++  test-commit-three-paragraphs
  |.((chk [~ %commit (crip "a\0a\0ab\0a\0ac")] 'commit -m "a" -m "b" -m c'))
++  test-commit-multiline-quoted
  |.((chk [~ %commit (crip "subject\0a\0abody line")] (crip "commit -m \"subject\0a\0abody line\"")))
::  add — all vs selective
++  test-add-all  |.((chk [~ %add ~] 'add'))
++  test-add-paths  |.((chk [~ %add ~['foo.txt' 'lib/bar.hoon']] 'add foo.txt lib/bar.hoon'))
::  push — current vs named branch
++  test-push-current  |.((chk [~ %push ~] 'push'))
++  test-push-branch  |.((chk [~ %push `'feature'] 'push feature'))
::  checkout / branch / branch -d
++  test-checkout  |.((chk [~ %checkout 'main'] 'checkout main'))
++  test-branch  |.((chk [~ %branch 'dev'] 'branch dev'))
++  test-branch-del  |.((chk [~ %branch-delete 'dev'] 'branch -d dev'))
::  commit — an UNQUOTED multi-word message (the second pass). Git makes you
::  quote this; the strict grammar used to answer it with `unrecognized
::  command`, which is how a real commit went missing: the lane reports
::  accepted, not done, so nothing said the quotes were what it wanted.
++  test-commit-bare-words
  |.((chk [~ %commit 'hello world'] 'commit -m hello world'))
++  test-commit-bare-punctuation
  =/  msg=@t  'itinerary: the trips dir opens bare, like its neighbours'
  |.((chk [~ %commit msg] (cat 3 'commit -m ' msg)))
++  test-commit-bare-long
  |.((chk [~ %commit 'two words'] 'commit --message two words'))
++  test-commit-bare-long-eq
  |.((chk [~ %commit 'two words'] 'commit --message=two words'))
::  trailing whitespace is not part of the message
++  test-commit-bare-trailing-space
  |.((chk [~ %commit 'hello world'] 'commit -m hello world   '))
::  the loose pass must not steal what the strict one already reads: repeated
::  -m is still paragraphs, not one literal string
++  test-commit-paragraphs-still-win
  |.((chk [~ %commit (crip "a\0a\0ab")] 'commit -m "a" -m "b"'))
++  test-commit-quoted-still-wins
  |.((chk [~ %commit 'hello world'] 'commit -m "hello world"'))
::  a quoted message whose text contains a quote still survives the escape
++  test-commit-escaped-quote
  |.((chk [~ %commit (crip "say \"hi\"")] (crip "commit -m \"say \\\"hi\\\"\"")))
::  garbage rejects
++  test-reject-empty  |.((chk ~ ''))
++  test-reject-bogus  |.((chk ~ 'frobnicate the widget'))
++  test-reject-partial  |.((chk ~ 'checkout'))
::  the loose pass is COMMIT only: it must not rescue other verbs
++  test-reject-bogus-verb-with-words  |.((chk ~ 'status please do it'))
++  test-reject-commit-no-message  |.((chk ~ 'commit'))
--
