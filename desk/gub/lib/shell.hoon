::  /lib/shell: client-side helpers for the shell permission system.
::
::  A nexus talks to the shell through grant.json: the shell writes it
::  into the app's own root on approval (its resolved grants, its
::  @alias -> path map, and `here`, the app's absolute address). These
::  arms read that file so an app can know what it holds without a
::  privileged walk to root (get-here-abs, which needs peek /).
::
::  Import it as `shell`, so the call sites read locus:shell and
::  locate:shell:
::
::    /<  shell  /lib/shell.hoon
::
|%
::  +locus: the app's own absolute path, read from grant.json.
::
::  Replaces get-here-abs for the common case of "I need my own
::  address to hand the client a URL." No %here walk -> no peek /.
::  Returns ~ if grant.json is missing (app not yet approved).
::
++  locus
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  gv=view:nexus  bind:m  (peek:io (nex-road:io rail [%& ~ %'grant.json']) ~)
  ?.  ?=([%file *] gv)  (pure:m ~)
  =/  jon=(unit json)  (mole |.(!<(json (need-vase:tarball sang.gv))))
  ?~  jon  (pure:m ~)
  ?.  ?=([%o *] u.jon)  (pure:m ~)
  =/  h=(unit json)  (~(get by p.u.jon) 'here')
  ?~  h  (pure:m ~)
  ?.  ?=([%s *] u.h)  (pure:m ~)
  (pure:m `p.u.h)
::  +locate: where a nexus-relative rail actually sits. Reads the app's
::  locus from grant.json and welds the caller's own relative rail onto
::  it, so [/accounts %'ledger.json'] comes back as
::  [/apps/<name>/accounts %'ledger.json'].
::
::  Needed wherever a road must be absolute -- a usergroup's reaches, a
::  URL handed to the browser -- while everything else an app does stays
::  relative. A granted app self-addresses with NO peek /: it reads
::  where the shell already told it it is, instead of climbing to root.
::
::  No grant.json means the app is not approved (or its grant was
::  dropped): the fiber fails saying so and waits for the restart the
::  grant brings. There is no fallback to the privileged walk; that walk
::  (get-here-abs) is deprecated and a sandboxed app cannot make it.
::
++  locate
  |=  rel=rail:tarball
  =/  m  (fiber:fiber:nexus ,rail:tarball)
  ^-  form:m
  ;<  base=(unit @t)  bind:m  (locus rel)
  ?~  base
    |=  input:fiber:nexus
    :+  ~  q.state
    [%fail ~[leaf+"no grant.json: this app is not approved on Permits, or its grant was dropped; it restarts when granted"]]
  (pure:m [(weld `path`(stab u.base) path.rel) name.rel])
--
