::  /lib/code-src: which /code file is the code for a blot or neck,
::  answered from the namespace, not from the build.
::
::  Governance is the walk in code-candidates:tarball — the path's
::  sibling /code, then each ancestor's, ending at root /code. The
::  kernel resolves compiled artifacts by that walk; since every
::  source file gets an artifact whether it compiled or crashed, the
::  FIRST candidate that has the source file is exactly the one whose
::  artifact governs. So the answer is a namespace fact: no dart, just
::  peeks. A code namespace is a directory named code whose neck is
::  /code.
::
|%
::  +is-code-ns: does this directory exist as a code namespace?
::
++  is-code-ns
  |=  =fold:tarball
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek-shallow:io [%& %| fold] ~)
  %-  pure:m
  ?&  ?=([%ball *] v)
      ?=(^ fil.ball.v)
      =(`[/ %code] neck.u.fil.ball.v)
  ==
::  +source-file: the source rail for an address within a code
::  namespace: /mar/<path>/<name>.hoon or /nex/<path>/<name>.hoon.
::
++  source-file
  |=  [ns=fold:tarball kind=?(%mar %nex) addr=rail:tarball]
  ^-  rail:tarball
  [(weld ns (weld /[kind] path.addr)) (cat 3 name.addr '.hoon')]
::  +resolve: from directory `from`, the source rail of the marc (%mar)
::  or nexus (%nex) at `addr` — a blot or neck rail like [/ %json] or
::  [/wallet %account]. ~ when no candidate has it.
::
++  resolve
  |=  [from=path kind=?(%mar %nex) addr=rail:tarball]
  =/  m  (fiber:fiber:nexus ,(unit rail:tarball))
  ^-  form:m
  ;<  got=(map rail:tarball (unit rail:tarball))  bind:m
    (resolve-many from kind ~[addr])
  (pure:m (fall (~(get by got) addr) ~))
::  +resolve-many: +resolve for many addresses from one place. The
::  candidates are the same for every address, so each is confirmed as
::  a code namespace once; each address then stops at its first hit.
::
++  resolve-many
  |=  [from=path kind=?(%mar %nex) addrs=(list rail:tarball)]
  =/  m  (fiber:fiber:nexus ,(map rail:tarball (unit rail:tarball)))
  ^-  form:m
  ::  the candidates that are actually code namespaces, in order
  ;<  cands=(list fold:tarball)  bind:m
    =/  m  (fiber:fiber:nexus ,(list fold:tarball))
    =/  all=(list fold:tarball)  (code-candidates:tarball from)
    =|  acc=(list fold:tarball)
    |-  ^-  form:m
    ?~  all  (pure:m (flop acc))
    ;<  ok=?  bind:m  (is-code-ns i.all)
    $(all t.all, acc ?:(ok [i.all acc] acc))
  =|  out=(map rail:tarball (unit rail:tarball))
  |-  ^-  form:m
  ?~  addrs  (pure:m out)
  ;<  hit=(unit rail:tarball)  bind:m
    =/  m  (fiber:fiber:nexus ,(unit rail:tarball))
    =/  cs  cands
    |-  ^-  form:m
    ?~  cs  (pure:m ~)
    =/  r=rail:tarball  (source-file i.cs kind i.addrs)
    ;<  has=?  bind:m  (peek-exists:io [%& %& r])
    ?:  has  (pure:m `r)
    $(cs t.cs)
  $(addrs t.addrs, out (~(put by out) i.addrs hit))
::  +owner: the code namespace a file is compiled BY — the nearest
::  enclosing directory (its own included) that is a code namespace.
::  ~ for a file outside any. This is containment, not governance:
::  a file at ns/mar/foo.hoon is owned by ns.
::
++  owner
  |=  file=rail:tarball
  =/  m  (fiber:fiber:nexus ,(unit fold:tarball))
  ^-  form:m
  =/  dir=path  path.file
  |-  ^-  form:m
  ?~  dir  (pure:m ~)
  ;<  ok=?  bind:m
    ?.  =(%code (rear dir))  (pure:(fiber:fiber:nexus ,?) %.n)
    (is-code-ns dir)
  ?:  ok  (pure:m `dir)
  $(dir (snip `path`dir))
::  +url: the explorer URL of a source rail.
::
++  url
  |=  r=rail:tarball
  ^-  tape
  "/grubbery/ball{(trip (spat (snoc path.r name.r)))}"
--
