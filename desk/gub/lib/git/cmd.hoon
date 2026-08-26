::  lib/git/cmd: a git-CLI options/argv parser.
::
::    Ported from hoon-git's lib/cmd.hoon — the one real artifact there (its
::    per-command parsers were referenced but never written). Front-end
::    agnostic: it turns a command string into a parsed [command options]
::    pair. Both forge's command input and the git_cmd MCP tool sit on this,
::    so the grammar for a verb lives in exactly one place.
::
::    Build verb grammars with the combinators below:
::      +cmd       a verb that takes options (before and/or after args) + args
::      +cmd-solo  a verb with no options, just args
::      +flag-opt / +text-opt / +num-opt   declare an option of each kind
::
|%
+$  opt-kind  ?(%f %t %ud)                    ::  flag | text | number
+$  opt-val   $%([%f ~] [%t @t] [%ud @ud])
+$  option    (pair @tas opt-val)             ::  [--name value]
::  +cmd-parse: parse a full verb (front options, args, back options).
::
++  cmd-parse  cmd:parse
++  parse
  |%
  ::  Renovated @ta to include uppercase
  ::
  ++  urs  %+  cook
             |=(a=tape (rap 3 ^-((list @) a)))
           (star ;~(pose nud hig low hep dot sig cab))
  ++  gap  (plus ace)
  ++  val-f  (easy ~)  :: option is present
  ::  XX Allow non-Hoon integers
  ++  val-ud  dem:ag
  ++  val-t
    ;~  pose
      ::  "double quoted" (git/shell convention)
      (ifix [doq doq] (boss 256 (star ;~(less doq prn))))
      ::  'single quoted'
      (ifix [soq soq] (boss 256 (star qit)))
      ::  unescaped cord
      (boss 256 (star ;~(less ace qit)))
    ==
  ++  value
    |*  kind=opt-kind
    ?-  kind
      %f  (stag %f val-f)
      %t  (stag %t val-t)
      %ud  (stag %ud val-ud)
    ==
  ::  -o
  ++  short
    |=(o=char ;~(plug hep (just o)))
  ::  --opt
  ++  long
    |=  opt=@tas
    ;~(plug hep hep (jest opt))
  ::  -o val, -oval
  ++  short-value
    |=  [o=char kind=opt-kind]
    ?:  ?=(%f kind)
      ;~(pfix (short o) (value kind))
    ;~(pfix (short o) ;~(pfix (star ace) (value kind)))
  ::  --opt val, --opt=val
  ++  long-value
    |=  [opt=@tas kind=opt-kind]
    ::  XX a bug in the parser:
    ::  ?=(kind %f) parser to something wrong
    ::
    ?:  ?=(%f kind)
      ;~(pfix (long opt) (value kind))
    ;~  pfix
      (long opt)
      ;~  pose
        ;~(pfix tis (value kind))
        ;~(pfix gap (value kind))
      ==
    ==
  ++  short-or-long-value
    |=  [o=@t opt=@tas kind=opt-kind]
    ;~  pose
      (short-value o kind)
      (long-value opt kind)
    ==
  ++  opt
    |=  [opt=@tas o=@tas kind=opt-kind]
    %+  stag  opt
    ?:  =(%$ o)
      (long-value opt kind)
    (short-or-long-value o opt kind)
  ++  flag-opt
    |=  [opt=@tas o=@tas]
    (^opt opt o %f)
  ++  text-opt
    |=  [opt=@tas o=@tas]
    (^opt opt o %t)
  ++  num-opt
    |=  [opt=@tas o=@tas]
    (^opt opt o %ud)
  ++  cmd-solo
    |*  [cmd=@tas args=rule]
    %+  cook
      |=(cmd=* [cmd ~])
    (stag cmd ;~(pfix (jest cmd) args))
  ++  any-short-opt
    ;~(plug hep ;~(pose low dit))
  ++  any-long-opt
    ;~(plug hep hep ;~(pose low dit))
  ++  any-opt
    ;~(pose any-short-opt any-long-opt)
  ++  cmd
    |*  [cmd=@tas opt=rule args=rule]
    |=  tub=nail
    ^-  (like [* (list option)])
    ::  Parse front options, command arguments
    ::
    ::  XX using , somehow changes output of
    ::  compiler error.
    ::
    =/  vex=(like [(list option) (unit *) *])
      %.  tub
      ;~  pfix  (jest cmd)
        ;~  plug
          (ifix [gap (star ace)] (more gap opt))
          (punt ;~(plug hep hep gap))
          (stag cmd args)
        ==
      ==
    ?~  q.vex  vex
    =/  [front=(list option) opt-end=(unit *) command=*]
      p.u.q.vex
    ?:  ?|(?=(^ opt-end) =("" q.q.u.q.vex))
      [p.vex `[[command front] q.u.q.vex]]
    =/  vex=(like (list option))
      %.  q.u.q.vex
      ;~  sfix
        ;~(pfix gap (more gap opt))
        (star ace)
      ==
    ?~  q.vex  vex
    =+  back=p.u.q.vex
    [p.vex `[[command (weld front back)] q.u.q.vex]]
  --
--
