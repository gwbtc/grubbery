/<  server-state  /lib/server-state.hoon
=,  server-state
|_  =db-state
++  grow
  |%
  ++  noun  db-state
  ++  json
    ^-  ^json
    :-  %a
    %+  turn  ~(tap by db-state)
    |=  [name=@tas =database]
    =/  latest-schema=(unit schema)
      (bind (ram:((on @da schema) gth) sys.database) |=([k=@da v=schema] v))
    =/  latest-data=(unit data)
      (bind (ram:((on @da data) gth) content.database) |=([k=@da v=data] v))
    %-  pairs:enjs:format
    :~  ['name' s+name]
        ['created' s+(scot %da created-tmsp.database)]
        :-  'tables'
        ?~  latest-schema  [%a ~]
        :-  %a
        %+  turn  ~(tap by tables.u.latest-schema)
        |=  [[ns=@tas tbl=@tas] =table]
        =/  rowcount=@ud
          ?~  latest-data  0
          =/  f  (~(get by files.u.latest-data) [ns tbl])
          ?~(f 0 rowcount.u.f)
        %-  pairs:enjs:format
        :~  ['namespace' s+ns]
            ['table' s+tbl]
            ['rowcount' (numb:enjs:format rowcount)]
            :-  'columns'
            :-  %a
            %+  turn  columns.table
            |=  =column:ast
            %-  pairs:enjs:format
            :~  ['name' s+name.column]
                ['type' s+(scot %tas type.column)]
            ==
        ==
    ==
  ++  mime
    ^-  ^mime
    [/application/json (as-octs:mimes:html (en:json:html json))]
  --
++  grab
  |%
  ++  noun  ^db-state
  --
--
