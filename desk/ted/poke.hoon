::  -grubbery!poke [/'server.server' %'main.server-state' %server-action [%reset ~]]
::
/-  spider
/+  *strandio, nexus
^-  thread:spider
|=  arg=vase
=/  m  (strand ,vase)
^-  form:m
=+  !<([~ dest-path=path dest-name=@tas =mark =noun] arg)
=/  req=load:remote:nexus
  [[/thread-poke %& dest-path dest-name] %poke [[/ mark] noun]]
;<  ~  bind:m  (poke-our %grubbery grubbery-load+!>(req))
~&  >  "poked {<dest-path>}/{(trip dest-name)} with %{(trip mark)}"
(pure:m !>(~))
