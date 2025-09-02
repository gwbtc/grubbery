/-  spider, g=grubbery
/+  *strandio
=,  strand=strand:spider
^-  thread:spider
|=  arg=vase
=/  m  (strand ,vase)
^-  form:m
=+  !<([~ here=path pid=@ta =stud:g =noun] arg)
;<  =bowl:spider  bind:m  get-bowl
=/  =wire  /[tid.bowl]
=/  =action:protocol:g  [[wire here] %bump pid stud noun]
=/  =path  (weld /poke/(scot %p our.bowl) wire)
;<  ~  bind:m  (watch-our /bump %grubbery path)
;<  ~  bind:m  (poke-our %grubbery grub-action+!>(action))
;<  =cage  bind:m  (take-fact /bump)
?.  ?=(%grub-sign-base -.cage)
  (strand-fail %wrong-subscription-mark ~)
=+  !<(=sign:base:g q.cage)
?.  ?=(%bump -.sign)
  (strand-fail %wrong-sign-base ~)
?^  err.sign
  (strand-fail %bump-fail u.err.sign)
~&  >  "Bump success!"
(pure:m !>(~))
