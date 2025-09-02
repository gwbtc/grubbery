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
;<  pack=cage  bind:m  (take-fact /poke)
?.  ?=(%grub-sign-base -.pack)
  (strand-fail %wrong-subscription-mark ~)
=+  !<(=sign:base:g q.pack)
?.  ?=(%pack -.sign)
  (strand-fail %wrong-sign-base ~)
?:  ?=(%| -.p.sign)
  (strand-fail %pack-fail p.p.sign)
~&  >  "Poke success!"
~&  >  "Poke id: {(trip p.p.sign)}"
|-
;<  poke=cage  bind:m  (take-fact /poke)
?.  ?=(%grub-sign-base -.poke)
  :: might receive perks (%grub-perk)
  $
=+  !<(=sign:base:g q.poke)
:: already got pack; not bumping; not expecting any bump-acks
?.  ?=(%poke -.sign)
  (strand-fail %wrong-sign-base ~)
?^  err.sign
  (strand-fail %poke-fail u.err.sign)
~&  >  "Poke completed!"
(pure:m !>(~))
