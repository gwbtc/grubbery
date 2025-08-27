/-  g=grubbery
/+  grubberyio, gui, *examples, wc=web-components
|%
:: evaluation engine for the main state and continuation monad
::
++  eval
  |%
  ++  output  (output-raw:base:g ,~)
  ::
  +$  result
    $%  [%next hold=?]
        [%fail err=tang]
        [%done ~]
    ==
  ::
  +$  took  [take:base:g (unit tang)]
  ::
  ++  take
    =|  darts=(list dart:g) :: effects
    =|  done=(list took) :: sequentially processed inputs
    |=  [here=path state=vase temp=(axal vase) pid=@ta =proc:g]
    ^-  [(list dart:g) (list took) vase (axal vase) _proc result]
    =/  =from:base:g  (relativize-from here from.give.poke.proc)
    =^  =take:base:g  next.proc  ~(get to next.proc)
    |-  :: recursion point so take can be replaced
    =/  res=(each output tang)
      (mule |.((proc.proc pid from pail.poke.proc state temp in.take)))
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
++  render-road
  |=  =road:g
  ^-  tape
  ?-  -.road
    %&  (spud p.road)
    %|  "^{(scow %ud p.p.road)} {(spud q.p.road)}"
  ==
::
++  prefix
  =|  p=path
  |=  [a=path b=path]
  ^-  path
  ?~  a  (flop p)
  ?~  b  (flop p)
  ?.  =(i.a i.b)  (flop p)
  $(a t.a, b t.b, p [i.a p])
::
++  make-bend
  |=  [here=path dest=path]
  ^-  bend:g
  =/  pref=path  (prefix here dest)
  =/  here-tel=path  (need (decap pref here))
  =/  dest-tel=path  (need (decap pref dest))
  [(lent here-tel) dest-tel]
::
++  relativize-from
  |=  [here=path =from:g]
  ^-  from:base:g
  ?.  ?=(%& -.from)
    from
  &+(make-bend here p.from)
::
++  raw-filter
  |=  [dest=path filt=(list path)]
  ^-  ?
  ?~  filt  |
  ?:  ?=(^ (decap i.filt dest))
    &
  $(filt t.filt)
::
++  filter-roads
  |=  [here=path dest=path filt=(list road:g)]
  ^-  ?
  (raw-filter dest (murn filt (cury path-from-road here)))
::
++  filter
  |=  [dest=path =jump:g here=path perm=(unit perm:g)]
  ^-  filt:g
  ?~  perm  ~
  ?:  ?=(%sysc jump)
    [~ %|] :: any filter stops syscalls
  ?:  ?=(?(%perk %give) jump)
    [~ %&] :: perks + "gives" pass through any filter
  :-  ~
  ?-  jump
    %make  (filter-roads here dest ~(tap in make.u.perm))
    %poke  (filter-roads here dest ~(tap in poke.u.perm))
    %peek  (filter-roads here dest ~(tap in peek.u.perm))
  ==
::
++  next-filt
  |=  [cur=filt:g nex=filt:g]
  ^-  filt:g
  ?~  cur  nex
  ?~  nex  cur
  ?:  ?=([~ %|] cur)
    [~ %|]
  ?:  ?=([~ %|] nex)
    [~ %|]
  [~ %&]
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
  :: bin base does nothing
  :: TODO: why have it be a base at all....?
  ::
  ++  base  `base:g`done:grubberyio
    ::
  ++  stem
    =,  grubberyio
    ^-  stem:g
    |=  =deps:stem:g
    ^-  vase
    =/  grubbery=vase  (nead (need (~(get of deps) /bin/grubbery)))
    =/  file=vase  (nead (need (~(get of deps) /source-lib)))
    =+  !<([@t res=(each [deps=(list (pair term path)) =hoon] tang)] file)
    ?:  ?=(%| -.res)
      ~|("hoon parsing failure" (mean p.res))
    =;  vax=(list vase)
      !:((slip (reel (snoc vax grubbery) slop) hoon.p.res))
    %+  turn  deps.p.res
    |=  [fac=term dep=path]
    ~|  "failed to find dep {(spud dep)}"
    =/  =vase  (nead (need (~(get of deps) dep)))
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
      =/  sour=vine:stem:g
        %-  ~(gas of *vine:stem:g)
        %+  welp  ~[[/source-lib &+here] [/bin/grubbery &+/bin/grubbery]]
        ?:(?=(%| -.res) ~ (turn pax.p.res |=([=term =path] [path &+path])))
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
    ~&  >>>  %basic-libraries-studs
    ;<  ~  bind:m  (overwrite-base /bin/zuse /bin `!>(zuse-core))
    ~&  >>>  %got-here-1
    ;<  ~  bind:m  (overwrite-base /bin/grubbery /bin `!>(grubbery-lib))
    ~&  >>>  %got-here-2
    ;<  ~  bind:m  (overwrite-lib /add/two add-two)
    ~&  >>>  %got-here-3
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
    ~&  >>>  %file
    ;<  ~  bind:m  (overwrite-base-lib /file file)
    :: user groups
    ::
    :: ~&  >>>  %user-groups
    :: ;<  ~  bind:m  (overwrite-stud-lib /group '(set @p)')
    :: ;<  ~  bind:m  (overwrite-stud-lib /perm 'perm:g')
    :: ;<  ~  bind:m  (overwrite-base-lib /usergroup usergroup)
    :: ;<  ~  bind:m  (overwrite-base-lib /group-perm group-perm)
    :: ;<  ~  bind:m  (overwrite-base /grp/who/~zod /usergroup `!>((sy ~[~zod])))
    :: ;<  ~  bind:m  (overwrite-base /grp/how/~zod /group-perm `!>(*perm:g))
    :: ;<  ~  bind:m  (overwrite-base /grp/pub /group-perm `!>(*perm:g))
    :: counter test
    ::
    ~&  >>>  %counter-test
    ;<  ~  bind:m  (overwrite-lib /add/two add-two)
    :: ;<  ~  bind:m  (overwrite-base-lib /counter counter)
    :: ;<  ~  bind:m  (overwrite-base-lib /counter-container counter-container)
    :: ;<  ~  bind:m  (overwrite-stem-lib /is-even is-even)
    :: ;<  ~  bind:m  (overwrite-stem-lib /parity parity)
    :: ;<  *  bind:m
    ::   (overwrite-and-poke /counter-container /counter-container ~ /sig !>(~))
    :: gui setup
    ::
    ~&  >>>  %gui-setup
    ~&  >>>  %overwriting-gui-base-lib
    ;<  ~  bind:m  (overwrite-base-lib /gui '[/sig base:gui]')
    ~&  >>>  %overwriting-gui-init-stud-lib
    ;<  ~  bind:m  (overwrite-stud-lib /gui/init ',~')
    ~&  >>>  %overwriting-and-poking-gui-base
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
