/-  g=grubbery
/+  grubberyio, gui, *examples, wc=web-components
|%
:: evaluation engine for the main state and continuation monad
::
++  eval
  =,  g
  |%
  +$  dish
    $:  now=@da
        our=@p
        eny=@uvJ
        wex=boat:gall
        sup=bitt:gall
        here=path
        pid=@ta
        perm=(unit perm:g)
    ==
  ::
  ++  make-bowl
    |=  [dish =from:g]
    ^-  bowl:base:g
    :*  now
        ?^(perm ~ `our)
        eny
        ?^(perm ~ `wex)
        ?^(perm ~ `sup)
        (mask-from here perm from)
        (mask-here here perm)
        pid
    ==
  ::
  ++  output  (output-raw:base ,~)
  ::
  +$  result
    $%  [%next hold=?]
        [%fail err=tang]
        [%done ~]
    ==
  ::
  +$  took  [take:base (unit tang)]
  ::
  ++  take
    =|  darts=(list dart) :: effects
    =|  done=(list took) :: sequentially processed inputs
    =|  =bowl:base:g
    |=  [=dish state=vase temp=(axal vase) =proc]
    ^-  [(list dart) (list took) vase (axal vase) _proc result]
    =^  =take:base  next.proc  ~(get to next.proc)
    |-  :: recursion point so take can be replaced
    =.  bowl  (make-bowl dish from.give.take)
    =/  res=(each output tang)
      (mule |.((proc.proc bowl pail.poke.proc state temp in.take)))
    ?:  ?=(%| -.res)
      =/  =tang  [leaf+"crash" p.res]
      :-  darts :: no output darts on failure
      :-  :_(done [take ~ tang])
      :-  state :: no output state on failure
      :-  temp  :: no output temp on failure
      :-  proc  
      [%fail tang]
    =/  =output  p.res
    ?-    -.next.output
        %fail
      :-  darts :: no output darts on failure
      :-  :_(done [take ~ err.next.output])
      :-  state :: no output state on failure
      :-  temp  :: no output temp on failure
      :-  proc
      [%fail err.next.output]
      ::
        %done
      :-  (weld darts darts.output)
      :-  :_(done [take ~])
      :-  state.output
      :-  temp.output
      :-  proc
      [%done ~]
      ::
        %cont
      %=  $
        darts      (weld darts darts.output)
        done       :_(done [take ~])
        state      state.output
        temp       temp.output
        next.proc  (~(gas to next.proc) ~(tap to skip.proc))
        skip.proc  ~
        proc.proc  self.next.output
        in.take    ~
      ==
      ::
        %wait
      =.  darts  (weld darts darts.output)
      =.  done   :_(done [take ~])
      ?.  =(~ next.proc)
        :: recurse on queued input
        ::
        =^  top  next.proc  ~(get to next.proc)
        %=  $
          take       top
          state      state.output
          temp       temp.output
        ==
      :: await input
      ::
      :-  darts
      :-  done
      :-  state.output
      :-  temp.output
      :-  proc
      [%next hold.next.output]
      ::
        %skip
      ?:  =(~ in.take)
        :: can't %skip a ~ input
        ::
        =/  =tang  [leaf+"cannot skip null input" ~]
        :-  darts :: no output darts on failure
        :-  :_(done [take ~ tang])
        :-  state :: no output state on failure
        :-  temp  :: no output temp on failure
        :-  proc
        [%fail tang]
      :: skip input
      ::
      =.  skip.proc  (~(put to skip.proc) take)
      ?.  =(~ next.proc)
        :: recurse on queued input
        ::
        =^  top  next.proc  ~(get to next.proc)
        $(take top)
      :-  darts :: %skips can't send effects
      :-  done  :: skipping doesn't complete the $take
      :-  state :: %skips can't change state
      :-  temp  :: %skips can't change temporary variables
      :-  proc
      [%next hold.next.output]
    ==
  --
::
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
:: get make, poke and peek permissions for grub at the path "here"
:: each as a set of unique, shortest path prefixes, including here
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
:: path prefix storage which keeps only shortest path prefixes
::
++  perx :: a permission axal
  =<  perx
  |%
  +$  perx  (axal ~) :: no contents; only trie structure
  :: set of unique shortest path prefixes
  ::
  ++  make
    |=  pax=(list path)
    ^-  (set path)
    (sy ~(tap px (~(gas px *perx) pax)))
  ++  px
    |_  fat=perx
    ++  put
      |=  pax=path
      ^+  fat
      ?~  pax  [[~ ~] ~]     :: finish at end of path
      ?^  fil.fat  [[~ ~] ~] :: finish at first populated descendant and prune
      =/  kid  (~(get by dir.fat) i.pax)
      :-  ~
      %+  ~(put by dir.fat)
        i.pax
      ?^  kid
        :: existing sub-tree: recurse for pruning logic
        $(fat u.kid, pax t.pax)
      :: no sub-tree: populate end of path
      (~(put of *perx) t.pax ~)
    ++  gas
      |=  pax=(list path)
      ^+  fat
      ?~  pax  fat
      $(pax t.pax, fat (put i.pax))
    ++  tap  (turn ~(tap of fat) head) :: list paths; ignore null contents
    --
  --
:: [%& ~]            - full system access
:: [%& ~ /some/path] - access under /some/path
:: [%| ~]            - no access
::
+$  auth  (each (unit path) ~)
:: find any path in pax that is a prefix of dest
:: assumes a list of shortest prefixes in which case
:: if a prefix exists it will be unique
::
++  find-prefix
  |=  [dest=path pax=(list path)]
  ^-  (unit path)
  ?~  pax  ~
  ?^  (decap i.pax dest)
    [~ i.pax]
  $(pax t.pax)
:: find any path in pax that is a strict, non-equal prefix of dest
:: assumes a list of shortest prefixes in which case
:: if a prefix exists it will be unique
::
++  find-prefix-hard
  |=  [dest=path pax=(list path)]
  ^-  (unit path)
  ?~  pax  ~
  ?:  ?=([~ ^] (decap i.pax dest))
    [~ i.pax]
  $(pax t.pax)
::
++  check-pax
  |=  [dest=path pax=(list path)]
  ^-  auth
  ?~  pfx=(find-prefix dest pax)
    [%| ~]
  [%& ~ u.pfx]
::
++  check-pax-hard
  |=  [dest=path pax=(list path)]
  ^-  auth
  ?~  pfx=(find-prefix-hard dest pax)
    [%| ~]
  [%& ~ u.pfx]
::
++  allowed
  |=  [here=path =dart:g perm=(unit perm:g)]
  ^-  auth
  ?~  perm  [%& ~] :: null permissions represents full system access
  ?:  ?=(%perk -.dart)  [%& ~] :: %perks ("subscription" updates) always allowed
  ?:  ?=(?(%sysc %scry) -.dart)  [%| ~] :: only ~ perm can make syscalls or scry
  =/  path=(unit path)  (path-from-road here road.dart)
  ?~  path  [%| ~] :: invalid bend (bad relative path)
  ?-    -.load.dart
      ?(%make %oust %cull)
    (check-pax u.path ~(tap in make.u.perm))
      ?(%poke %bump %kill)
    (check-pax u.path ~(tap in poke.u.perm))
      %peek
    (check-pax u.path ~(tap in peek.u.perm))
      %sand
    :: check-pax-hard: a perfectly sandboxed grub cannot change its own perms
    ::
    (check-pax-hard u.path ~(tap in make.u.perm))
  ==
:: Convert a relative path to an absolute path
::
++  path-from-bend
  |=  [here=path =bend:g]
  ^-  (unit path)
  =.  here  (flop here)
  |-
  ?:  =(0 p.bend)
    `(weld (flop here) q.bend)
  ?~  here  ~
  $(here t.here, p.bend (dec p.bend))
:: Convert an absolute or relative path to an absolute path
::
++  path-from-road
  |=  [here=path =road:g]
  ^-  (unit path)
  ?-  -.road
    %&  `p.road
    %|  (path-from-bend here p.road)
  ==
::
++  mask-here
  |=  [here=path perm=(unit perm:g)]
  ^-  road:g
  ?~  perm  [%& here]
  =/  pfx=(unit path)  (find-prefix here ~(tap in peek.u.perm))
  ?>  ?=(^ pfx)
  ?:  =([~ /] pfx)  [%& here]
  =/  tel=path  (need (decap u.pfx here))
  [%| (lent tel) tel]
::
++  mask-path
  |=  [here=path perm=(unit perm:g) dest=path]
  ^-  (unit road:g)
  ?~  perm  [~ %& dest]
  =/  here-pfx=(unit path)  (find-prefix here ~(tap in peek.u.perm))
  =/  dest-pfx=(unit path)  (find-prefix dest ~(tap in peek.u.perm))
  ?>  ?=(^ here-pfx)
  ?~  dest-pfx  ~
  ?.  =(here-pfx dest-pfx)  ~
  ?:  =([~ /] here-pfx)  [~ %& dest]
  =/  here-tel=path  (need (decap u.here-pfx here))
  =/  dest-tel=path  (need (decap u.dest-pfx here))
  [~ %| (lent here-tel) dest-tel]
::
++  mask-from
  |=  [here=path perm=(unit perm:g) =from:g]
  ^-  from:base:g
  ?~  perm
    ?-  -.from
      %|  [%| p.from]
      %&  [%& ~ &+p.from]
    ==
  ?-  -.from
    %|  [%& ~]
    %&  [%& (mask-path here perm p.from)]
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
  =/  m  (charm:base:g ,~)
  ^-  form:m
  ;<  [=stud:g =vase]  bind:m  get-poke-pail
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
    ~|  "failed to find dep {(spud dep)}"
    =/  =vase  (nead (~(got by deps.bowl) dep))
    vase(p [%face fac p.vase])
  --
::
++  lib
  |%
  ++  base
    =,  grubberyio
    ^-  base:g
    =/  m  (charm:base:g ,~)
    ^-  form:m
    ;<  [=stud:g =vase]  bind:m  get-poke-pail
    ;<  here=path        bind:m  get-here
    ?+    stud  !!
        [%sig ~]
      =+  !<(=@t vase)
      =/  res=(each [pax=(list (pair term path)) =hoon] tang)
        (mule |.((build t)))
      ;<  ~  bind:m  (replace !>([t res]))
      ?>  ?=([%lib *] here)
      =/  dest=path  [%bin t.here]
      =/  sour=(set path)
        ?:(?=(%| -.res) ~ (sy (turn pax.p.res tail)))
      =.  sour  (~(gas in sour) here /bin/grubbery ~)
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
  =/  m  (charm:base:g ,~)
  ^-  form:m
  ;<  [=stud:g =vase]  bind:m  get-poke-pail
  ?+    stud  !!
      [%sig ~]
    ~&  >  %boot-sig
    ;<  ~  bind:m  (overwrite-base /bin/zuse /bin `!>(zuse-core))
    ;<  ~  bind:m  (overwrite-base /bin/grubbery /bin `!>(grubbery-lib))
    ;<  ~  bind:m  (overwrite-lib /add/two add-two)
    ;<  ~  bind:m  (overwrite-stud-lib /noun 'noun')
    ;<  ~  bind:m  (overwrite-stud-lib /ud '@ud')
    ;<  ~  bind:m  (overwrite-stud-lib /loob '?')
    ;<  ~  bind:m  (overwrite-stud-lib /txt '@t')
    ;<  ~  bind:m  (overwrite-stud-lib /wain 'wain')
    ;<  ~  bind:m  (overwrite-stud-lib /wall 'wall')
    ;<  ~  bind:m  (overwrite-stud-lib /dr '@dr')
    ;<  ~  bind:m  (overwrite-stud-lib /manx 'manx')
    ;<  ~  bind:m  (overwrite-stud-lib /sig ',~')
    ;<  ~  bind:m  (overwrite-stud-lib /init ',~')
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
    =/  m  (charm:base:g ,~)
    ^-  form:m
    ;<  [=stud:g =vase]  bind:m  get-poke-pail
    ?+    stud  !!
        [%put-base-manx ~]
      done
      ::
        [%put-stem-manx ~]
      done
    ==
  --
--
