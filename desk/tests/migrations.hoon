/+  *test, migrations, nexus, tarball
|%
::  ==========================================
::  narrow -> wide pool migration tests
::
::  The narrow types stand in for state saved before the widening of
::  the load union. The queues are typed at today's take (covariant, so
::  pre-widening values nest as they are). Only the process slot is a
::  raw noun, shed on crossing. A vase whose queues do NOT fit today's
::  types fails the narrow !< too, and gall rejects the upgrade
::  atomically. There is deliberately no element-wise shed path.
::  ==========================================
::
::  a representative queued take: a give-back address plus a %veto
::  pend carrying a dart whose load uses a stem the narrow union had
::
++  example-take
  ^-  take:fiber:nexus
  :-  `[[/a/b %src] /give-wire]
  `[%veto %node /w [%& %& /a %b] %poke [/ %noun] 42]
::
++  example-take-2
  ^-  take:fiber:nexus
  [~ `[%pack /nonce ~]]
::
++  example-queue
  ^-  (qeu take:fiber:nexus)
  =/  q  *(qeu take:fiber:nexus)
  =.  q  (~(put to q) example-take)
  (~(put to q) example-take-2)
::
++  banged
  ^-  tang
  ~[leaf+"saving for reload"]
::
++  test-narrow-banged-proc-crosses-whole
  ::  a banged process and its queues cross noun-for-noun
  =/  old=proc-narrow:migrations
    [|+banged example-queue example-queue]
  =/  new=proc:fiber:nexus
    (proc-narrow-to-proc:migrations [/a %grub] old)
  ;:  weld
    (expect-eq !>(`*`old) !>(`*`new))
    (expect-eq !>(example-queue) !>(next.new))
    (expect-eq !>(`(each process:fiber:nexus tang)`|+banged) !>(process.new))
  ==
::
++  test-narrow-live-proc-is-shed
  ::  a %& process (a live gate) cannot cross. It is banged, and its
  ::  queues are kept.
  =/  gat=*  |=(* ~)
  =/  old=proc-narrow:migrations
    [&+gat example-queue *(qeu take:fiber:nexus)]
  =/  new=proc:fiber:nexus
    (proc-narrow-to-proc:migrations [/a %grub] old)
  ;:  weld
    (expect !>(?=(%| -.process.new)))
    (expect-eq !>(example-queue) !>(next.new))
    (expect-eq !>(*(qeu take:fiber:nexus)) !>(skip.new))
  ==
::
++  test-narrow-nested-pool-crosses
  ::  the pool is an axal. A pipe nested two directories deep must cross
  ::  through +pool-narrow-to-pool's recursive branch, noun-identically,
  ::  with the here path threaded. The here path is visible only via
  ::  slogs, and a wrong here would mis-key nothing, so the assertion
  ::  is the noun.
  =/  pip=pipe-narrow:migrations
    :-  bang=`~[leaf+"nexus bang"]
    (~(put by *(map @ta proc-narrow:migrations)) %grub [|+banged example-queue *(qeu take:fiber:nexus)])
  =/  deep=pool-narrow:migrations
    :-  ~
    %+  ~(put by *(map @ta pool-narrow:migrations))  %sys
    :-  ~
    (~(put by *(map @ta pool-narrow:migrations)) %behn [`pip ~])
  =/  new=pool:nexus  (pool-narrow-to-pool:migrations deep)
  (expect-eq !>(`*`deep) !>(`*`new))
::
++  test-narrow-state-passthrough
  ::  fields other than pool cross untouched, born (the unrecoverable
  ::  truth field) explicitly among them. The pool is remolded
  ::  noun-identically when everything in it can cross.
  =/  sil=silo:nexus
    :_  ~
    (~(put by *(map nobe:nexus [refs=@ud noun=*])) 0v17 [refs=2 noun='truth'])
  =/  pip=pipe-narrow:migrations
    :-  bang=`~[leaf+"nexus bang"]
    (~(put by *(map @ta proc-narrow:migrations)) %grub [|+banged example-queue *(qeu take:fiber:nexus)])
  =/  old=state-0-narrow:migrations
    =/  bunt  *state-0-narrow:migrations
    %=  bunt
      born  *born:nexus
      silo  sil
      pool  [`pip ~]
      last  [now=~2026.8.14 eny=`@uvJ`0v42]
    ==
  =/  new=state-0:migrations
    (state-0-narrow-to-0:migrations old)
  ;:  weld
    (expect-eq !>(born.old) !>(born.new))
    (expect-eq !>(silo.old) !>(silo.new))
    (expect-eq !>(last.old) !>(last.new))
    (expect-eq !>(`*`pool.old) !>(`*`pool.new))
  ==
--
