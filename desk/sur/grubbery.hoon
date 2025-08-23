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
::
+$  dart
  $%  [%grub =wire =path =load]
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
      [%kill pid=@ta]
      [%peek ~]
  ==
::
+$  grub
  $%  [%base data=vase base=path]
      [%stem data=(each vase tang) stem=path tidy=? sour=(map path @da)]
  ==
::
+$  take  [[here=path pid=@ta] take:base]
::
+$  proc
  $:  =proc:base
      =give
      next=cute:base
      skip=cute:base
  ==
::
+$  cone  (axal grub)
+$  give  [from=path =wire]
+$  poke  [=give =pail]
+$  tack
  $:  last=[step=@da poke=@da]
      sinx=(set path)
      boar=(unit @ta)     :: who is hogging the pipes
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
  +$  bowl
    $:  now=@da                          :: time
        our=@p                           :: host
        eny=@uvJ                         :: entropy
        here=path                        :: our address
        deps=(map path (each vase tang)) :: dependencies
    ==
  --
::
++  base
  =<  base
  |%
  +$  bowl
    $:  now=@da       :: time
        our=@p        :: host
        eny=@uvJ      :: entropy
        wex=boat:gall :: outgoing gall subs
        sup=bitt:gall :: incoming gall subs
        from=path     :: provenance
        here=path     :: our address
        pid=@ta       :: our process id
    ==
  ::
  +$  sign
    $%  [%poke err=(unit tang)]
        [%perk err=(unit tang)]
        [%bump err=(unit tang)]
        [%pack p=(each @ta tang)]
    ==
  ::
  +$  intake
    $%  [%bump =pail]
        [%perk =wire =pail]
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
  +$  input  [=bowl state=vase in=(unit intake)]
  ::
  +$  take  [=give in=(unit intake)]
  +$  cute  (qeu take)
  ::
  ++  output-raw
    |*  value=mold
    $~  [~ !>(~) %done *value]
    $:  darts=(list dart)
        state=vase
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
  +$  base  $-([bowl pail] proc)
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
      [~ state %done value]
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
      ?-    -.next.b-res
        %wait  [%wait hold.next.b-res]
        %skip  [%skip hold.next.b-res]
        %cont  [%cont ..$(m-b self.next.b-res)]
        %fail  [%fail err.next.b-res]
        %done  [%cont (fun value.next.b-res)]
      ==
    ::
    ++  eval
      |%
      +$  result
        $%  [%next hold=?]
            [%fail err=tang]
            [%done =value]
        ==
      ::
      ++  take
        =|  darts=(list dart) :: effects
        =|  done=(list [^take (unit tang)]) :: sequentially processed inputs
        |=  [[=form next=cute skip=cute] =give =input]
        ^-  [[(list dart) (list [^take (unit tang)]) vase result] _form cute cute]
        =/  res=(each output tang)  (mule |.((form input)))
        ?:  ?=(%| -.res)
          =/  =tang  [leaf+"crash" p.res]
          :_  [form next skip]
          :-  darts :: no output darts on failure
          :-  :_(done [[give in.input] ~ tang])
          :-  state.input :: no output state on failure
          [%fail tang]
        =/  =output  p.res
        ?-    -.next.output
            %fail
          :_  [form next skip]
          :-  darts :: no output darts on failure
          :-  :_(done [[give in.input] ~ err.next.output])
          :-  state.input :: no output state on failure
          [%fail err.next.output]
          ::
            %done
          :_  [form next skip]
          :-  (weld darts darts.output)
          :-  :_(done [[give in.input] ~])
          :-  state.output
          [%done value.next.output]
          ::
            %cont
          %=  $
            next   (~(gas to next) ~(tap to skip))
            skip   ~
            form   self.next.output
            darts  (weld darts darts.output)
            done   :_(done [[give in.input] ~])
            input  [bowl.input state.output ~]
          ==
          ::
            %wait
          =.  darts        (weld darts darts.output)
          =.  done         :_(done [[give in.input] ~])
          ?.  =(~ next)
            :: recurse on queued input
            ::
            =^  top  next  ~(get to next)
            %=  $
              give   -.top
              input  [bowl.input state.output +.top]
            ==
          :: await input
          ::
          :_  [form next skip]
          :-  darts
          :-  done
          :-  state.output
          [%next hold.next.output]
          ::
            %skip
          ?:  =(~ in.input)
            :: can't %skip a ~ input
            ::
            =/  =tang  [leaf+"cannot skip null input" ~]
            :_  [form next skip]
            :-  darts :: no output darts on failure
            :-  :_(done [[give in.input] ~ tang])
            :-  state.input :: no output state on failure
            [%fail tang]
          :: skip input
          ::
          =.  skip  (~(put to skip) [give in.input])
          ?.  =(~ next)
            :: recurse on queued input
            ::
            =^  top  next  ~(get to next)
            $(give -.top, in.input +.top)
          :_  [form next skip]
          :-  darts :: %skips can't send effects
          :-  done  :: skipping doesn't complete the $take
          :-  state.input :: %skips can't change state
          [%next hold.next.output]
        ==
      --
    --
  --
--
