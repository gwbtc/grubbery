/-  g=grubbery
/+  grubberyio, gui, *examples, wc=web-components
|%
++  slip
  |=  [vax=vase gen=hoon]
  ^-  vase
  =+  gun=(~(mint ut p.vax) %noun gen)
  [p.gun (need (mack q.vax q.gun))]
:: from rudder (paldev)
::
++  decap  ::  strip leading base from full site path
  |=  [base=(list @t) site=(list @t)]
  ^-  (unit (list @t))
  ?~  base  `site
  ?~  site  ~
  ?.  =(i.base i.site)  ~
  $(base t.base, site t.site)
::
++  clean-perm
  |=  [here=path =perm:g]
  ^+  perm
  |^
  :*  (clean make.perm)
      (clean poke.perm)
      (clean peek.perm)
  ==
  :: add here and keep only shortest prefixes
  ::
  ++  clean
    |=  pax=(set path)
    ^-  (set path)
    (make:perx here ~(tap in pax))
  --
:: prefix storage which keeps only shortest prefixes
::
++  perx
  =<  perx
  |%
  +$  perx  (axal ~)
  ++  make
    |=  pax=(list path)
    ^-  (set path)
    (sy ~(tap px (~(gas px *perx) pax)))
  ++  px
    |_  fat=perx
    ++  put
      |=  pax=path
      ^+  fat
      ?~  pax  [[~ ~] ~]
      ?^  fil.fat  [[~ ~] ~]
      =/  kid  (~(get by dir.fat) i.pax)
      :-  ~
      %+  ~(put by dir.fat)
        i.pax
      ?^  kid
        $(fat u.kid, pax t.pax)
      (~(put of *perx) t.pax ~)
    ++  gas
      |=  pax=(list path)
      ^+  fat
      ?~  pax  fat
      $(pax t.pax, fat (put i.pax))
    ++  tap  (turn ~(tap of fat) head)
    --
  --
:: assumes a list of shortest prefixes
::
++  check-pax
  |=  [dest=path pax=(list path)]
  ^-  (each (unit path) ~)
  ?~  pax  [%| ~]
  ?^  (decap i.pax dest)
    [%& ~ i.pax]
  $(pax t.pax)
:: assumes a list of shortest prefixes
::
++  check-pax-hard
  |=  [dest=path pax=(list path)]
  ^-  (each (unit path) ~)
  ?~  pax  [%| ~]
  ?:  ?=([~ ^] (decap i.pax dest))
    [%& ~ i.pax]
  $(pax t.pax)
::
++  allowed
  |=  [=dart:g perm=(unit perm:g)]
  ^-  (each (unit path) ~)
  ?~  perm  [%& ~]
  ?:  ?=(?(%perk %muxt) -.dart)  [%& ~]
  ?:  ?=(?(%sysc %scry) -.dart)  [%| ~]
  ?-    -.load.dart
      ?(%make %oust %cull)
    (check-pax path.dart ~(tap in make.u.perm))
      %sand
    (check-pax-hard path.dart ~(tap in make.u.perm))
      ?(%poke %bump %kill)
    (check-pax path.dart ~(tap in poke.u.perm))
      %peek
    (check-pax path.dart ~(tap in peek.u.perm))
  ==
::  user groups:
::  /grp/who (set ship)
::  /grp/how perm
::  /grp/pub perm
++  file
  %-  crip
  """
  :-  /noun
  =,  grubberyio
  ^-  base:g
  |=  [=bowl:base:g =stud:g =vase]
  =/  m  (charm:base:g ,~)
  ^-  form:m
  (pour vase)
  """
::
++  bin
  |%
  :: bin base does nothing; it's like a rock
  ::
  ++  base
    =,  grubberyio
    ^-  base:g
    |=  [=bowl:base:g =stud:g =vase]
    =/  m  (charm:base:g ,~)
    ^-  form:m
    done
    ::
  ++  stem
    =,  grubberyio
    ^-  stem:g
    |=  =bowl:stem:g
    ^-  vase
    ?>  ?=([%bin *] here.bowl)
    =/  grubbery=vase  (nead (~(got by deps.bowl) /bin/grubbery))
    =/  file=vase  (nead (~(got by deps.bowl) [%lib t.here.bowl]))
    =+  !<([@t res=(each [deps=(list (pair term path)) =hoon] tang)] file)
    ?:  ?=(%| -.res)
      ~|("hoon parsing failure" (mean p.res))
    =/  deps=(set path)
      %-  ~(gas in (sy (turn deps.p.res tail)))
      ~[/bin/grubbery [%lib t.here.bowl]]
    ?>  =(deps ~(key by deps.bowl))
    =;  vax=(list vase)
      !:((slip (reel (snoc vax grubbery) slop) hoon.p.res))
    %+  turn  deps.p.res
    |=  [fac=term dep=path]
    =/  =vase  (nead (~(got by deps.bowl) dep))
    vase(p [%face fac p.vase])
  --
::
++  lib
  |%
  ++  base
    =,  grubberyio
    ^-  base:g
    |=  [=bowl:base:g =stud:g =vase]
    =/  m  (charm:base:g ,~)
    ^-  form:m
    ?+    stud  !!
        [%sig ~]
      =+  !<(=@t vase)
      =/  res=(each [pax=(list (pair term path)) =hoon] tang)
        (mule |.((build t)))
      ;<  ~  bind:m  (replace !>([t res]))
      ?>  ?=([%lib *] here.bowl)
      =/  dest=path  [%bin t.here.bowl]
      =/  sour=(set path)
        ?:(?=(%| -.res) ~ (sy (turn pax.p.res tail)))
      =.  sour  (~(gas in sour) here.bowl /bin/grubbery ~)
      ;<  ~  bind:m  (overwrite-stem dest /bin sour)
      done
    ==
  :: TODO: allow optional face and relative paths (i.e. /^/^/path)
  ::
  ++  import-line
    ;~  plug
      (cook term ;~(pfix ;~(plug (jest '/-') gap) sym))
      (cook |=(=path (welp /bin path)) ;~(pfix ;~(plug gap fas) (more fas sym)))
    ==
   ::
   ++  build
     |=  text=@t
     ^-  [(list (pair term path)) hoon]
     (rash text ;~(pfix (star gap) ;~(plug (more gap import-line) vest)))
  --
::
++  boot
  =*  grubbery-lib  ..bin :: avoid masking by grubberyio
  =*  zuse-core  ..zuse
  =,  grubberyio
  ^-  base:g
  |=  [=bowl:base:g =stud:g =vase]
  =/  m  (charm:base:g ,~)
  ^-  form:m
  ?+    stud  !!
      [%sig ~]
    ~&  >  %boot-sig
    ;<  ~  bind:m  (overwrite-base /bin/zuse /bin `!>(zuse-core))
    ~&  >  %boot-sig1
    ;<  ~  bind:m  (overwrite-base /bin/grubbery /bin `!>(grubbery-lib))
    ~&  >  %boot-sig2
    ;<  ~  bind:m  (overwrite-lib /add/two add-two)
    ~&  >  %boot-sig3
    ;<  ~  bind:m  (overwrite-stud-lib /noun 'noun')
    ~&  >  %boot-sig4
    ;<  ~  bind:m  (overwrite-stud-lib /ud '@ud')
    ~&  >  %boot-sig5
    ;<  ~  bind:m  (overwrite-stud-lib /loob '?')
    ~&  >  %boot-sig6
    ;<  ~  bind:m  (overwrite-stud-lib /txt '@t')
    ~&  >  %boot-sig7
    ;<  ~  bind:m  (overwrite-stud-lib /wain 'wain')
    ~&  >  %boot-sig8
    ;<  ~  bind:m  (overwrite-stud-lib /wall 'wall')
    ~&  >  %boot-sig9
    ;<  ~  bind:m  (overwrite-stud-lib /dr '@dr')
    ~&  >  %boot-sig10
    ;<  ~  bind:m  (overwrite-stud-lib /manx 'manx')
    ~&  >  %boot-sig11
    ;<  ~  bind:m  (overwrite-stud-lib /sig ',~')
    ~&  >  %boot-sig12
    ;<  ~  bind:m  (overwrite-stud-lib /init ',~')
    ~&  >  %boot-sig13
    ;<  ~  bind:m  (overwrite-stud-lib /load ',~')
    :: "file"
    ::
    ;<  ~  bind:m  (overwrite-base-lib /file file)
    :: user groups
    ::
    ;<  ~  bind:m  (overwrite-stud-lib /group '(set @p)')
    ;<  ~  bind:m  (overwrite-stud-lib /perm 'perm:g')
    ;<  ~  bind:m  (overwrite-base-lib /usergroup usergroup)
    ;<  ~  bind:m  (overwrite-base-lib /group-perm group-perm)
    ;<  ~  bind:m  (overwrite-base /grp/who/~zod /usergroup `!>((sy ~[~zod])))
    ;<  ~  bind:m  (overwrite-base /grp/how/~zod /group-perm `!>(*perm:g))
    ;<  ~  bind:m  (overwrite-base /grp/pub /group-perm `!>(*perm:g))
    :: counter test
    ::
    ;<  ~  bind:m  (overwrite-lib /add/two add-two)
    ;<  ~  bind:m  (overwrite-base-lib /counter counter)
    ;<  ~  bind:m  (overwrite-base-lib /counter-container counter-container)
    ;<  ~  bind:m  (overwrite-stem-lib /is-even is-even)
    ;<  ~  bind:m  (overwrite-stem-lib /parity parity)
    ;<  *  bind:m
      (overwrite-and-poke /counter-container /counter-container ~ /sig !>(~))
    :: gui setup
    ::
    ;<  ~  bind:m  (overwrite-base-lib /gui '[/sig base:gui]')
    ;<  ~  bind:m  (overwrite-stud-lib /gui/init ',~')
    ;<  *  bind:m  (overwrite-and-poke /gui /gui ~ /gui/init !>(~))
    ::
    ~&  >  "Grubbery booted!"
    done
  ==
::
++  dom
  |%
  ++  base
    =,  grubberyio
    ^-  base:g
    |=  [=bowl:base:g =stud:g =vase]
    =/  m  (charm:base:g ,~)
    ^-  form:m
    ?+    stud  !!
        [%put-base-manx ~]
      done
      ::
        [%put-stem-manx ~]
      done
    ==
  --
--
