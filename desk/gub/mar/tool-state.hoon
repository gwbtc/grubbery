/<  tools  /lib/tools.hoon
|_  =tool-state:tools
++  grab
  |%
  ++  noun  tool-state:tools
  --
++  grow
  |%
  ++  noun  tool-state
  ++  json
    ^-  ^json
    %-  pairs:enjs:format
    :~  ['tool' s+tool.tool-state]
        ['step' s+step.tool-state]
        ['data' data.tool-state]
        ['args' [%o args.tool-state]]
        ['update' ?~(update.tool-state ~ u.update.tool-state)]
    ==
  ++  mime
    =/  jon=^json  json
    [/application/json (as-octs:mimes:html (en:json:html jon))]
  --
--
