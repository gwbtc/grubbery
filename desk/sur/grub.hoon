::  grub: the thin agent-facing surface of grubbery.
::
::  For gall agents (local or remote) talking to a grubbery: plain
::  types only — paths, marks as @tas, raw nouns. No tarball/nexus
::  types cross this boundary; readers get materialized content, and
::  content validation is the reader's job (mark labels are advisory
::  here, exactly like the remote-scry farm).
::
::  Idiom: subscribe /client/[chan] first, then poke %grub-cmd
::  requests tagged with that chan; every outcome arrives as a
::  %grub-fact on the subscription. chan is a CHANNEL id, not a
::  request id: it names your return path. Facts fan out to every
::  subscriber of the channel, and two in-flight requests of the same
::  kind on one channel cannot be told apart — pick a unique chan per
::  conversation (entropy-derived), or one per request when you need
::  strict pairing. Identity is the poking SHIP (gall does not name
::  the poking agent): a caller acts as
::  /sys/ames/ships/[ship]/ship.sig, your own ship included — local
::  privilege is just the absence of a weir on your own path.
::
::  mark=@tas flattens grubbery blots: a blot may carry a path prefix
::  (nested necks); this surface expresses only the bare name.
::
|%
::  +gnode: a materialized view of a namespace node
::
+$  gnode
  $%  [%file mark=@tas =noun]         ::  a grub's content
      [%tree kids=(map @ta gnode)]    ::  a directory, deep
      [%ls kids=(list @ta)]           ::  a directory, names only
  ==
::  +op: one request. path/name keep the file/dir distinction: a
::  file is always [path name], a directory is a bare path.
::
+$  op
  $%  [%poke =path name=@ta mark=@tas =noun]              ::  poke a grub
      [%peek =path name=(unit @ta) deep=?]                ::  read file or dir
      [%make-file =path name=@ta mark=@tas =noun force=?] ::  create a grub
      [%make-dir =path force=?]                           ::  create a directory
      [%cull =path name=(unit @ta)]                       ::  delete file or dir
      [%keep =path name=(unit @ta)]   ::  subscribe: %news on changes
      [%drop =path name=(unit @ta)]   ::  unsubscribe
  ==
+$  cmd  [chan=@ta =op]               ::  poked as %grub-cmd
::  +res: one outcome, given as %grub-fact on /client/[id]
::
+$  res
  $%  [%ack err=(unit tang)]          ::  poke/make/cull/keep/drop outcome
      [%got =gnode]                   ::  peek result
      [%miss ~]                       ::  peek: nothing there
      [%news =path name=(unit @ta)]   ::  a kept target (or below it) changed; re-peek for content
  ==
+$  fact  [chan=@ta =res]
--
