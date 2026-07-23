::  mar/urb-state.hoon
::
::  Mark for the urb-core block processor's state. Living as a grub
::  lets the groundwire walker peek/over it between blocks, and lets the
::  state be scryable/served via /api/file without a bespoke endpoint.
::
/<  urb  /lib/sur/urb.hoon
|_  state=state:urb
++  grow
  |%
  ++  noun  state
  ++  json
    ^-  ^json
    %-  pairs:enjs:format
    :~  ['height' (numb:enjs:format num.block-id.state)]
        ['hash' s+(en:base16:mimes:html 32^hax.block-id.state)]
        ['sont-count' (numb:enjs:format ~(wyt by sont-map.state))]
        ['insc-count' (numb:enjs:format ~(wyt by insc-ids.state))]
        ['point-count' (numb:enjs:format ~(wyt by unv-ids.state))]
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
++  grab
  |%
  ++  noun  state:urb
  --
--
