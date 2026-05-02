::  bowl oracle nexus: poke-response services for bowl fields
::
::  Mounted at /sys/bowl/. Each sig file is an oracle — poke it
::  and it pokes back with the corresponding bowl field.
::
::  Files:
::    now.sig  — current @da timestamp
::    our.sig  — ship identity @p
::    eny.sig  — entropy @uvJ
::    here.sig — this process's location (rail)
::
=<  ^-  nexus:nexus
    |%
++  on-load
  |=  [=sand:nexus =gain:nexus =ball:tarball]
  ^-  [sand:nexus gain:nexus ball:tarball]
  =/  =ver:loader  (get-ver:loader ball)
  ?+  ver  !!
      ?(~ [~ %0])
    %+  spin:loader  [sand gain ball]
    :~  (ver-row:loader 0)
        [%fall %& [/ %'now.sig'] %.n [~ [/ %sig] !>(~)]]
        [%fall %& [/ %'our.sig'] %.n [~ [/ %sig] !>(~)]]
        [%fall %& [/ %'eny.sig'] %.n [~ [/ %sig] !>(~)]]
        [%fall %& [/ %'here.sig'] %.n [~ [/ %sig] !>(~)]]
    ==
  ==
::
++  on-manu
  |=  =mana:nexus
  ^-  @t
  ?-  -.mana
    %&  'Bowl oracle. Poke now/our/eny/here.sig to get the corresponding bowl field.'
    %|  'Bowl oracle sig file. Poke to get the value.'
  ==
::
++  on-file
  |=  [=rail:tarball =mark]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
    ::
      [~ %'now.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%bowl now: failed")
    |-
    ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
    ;<  now=@da  bind:m  get-time:io
    ;<  ~  bind:m  (poke:io (from-to-road from) [/ %da] !>(now))
    $
    ::
      [~ %'our.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%bowl our: failed")
    |-
    ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
    ;<  our=@p  bind:m  get-our:io
    ;<  ~  bind:m  (poke:io (from-to-road from) [/ %p] !>(our))
    $
    ::
      [~ %'eny.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%bowl eny: failed")
    |-
    ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
    ;<  eny=@uvJ  bind:m  get-entropy:io
    ;<  ~  bind:m  (poke:io (from-to-road from) [/ %uv] !>(eny))
    $
    ::
      [~ %'here.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%bowl here: failed")
    |-
    ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
    ::  resolve caller's location from the return address
    ;<  here=rail:tarball  bind:m  get-here:io
    =/  from-road=road:tarball  (from-to-road from)
    =/  caller-lane=(unit lane:tarball)
      (lane-from-road:tarball [%& here] from-road)
    =/  caller-here=rail:tarball
      ?~  caller-lane  here
      ?>  ?=(%& -.u.caller-lane)
      p.u.caller-lane
    ;<  ~  bind:m  (poke:io from-road [/ %bowl-here] !>(caller-here))
    $
  ==
    --
::  convert fiber from (each bend:fiber prov) to tarball road
::  fiber bend = [steps=@ud =rail], tarball bend = [steps=@ud =lane]
::
|%
++  from-to-road
  |=  =from:fiber:nexus
  ^-  road:tarball
  ?>  ?=(%& -.from)
  |+[p.p.from &+q.p.from]
--
