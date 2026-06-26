::  mark for proc-registry: process bookkeeping for main.sig
::
/<  wt  /lib/wallet-types.hoon
=,  wt
=,  format
|_  dat=proc-registry
++  grab
  |%
  ++  noun  proc-registry
  ++  json
    |=  jon=^json
    ^-  proc-registry
    ?>  ?=([%o *] jon)
    =/  wj  (~(get by p.jon) 'wallets')
    =/  aj  (~(get by p.jon) 'accounts')
    =/  wal-map=(map @t wallet-procs)
      ?~  wj  *(map @t wallet-procs)
      ?>  ?=([%o *] u.wj)
      %-  ~(gas by *(map @t wallet-procs))
      %+  turn  ~(tap by p.u.wj)
      |=  [k=@t v=^json]
      :-  k
      =/  disc=(unit ^json)
        ?.  ?=(%o -.v)  ~
        (~(get by p.v) 'discover')
      [?~(disc ~ ?:(?=([~ %s *] disc) `p.u.disc ~))]
    =/  acct-map=(map @t account-procs)
      ?~  aj  *(map @t account-procs)
      ?>  ?=([%o *] u.aj)
      %-  ~(gas by *(map @t account-procs))
      %+  turn  ~(tap by p.u.aj)
      |=  [k=@t v=^json]
      :-  k
      ?>  ?=([%o *] v)
      =/  sj  (~(get by p.v) 'scan')
      =/  rj  (~(get by p.v) 'refresh')
      :*  ?~(sj ~ ?:(?=([~ %s *] sj) `p.u.sj ~))
          ?~  rj  *(map @ta @ta)
          ?>  ?=([%o *] u.rj)
          %-  ~(gas by *(map @ta @ta))
          %+  turn  ~(tap by p.u.rj)
          |=  [rk=@t rv=^json]
          ?>  ?=([%s *] rv)
          [rk p.rv]
      ==
    [wal-map acct-map]
  ++  mime
    |=  [p=mite q=octs]
    ^-  proc-registry
    (json (need (de:json:html (@t q.q))))
  --
++  grow
  |%
  ++  noun  dat
  ++  json
    ^-  ^json
    %-  pairs:enjs
    :~  :-  'wallets'
        :-  %o
        %-  ~(gas by *(map @t ^json))
        %+  turn  ~(tap by wallets.dat)
        |=  [k=@t v=wallet-procs]
        :-  k
        (pairs:enjs ~[['discover' ?~(discover.v ~ s+u.discover.v)]])
      ::
        :-  'accounts'
        :-  %o
        %-  ~(gas by *(map @t ^json))
        %+  turn  ~(tap by accounts.dat)
        |=  [k=@t v=account-procs]
        :-  k
        %-  pairs:enjs
        :~  ['scan' ?~(scan.v ~ s+u.scan.v)]
            :-  'refresh'
            :-  %o
            %-  ~(gas by *(map @t ^json))
            %+  turn  ~(tap by refresh.v)
            |=  [rk=@ta rv=@ta]
            [rk s+rv]
        ==
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
--
