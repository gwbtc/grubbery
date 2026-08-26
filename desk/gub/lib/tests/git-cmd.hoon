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
::  garbage rejects
++  test-reject-empty  |.((chk ~ ''))
++  test-reject-bogus  |.((chk ~ 'frobnicate the widget'))
++  test-reject-partial  |.((chk ~ 'checkout'))
--
