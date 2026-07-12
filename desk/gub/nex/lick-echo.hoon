::  lick-echo nexus: local IPC demo over the lick vane.
::
::  Spins a unix socket at <pier>/.urb/dev/grubbery/grubbery/echo and echoes
::  every inbound [mark noun] message back to the connected client. Talk
::  to it with any newt+jam client (see the man page for a worked example).
::
/&  man  ../man/lick-echo/readme.md
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  ball
        :~  (ver-row:loader 0)
            [%fall %& [/ %'echo.sig'] [[/ %sig] ~]]
            [%over %& [/man %'readme.md'] [[/ %mime] man]]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          [~ %'echo.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%lick-echo: failed")
        ;<  ~  bind:m  (lick-spin:io port)
        ::  keep the inbound grub (initial bond wave consumed here); each
        ::  message bumps seq -> a fresh wave. Peek-first + seq dedup: a
        ::  message that lands before the keep is echoed on entry, and a
        ::  burst coalesces to the newest message without double-echoing.
        ;<  *  bind:m  (keep:io /in [%& %& (weld /sys/lick port) %in] ~)
        =|  last=(unit @ud)
        |-
        ;<  =seen:nexus  bind:m  (peek:io [%& %& (weld /sys/lick port) %in] ~)
        ?:  ?=([%& %file *] seen)
          =/  msg  !<([seq=@ud mark=@tas noun=*] (need-vase:tarball sang.p.seen))
          ?.  =(`seq.msg last)
            ;<  ~  bind:m  (lick-spit:io port mark.msg noun.msg)
            $(last `seq.msg)
          ;<  *  bind:m  (take-news:io /in)
          $
        ;<  *  bind:m  (take-news:io /in)
        $
      ==
    --
|%
++  port  ^-  path  /grubbery/echo
--
