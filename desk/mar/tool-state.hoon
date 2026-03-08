/+  nex-tools
|_  =tool-state:nex-tools
++  grab
  |%
  ++  noun  tool-state:nex-tools
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
    ==
  ++  mime
    =/  jon=^json  json
    [/application/json (as-octs:mimes:html (en:json:html jon))]
  --
++  grad  %noun
--
