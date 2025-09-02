/-  spider, g=grubbery
/+  *strandio
=,  strand=strand:spider
^-  thread:spider
|=  arg=vase
=/  m  (strand ,vase)
^-  form:m
=+  !<([~ here=path =stud:g =noun] arg)
;<  =bowl:spider  bind:m  get-bowl
=/  =wire  /[tid.bowl]
=/  =action:protocol:g  [[wire here] %poke stud noun]
=/  =path  (weld /poke/(scot %p our.bowl) wire)
;<  ~  bind:m  (watch-our /poke %grubbery path)
;<  ~  bind:m  (poke-our %grubbery grub-action+!>(action))
;<  =cage  bind:m  (take-fact /poke)
?.  ?=(%grub-sign-base -.cage)
  (strand-fail %wrong-subscription-mark ~)
=+  !<(=sign:base:g q.cage)
?.  ?=(%pack -.sign)
  (strand-fail %wrong-sign-base ~)
?:  ?=(%| -.p.sign)
  (strand-fail %pack-fail p.p.sign)
~&  >  "Poke success!"
~&  >  "Poke id: {(trip p.p.sign)}"
(pure:m !>(p.p.sign))