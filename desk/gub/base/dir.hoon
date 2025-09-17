/-  dir       /stud/dir
/-  dir-poke  /stud/dir/poke
:-  /dir
=,  grubberyio
^-  base:g
=/  m  (charm:base:g ,~)
^-  form:m
;<  [=stud:g =vase]  bind:m  get-poke-pail
?+    stud  !!
    [%dir %poke ~]
  =+  !<(=dir-poke vase)
  ?-    -.dir-poke
      %toggle-hidden
    ;<  =dir  bind:m  (get-state-as ,dir)
    (pour !>([!hid dir]:dir))
    ::
      %create-subdir
    ?<  =('' name.dir-poke)
    =/  =road:g  |+[0 /[name.dir-poke]]
    ;<  ~  bind:m  (make-base road /dir ~)
    ;<  =dir  bind:m  (get-state-as ,dir)
    (pour !>([hid.dir (snoc dir.dir road)]))
    ::
      %create-symlink
    ;<  =dir  bind:m  (get-state-as ,dir)
    (pour !>([hid.dir (snoc dir.dir road.dir-poke)]))
  ==
==
