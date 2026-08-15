/+  *test, migrations, nexus, tarball
|%
::  ==========================================
::  narrow -> wide pool migration tests
::
::  The narrow types stand in for state saved before the
::  %grow/%tomb/%keen widening of the load union. Narrow load values
::  are a strict subset of wide ones, so a queued take built from
::  pre-widening stems must cross noun-identically; a live process
::  gate and a garbage queue entry must be shed.
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
    [|+banged `(qeu *)`example-queue `(qeu *)`example-queue]
  =/  new=proc:fiber:nexus
    (proc-narrow-to-proc:migrations [/a %grub] old)
  ;:  weld
    (expect-eq !>(`*`old) !>(`*`new))
    (expect-eq !>(example-queue) !>(next.new))
    (expect-eq !>(`(each process:fiber:nexus tang)`|+banged) !>(process.new))
  ==
::
++  test-narrow-live-proc-is-shed
  ::  a %& process (a live gate) cannot cross: banged, queues kept
  =/  gat=*  |=(* ~)
  =/  old=proc-narrow:migrations
    [&+gat `(qeu *)`example-queue *(qeu *)]
  =/  new=proc:fiber:nexus
    (proc-narrow-to-proc:migrations [/a %grub] old)
  ;:  weld
    (expect !>(?=(%| -.process.new)))
    (expect-eq !>(example-queue) !>(next.new))
    (expect-eq !>(*(qeu take:fiber:nexus)) !>(skip.new))
  ==
::
++  test-narrow-garbage-queue-entry-is-shed
  ::  a queue holding one real take and one alien noun keeps the take
  =/  raw=(qeu *)
    =/  q  *(qeu *)
    =.  q  (~(put to q) `*`example-take)
    (~(put to q) [%wat %ever ~])
  =/  out=(qeu take:fiber:nexus)
    (remold-queue:migrations "/a/grub" "next" raw)
  ;:  weld
    (expect-eq !>(1) !>((lent ~(tap to out))))
    (expect-eq !>(`(unit take:fiber:nexus)`[~ example-take]) !>(~(top to out)))
  ==
::
++  test-narrow-state-passthrough
  ::  fields other than pool cross untouched; the pool is remolded
  ::  noun-identically when everything in it can cross
  =/  sil=silo:nexus
    :_  ~
    (~(put by *(map nobe:nexus [refs=@ud noun=*])) 0v17 [refs=2 noun='truth'])
  =/  pip=pipe-narrow:migrations
    :-  bang=`~[leaf+"nexus bang"]
    (~(put by *(map @ta proc-narrow:migrations)) %grub [|+banged `(qeu *)`example-queue *(qeu *)])
  =/  old=state-0-narrow:migrations
    =/  bunt  *state-0-narrow:migrations
    %=  bunt
      silo  sil
      pool  [`pip ~]
      last  [now=~2026.8.14 eny=`@uvJ`0v42]
    ==
  =/  new=state-0:migrations
    (state-0-narrow-to-0:migrations old)
  ;:  weld
    (expect-eq !>(silo.old) !>(silo.new))
    (expect-eq !>(last.old) !>(last.new))
    (expect-eq !>(`*`pool.old) !>(`*`pool.new))
  ==
--
