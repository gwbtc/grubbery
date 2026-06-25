::  mark for labels:bip329
::
/<  b329  /lib/bip329.hoon
=,  format
|_  =labels:b329
++  grab
  |%
  ++  noun  labels:b329
  ++  mime
    |=  [p=mite q=octs]
    ^-  labels:b329
    (json (need (de:json:html (@t q.q))))
  ++  json
    |=  jon=^json
    ^-  labels:b329
    ?>  ?=([%a *] jon)
    (~(import la:b329 *labels:b329) (turn p.jon entry-from-json))
  --
++  grow
  |%
  ++  noun  labels
  ++  json
    ^-  ^json
    :-  %a
    %+  turn  ~(export la:b329 labels)
    |=  e=label-entry:b329
    =/  base=(list [@t ^json])
      :~  ['type' s+(scot %tas type.e)]
          ['ref' s+ref.e]
          ['label' s+label.e]
      ==
    =/  base=(list [@t ^json])
      ?~  origin.e  base
      =/  og=parsed-origin:b329  u.origin.e
      =/  path-str=@t
        %-  crip
        %-  zing
        %+  turn  path.og
        |=(s=seg:b329 "/{(trip (render-seg s))}")
      :_  base
      :-  'origin'
      s+(rap 3 ~[(scot %tas type.og) '([' (crip (hexn:http-utils fingerprint.og)) ']' path-str ')'])
    =/  base=(list [@t ^json])
      ?~  spendable.e  base
      [[%spendable b+u.spendable.e] base]
    =/  base=(list [@t ^json])
      ?.  =(~ more.e)  (weld ~(tap by more.e) base)
      base
    (pairs:enjs base)
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
++  entry-from-json
  |=  jon=json
  ^-  label-entry:b329
  ?>  ?=([%o *] jon)
  =/  known=(set @t)  (sy ~['type' 'ref' 'label' 'origin' 'spendable'])
  =/  extra=(map @t json)
    %-  malt
    %+  skip  ~(tap by p.jon)
    |=([k=@t *] (~(has in known) k))
  :*  ;;(label-type:b329 (slav %tas (so:dejs (~(got by p.jon) 'type'))))
      (so:dejs (~(got by p.jon) 'ref'))
      (fall (bind (~(get by p.jon) 'label') so:dejs) '')
      (bind (~(get by p.jon) 'origin') parse-origin)
      =/  sp=(unit json)  (~(get by p.jon) 'spendable')
      ?~(sp ~ ?:(=([%b %.y] u.sp) `%.y ?:(=([%b %.n] u.sp) `%.n ~)))
      extra
  ==
++  parse-origin
  |=  jon=json
  ^-  parsed-origin:b329
  ?>  ?=([%s *] jon)
  =/  raw=tape  (trip p.jon)
  ::  format: wpkh([fingerprint]/path/segments)
  =/  type-end=@ud  (need (find "(" raw))
  =/  stype=@ta  (crip (scag type-end raw))
  =/  inner=tape  (slag +(type-end) raw)
  =/  inner=tape  (scag (dec (lent inner)) inner)
  =/  parts=(list tape)  (split-on inner '/')
  ?>  ?=(^ parts)
  =/  fp-raw=tape  i.parts
  ::  strip brackets from fingerprint
  =/  fp-raw=tape
    ?:  &(=('[' (snag 0 fp-raw)) =(']' (rear fp-raw)))
      (slag 1 (scag (dec (lent fp-raw)) fp-raw))
    ?:  =('[' (snag 0 fp-raw))
      (slag 1 (scag (dec (lent fp-raw)) fp-raw))
    fp-raw
  =/  fp=@ux  (slav %ux (crip fp-raw))
  =/  segs=(list seg:b329)
    %+  turn  t.parts
    |=  s=tape
    ^-  seg:b329
    ?:  =(~ s)  [%.n 0]
    ?:  =("*" s)  [%.n 0]
    ?:  =('\'' (rear s))
      [%.y (slav %ud (crip (scag (dec (lent s)) s)))]
    [%.n (slav %ud (crip s))]
  [;;(script-type:b329 stype) fp segs]
++  render-seg
  |=  s=seg:b329
  ^-  @t
  ?:  p.s  (rap 3 ~[(scot %ud q.s) '\''])
  (scot %ud q.s)
++  split-on
  |=  [txt=tape c=@t]
  ^-  (list tape)
  |-
  =/  idx=(unit @ud)  (find ~[c] txt)
  ?~  idx  ~[txt]
  [(scag u.idx txt) $(txt (slag +(u.idx) txt))]
--
