::  grub: client library for talking to a grubbery from a gall agent.
::
::  Idiom: (watch ship chan) once, then (send ship chan op) as many times
::  as you like; every outcome arrives on the subscription as a
::  %grub-fact — pull it out of on-agent with +take-fact.
::
::  Vendorable: a consumer desk needs this file, sur/grub.hoon, and
::  mar/grub-{cmd,fact}.hoon. Nothing else.
::
/-  grub
|%
++  watch
  |=  [=ship chan=@ta]
  ^-  card:agent:gall
  [%pass /grub/[chan] %agent [ship %grubbery] %watch /client/[chan]]
::
++  leave
  |=  [=ship chan=@ta]
  ^-  card:agent:gall
  [%pass /grub/[chan] %agent [ship %grubbery] %leave ~]
::
++  send
  |=  [=ship chan=@ta =op:grub]
  ^-  card:agent:gall
  [%pass /grub-cmd/[chan] %agent [ship %grubbery] %poke %grub-cmd !>(`cmd:grub`[chan op])]
::  +take-fact: the fact in an on-agent sign, if it is one
::
++  take-fact
  |=  =sign:agent:gall
  ^-  (unit fact:grub)
  ?.  ?=(%fact -.sign)  ~
  ?.  =(%grub-fact p.cage.sign)  ~
  `!<(fact:grub q.cage.sign)
--
