|%
+$  stud  path
+$  pail  (pair stud vase)
+$  card  card:agent:gall
+$  make
  $%  [%base base=path data=(unit vase)]
      [%stem stem=path sour=(set path)]
  ==
::
+$  deed  ?(%make %oust %cull %sand %poke %bump %kill %peek)
::
+$  perm
  $:  make=(set path) :: %make or %oust (%sand ?)
      poke=(set path) :: %poke, %bump or %kill
      peek=(set path)
  ==
::
+$  sand  (axal perm)
:: effects that a base grub can emit
:: TODO: it should be possible to make a syscall such that the response
::       comes back as an entirely new poke instead of as a base input
::       this probably involves storing studs for syscall responses
::
+$  dart
  $%  [%grub =wire =road =load]
      [%perk =wire =pail]
      [%sysc =card:agent:gall]
      [%scry =wire =mold =path]
  ==
:: pair of source grub (here) and emitted dart
::
+$  bolt  [here=path pid=@ta =dart]
:: dart payload
::
+$  load
  $%  [%make =make]
      [%oust ~]
      [%cull ~]
      [%sand perm=(unit perm)]
      [%poke =pail]
      [%bump pid=@ta =pail]
      [%kill pid=(unit @ta)]
      [%peek ~]
  ==
::
+$  grub
  $%  [%base data=vase base=path]
      [%stem data=(each vase tang) stem=path tidy=? sour=(map path @da)]
  ==
:: TODO: for stems, assigning deps should be like mapping from a local
::       deps namespace to the global grubbery namespace
:: TODO: tidy and sour should be moved to trac?
::
:: TODO: our, from and here should be restricted entirely in line with
::       peek permissions
::
+$  bend  (pair @ud path)
:: roads can be used to navigate relative to one's known or unknown location
:: in the tree. from and here should also be roads, where a relative road
:: means that you are sandboxed and where p.bend == (lent q.bend)
::
+$  road  (each path bend)
+$  prov  [src=@p sap=path]
:: [%| ~zod /gall/...]                    - from outside grubbery
:: [%& ~ %& /some/absolute/path]          - absolute path from inside grubbery
:: [%& ~ %| &+2 /relative/path/to/source] - relative path in peek sandbox
:: [%& ~]                                 - out of peek sandbox
::
+$  from  (each (unit road) prov)
:: should probably distinguish from from from:base
:: from:base might be the above, normal from might be
:: +$  from  (each path prov)
+$  take  [[here=path pid=@ta] take:base]
::
+$  proc
  $:  =proc:base
      =poke            :: keep initial poke
      next=cute:base   :: queue of held inputs
      skip=cute:base   :: queue of skipped inputs
  ==
::
+$  cone  (axal grub)
+$  give  [=from =wire]
+$  poke  [=give =pail]
+$  tack
  $:  last=[step=@da poke=@da]
      sinx=(set path)
      boar=(unit @ta)  :: who is hogging the pipes
      temp=(axal vase) :: persist shared "transient" state
      proc=(map @ta proc)
  ==
+$  trac  (axal tack)
:: NOTE: the distinction between cone and trac exists because
::       it is not yet clear what information should be available
::       on peek. Sinx being in tack also makes dependencies
::       more ergonomic (for now) in the case where a source
::       is deleted and then recreated or replaced
::
+$  bindings  (map (list @t) path) :: eyre bindings
:: time ordered latest changes
::
+$  history   ((mop @da path) gth)
++  hon       ((on @da path) gth)
::
++  stem
  =<  stem
  |%
  +$  stem  $-(bowl vase)
  :: TODO: replace with only deps
  +$  bowl
    $:  here=path                        :: our address
        deps=(map path (each vase tang)) :: dependencies
    ==
  --
::
++  base
  =<  proc
  |%
  +$  bowl
    $:  now=@da       :: time
        our=(unit @p) :: host - sandboxed grubs may not see
        eny=@uvJ      :: entropy
        wex=boat:gall :: outgoing gall subs
        sup=bitt:gall :: incoming gall subs
        =from         :: provenance
        here=road     :: our address
        pid=@ta       :: our process id
    ==
  ::
  +$  sign
    $%  [%poke err=(unit tang)] :: complete poke cycle (finish or crash)
        [%perk err=(unit tang)] :: response to gift / subscription
        [%bump err=(unit tang)] ::  response to command for running process
        [%pack p=(each @ta tang)] :: build poke (id or build error)
    ==
  ::
  +$  intake
    $%  [%bump =pail] :: command for a running process
        [%perk =wire =pail] :: gift / subscription
        [%peek =wire =path =cone =sand] :: local read
        [%made =wire err=(unit tang)] :: response to make
        [%gone =wire err=(unit tang)] :: response to oust
        [%cull =wire err=(unit tang)] :: response to cull
        [%dead =wire err=(unit tang)] :: response to kill
        [%sand =wire err=(unit tang)] :: response to sand
        [%base =wire =sign] :: response from poke or bump
        [%veto =dart] :: notify that a dart was sandboxed
        :: messages from gall and arvo
        ::
        [%scry =wire =path =vase]
        [%arvo =wire sign=sign-arvo]
        [%agent =wire =sign:agent:gall]
        [%watch =path]
        [%leave =path]
    ==
  ::
  +$  input  [=bowl =pail state=vase temp=(axal vase) in=(unit intake)]
  ::
  +$  take  [=give in=(unit intake)]
  +$  cute  (qeu take)
  ::
  ++  output-raw
    |*  value=mold
    $~  [~ !>(~) [~ ~] %done *value]
    $:  darts=(list dart)
        state=vase
        temp=(axal vase)
        $=  next
        $%  [%wait hold=?]
            [%skip hold=?]
            [%cont self=(form-raw value)]
            [%fail err=tang]
            [%done =value]
        ==
    ==
  ::
  ++  form-raw
    |*  value=mold
    $-(input (output-raw value))
  ::
  +$  proc  _*form:(charm ,~)
  :: 
  ++  charm
    |*  value=mold
    |%
    ++  output  (output-raw value)
    ++  form    (form-raw value)
    :: give value; leave state unchanged
    ::
    ++  pure
      |=  =value
      ^-  form
      |=  input
      ^-  output
      [~ state temp %done value]
    ::
    ++  bind
      |*  b=mold
      |=  [m-b=(form-raw b) fun=$-(b form)]
      ^-  form
      |=  =input
      =/  b-res=(output-raw b)  (m-b input)
      ^-  output
      :-  darts.b-res
      :-  state.b-res
      :-  temp.b-res
      ?-    -.next.b-res
        %wait  [%wait hold.next.b-res]
        %skip  [%skip hold.next.b-res]
        %cont  [%cont ..$(m-b self.next.b-res)]
        %fail  [%fail err.next.b-res]
        %done  [%cont (fun value.next.b-res)]
      ==
    --
  --
::
++  eval
  |%
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
    |=  [=bowl:base state=vase temp=(axal vase) =proc]
    ^-  [(list dart) (list took) vase (axal vase) _proc result]
    =^  =take:base  next.proc  ~(get to next.proc)
    =.  from.bowl  from.give.take :: TODO: implement sandboxing
    |-  :: recursion point so take can be replaced
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
--
