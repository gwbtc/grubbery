::  -grubbery!poke [/server %main %server-action [%reset ~]]
::
/-  spider
/+  *strandio, nexus
^-  thread:spider
|=  arg=vase
=/  m  (strand ,vase)
^-  form:m
=+  !<([~ dest-path=path dest-name=@tas =mark =noun] arg)
=/  =action:nexus
  [[/thread-poke %& dest-path dest-name] %poke [mark noun]]
;<  ~  bind:m  (poke-our %grubbery grubbery-action+!>(action))
~&  >  "poked {<dest-path>}/{(trip dest-name)} with %{(trip mark)}"
(pure:m !>(~))
