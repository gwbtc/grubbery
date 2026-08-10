::  /lib/shell: client-side helpers for the shell permission system.
::
::  A nexus talks to the shell through grant.json: the shell writes it
::  into the app's own root on approval (its resolved grants, its
::  @alias -> path map, and `here`, the app's absolute address). These
::  arms read that file so an app can know what it holds without a
::  privileged walk to root (get-here-abs, which needs peek /).
::
|%
::  +here: the app's own absolute path, read from grant.json.
::
::  Replaces get-here-abs for the common case of "I need my own
::  address to hand the client a URL." No %here walk -> no peek /.
::  Returns ~ if grant.json is missing (app not yet approved).
::
++  here
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
::  +here-abs: this fiber's absolute rail, without a %here walk. Reads the
::  app root from grant.json (here) and welds the caller's own nexus-
::  relative rail onto it. Falls back to the trustless %here walk only when
::  there's no grant yet — an unapproved app runs unrestricted, so the walk
::  succeeds. Lets a granted app register / self-address with NO peek /: it
::  reads where the shell already told it it is, instead of climbing to root.
::
++  here-abs
  |=  rel=rail:tarball
  =/  m  (fiber:fiber:nexus ,rail:tarball)
  ^-  form:m
  ;<  base=(unit @t)  bind:m  (here rel)
  ?~  base  get-here-abs:io
  (pure:m [(weld `path`(stab u.base) path.rel) name.rel])
--
