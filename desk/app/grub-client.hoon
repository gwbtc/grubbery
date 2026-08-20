::  %grub-client: test agent for grubbery's thin agent surface.
::
::  VENDORING: to talk to grubbery from your own clay desk, copy
::  exactly four files out of the grubbery desk — nothing else:
::
::    sur/grub.hoon       the shared types (cmd/op/fact/res/gnode)
::    lib/grub.hoon       the client helpers (watch/leave/send/take-fact)
::    mar/grub-cmd.hoon   poke mark (needed for cross-desk conversion)
::    mar/grub-fact.hoon  fact mark (ditto)
::
::  Then do what this agent does: /-  grub, /+  lg=grub, emit
::  (watch:lg ship chan) once, (send:lg ship chan op) per request,
::  and pull outcomes out of on-agent with take-fact:lg. No grubbery
::  internals (nexus/tarball/fiber types) are needed or wanted.
::
::  Drive from dojo:
::    :grub-client &noun [%watch ~nec 'a']
::    :grub-client &noun [%send ~nec 'a' %peek /docs ~ |]
::    :grub-client &noun [%send ~nec 'a' %make-file /docs 'note.txt' %txt ~['hi'] |]
::    :grub-client &noun [%send ~nec 'a' %poke /docs/test 'inbox.sig' %txt ~['yo']]
::    :grub-client &noun [%send ~nec 'a' %cull /docs `'note.txt']
::  Facts print to the dojo.
::
/-  grub
/+  default-agent, lg=grub
|%
+$  order
  $%  [%watch =ship chan=@ta]
      [%leave =ship chan=@ta]
      [%send =ship chan=@ta =op:grub]
  ==
--
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %.n) bowl)
++  on-init  `this
++  on-save  !>(~)
++  on-load  |=(* `this)
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card:agent:gall _this)
  ?.  =(%noun mark)  (on-poke:def mark vase)
  =/  ord  !<(order vase)
  ?-  -.ord
    %watch  [~[(watch:lg [ship chan]:ord)] this]
    %leave  [~[(leave:lg [ship chan]:ord)] this]
    %send   [~[(send:lg [ship chan op]:ord)] this]
  ==
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card:agent:gall _this)
  ?~  fac=(take-fact:lg sign)
    ?:  ?=(%kick -.sign)
      ~&  >>>  [%grub-client %kicked wire]
      [~ this]
    ?:  ?&(?=(%poke-ack -.sign) ?=(^ p.sign))
      ~&  >>>  [%grub-client %poke-nacked wire]
      [~ this]
    ?:  ?&(?=(%watch-ack -.sign) ?=(^ p.sign))
      ~&  >>>  [%grub-client %watch-nacked wire]
      [~ this]
    [~ this]
  ~&  >  [%grub-fact u.fac]
  [~ this]
++  on-watch  on-watch:def
++  on-leave  on-leave:def
++  on-peek   on-peek:def
++  on-arvo   on-arvo:def
++  on-fail   on-fail:def
--
