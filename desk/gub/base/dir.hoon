/-  dir        /stud/dir
/-  dir-poke   /stud/dir/poke
/-  mp         /stud/multipart
/-  multipart  /multipart
!:
:-  /dir
=,  grubberyio
^-  base:g
=/  m  (charm:base:g ,~)
^-  form:m
;<  [=stud:g =vase]  bind:m  get-poke-pail
?+    stud  (charm-fail leaf+"bad stud" ~)
    [%multipart ~]
  =+  !<(=mp vase)
  =/  parts=(map @t part:multipart)
    (~(gas by *(map @t part:multipart)) mp)
  =+  (~(got by parts) 'file')
  =/  =road:g  |+[0 /[(fall file %unnamed)]]
  =/  =mime
    :_  (as-octs:mimes:html body)
    (fall type /application/octet-stream)
  ;<  ~     bind:m  (make-base road /mime ~ !>(mime))
  ;<  =dir  bind:m  (get-state-as ,dir)
  (pour !>([hid.dir (snoc dir.dir road)]))
    ::
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
