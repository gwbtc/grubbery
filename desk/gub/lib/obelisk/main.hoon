/<  ast  /lib/obelisk-ast.hoon
/<  obelisk-types  /lib/obelisk-types.hoon
/<  server-state  /lib/server-state.hoon
/<  sys-views  /lib/obelisk/sys-views.hoon
/<  ddl  /lib/obelisk/ddl.hoon
/<  crud  /lib/obelisk/crud.hoon
/<  parse  /lib/obelisk/parse.hoon
/<  utils  /lib/obelisk/utils.hoon
=,  obelisk-types
=,  server-state
=,  sys-views
=,  ddl
=,  crud
=,  utils
|_  [state=db-state our=@p now=@da eny=@uvJ]
::
++  parse-urql
  |=  [db=@tas script=tape]
  ^-  (list command:ast)
  (parse:parse(default-database db) script)
::
++  process-cmds
  |=  cmds=(list command:ast)
  ~+
  ^-  [(list cmd-result:ast) db-state]
  ::
  ::  to do:
  ::  temporary security prevents all access by foreign ships
  ::  until full persmissions processing implemented
          ?.  =(our our)
            ~|("all access by local agent only" !!)
  ::
  ::  next-schemas and next-data respectively track whether the current script 
  ::  has advanced the schema and data times, respectively.
  ::  If so, schema and data changes at the current schema and data times are
  ::  allowed.
  =/  next-schemas  *(map @tas @da)
  =/  next-data     *(map @tas @da)
  =/  results       *(list cmd-result:ast)
  =/  query-has-run=?  %.n
  |-
  ?~  cmds  :-  (flop results)
                state
  ?-  -<.cmds
    %alter-database
      ?.  =(our our)
            ~|("ALTER DATABASE: database must be renamed by local agent" !!)
      ?:  query-has-run
            ~|("ALTER DATABASE: state change after query in script" !!)
      =/  r=[cmd-result:ast (map @tas @da) (map @tas @da) db-state]
            (alter-db i.cmds next-schemas next-data)
      %=  $
        next-schemas  +<.r
        next-data     +>-.r
        state         +>+.r
        cmds          t.cmds
        results       [-.r results]
      ==
    %alter-index
      ?.  =(our our)
            ~|("ALTER INDEX: schema changes must be by local agent" !!)
      ?:  query-has-run
            ~|("ALTER INDEX: state change after query in script" !!)
      ~|("%alter-index not implemented" !!)
    %alter-namespace
      ?.  =(our our)
            ~|("ALTER NAMESPACE: schema changes must be by local agent" !!)
      ?:  query-has-run
        ~|("ALTER NAMESPACE: state change after query in script" !!)
      =/  r=[cmd-result:ast (map @tas @da) (map @tas @da) db-state]
            (~(alter-ns ddl [state our now eny]) i.cmds next-schemas next-data)
      %=  $
        next-schemas  +<.r
        next-data     +>-.r
        state         +>+.r
        cmds          t.cmds
        results       [-.r results]
      ==
    %alter-table
      ?.  =(our our)
            ~|("ALTER TABLE: schema changes must be by local agent" !!)
      ?:  query-has-run
            ~|("ALTER TABLE: state change after query in script" !!)
      =/  r=[cmd-result:ast (map @tas @da) (map @tas @da) db-state]
            (~(alter-tbl ddl [state our now eny]) i.cmds next-schemas next-data)
      %=  $
        next-schemas  +<.r
        next-data     +>-.r
        state         +>+.r
        cmds          t.cmds
        results       [-.r results]
      ==
    %create-database
      :: create database is exempt from query-has-run
      ?.  =(our our)
            ~|("database must be created by local agent" !!)
      =/  r=[cmd-result:ast (map @tas @da) (map @tas @da) db-state]
            (new-database i.cmds next-schemas next-data)
      %=  $
        next-schemas  +<.r
        next-data     +>-.r
        state         +>+.r
        cmds          t.cmds
        results  [-.r results]
      ==
    %create-index
      ?.  =(our our)
            ~|("CREATE-INDEX: schema changes must be by local agent" !!)
      ?:  query-has-run
        ~|("CREATE-INDEX: state change after query in script" !!)
      ~|("%create-index not implemented" !!)
    %create-namespace
      ?.  =(our our)
            ~|("CREATE NAMESPACE: schema changes must be by local agent" !!)
      ?:  query-has-run
        ~|("CREATE NAMESPACE: state change after query in script" !!)
      =/  r=[cmd-result:ast (map @tas @da) db-state]
            (~(create-ns ddl [state our now eny]) i.cmds next-schemas next-data)
      %=  $
        next-schemas  +<.r
        state         +>.r
        cmds          t.cmds
        results       [-.r results]
      ==
    %create-table
      ?.  =(our our)
            ~|("CREATE TABLE: table must be created by local agent" !!)
      ?:  query-has-run
        ~|("CREATE TABLE: state change after query in script" !!)
      =/  r=[cmd-result:ast (map @tas @da) (map @tas @da) db-state]
            (~(create-tbl ddl [state our now eny]) i.cmds next-schemas next-data)
      %=  $
        next-schemas  +<.r
        next-data     +>-.r
        state         +>+.r
        cmds          t.cmds
        results       [-.r results]
      ==
    %create-view
      ?.  =(our our)
            ~|("CREATE VIEW: schema changes must be by local agent" !!)
      ?:  query-has-run
            ~|("CREATE VIEW: state change after query in script" !!)
      ~|("%create-view not implemented" !!)
    %drop-database
      ?.  =(our our)
            ~|("DROP DATABASE: database must be dropped by local agent" !!)
      ?:  query-has-run
            ~|("DROP DATABASE: state change after query in script" !!)
      =/  cmd=drop-database:ast  i.cmds
      %=  $
        state         (drop-db cmd)
        cmds          t.cmds
        results  :-
                   :-  %results
                       :~  [%action (crip "DROP DATABASE {<name.cmd>}")]
                           [%server-time now]
                           [%message (crip "database {<name.cmd>} dropped")]
                        ==
                   results
      ==
    %drop-index
      ?.  =(our our)
            ~|("DROP INDEX: schema changes must be by local agent" !!)
      ?:  query-has-run  ~|("DROP INDEX: state change after query in script" !!)
      ~|("%drop-index not implemented" !!)
    %drop-namespace
      ?.  =(our our)
            ~|("DROP NAMESPACE: schema changes must be by local agent" !!)
      ?:  query-has-run
        ~|("DROP NAMESPACE: state change after query in script" !!)
      =/  r=[cmd-result:ast (map @tas @da) (map @tas @da) db-state]
            (~(drop-ns ddl [state our now eny]) i.cmds next-schemas next-data)
      %=  $
        next-schemas  +<.r
        next-data     +>-.r
        state         +>+.r
        cmds          t.cmds
        results       [-.r results]
      ==
    %drop-table
      ?.  =(our our)
            ~|("DROP TABLE: table must be dropped by local agent" !!)
      ?:  query-has-run  ~|("DROP TABLE: state change after query in script" !!)
      =/  r=[cmd-result:ast (map @tas @da) (map @tas @da) db-state]
            (~(drop-tbl ddl [state our now eny]) i.cmds next-schemas next-data)
      %=  $
        next-schemas  +<.r
        next-data     +>-.r
        state         +>+.r
        cmds          t.cmds
        results       [-.r results]
      ==
    %drop-view
      ?.  =(our our)
            ~|("DROP VIEW: schema changes must be by local agent" !!)
      ?:  query-has-run  ~|("DROP VIEW: state change after query in script" !!)
      ~|("%drop-view not implemented" !!)
    %grant
      ?.  =(our our)
            ~|("GRANT: grant permissions must be by local agent" !!)
      ~|("%grant not implemented" !!)
    %revoke
      ?.  =(our our)
            ~|("REVOKE: revoke permissions must be by local agent" !!)
      ~|("%revoke not implemented" !!)
    %crud-txn
      =/  r=[? [(map @tas @da) db-state (list result:ast)]]
            %:  ~(do-crud-txn crud [state our now eny])  i.cmds
                                                      query-has-run
                                                      next-data
                                                      next-schemas
                                                      ==
      %=  $
        query-has-run   ?:  query-has-run  %.y  -.r
        next-data       +<.r
        state           +>-.r
        cmds            t.cmds
        results         [[%results +>+.r] results]
      ==
    %truncate-table
      ?:  query-has-run
        ~|("TRUNCATE TABLE: state change after query in script" !!)
      =/  cmd=truncate-table:ast  i.cmds
      =/  r=[cmd-result:ast (map @tas @da) (map @tas @da) db-state]
            (~(truncate-tbl crud [state our now eny]) cmd next-schemas next-data)
      %=  $
        next-schemas  +<.r
        next-data     +>-.r
        state         +>+.r
        cmds          t.cmds
        results       [-.r results]
      ==
  ==
::
++  new-database
  |=  $:  c=create-database:ast
          next-schemas=(map @tas @da)
          next-data=(map @tas @da)
          ==
  ^-  [cmd-result:ast (map @tas @da) (map @tas @da) db-state]
  ?:  =(name.c %sys)            ~|("database name cannot be 'sys'" !!)
  ?:  (~(has by state) name.c)  ~|("database {<name.c>} already exists" !!)
  =/  sys-time  (set-tmsp as-of.c now)
  =/  ns=namespaces  (my ~[[%sys sys-time] [%dbo sys-time]])
  =/  db-views
        %-  limo  :~  :-  [%sys %namespaces sys-time]
                          %-  apply-ordering
                              (sys-namespaces-view +<.c / sys-time)
                      :-  [%sys %tables sys-time]
                          %-  apply-ordering
                              (sys-tables-view +<.c / sys-time)
                      :-  [%sys %table-keys sys-time]
                          %-  apply-ordering
                              (sys-table-keys-view +<.c / sys-time)
                      :-  [%sys %foreign-keys sys-time]
                          %-  apply-ordering
                              (sys-foreign-keys-view +<.c / sys-time)
                      :-  [%sys %columns sys-time]
                          %-  apply-ordering
                              (sys-columns-view +<.c / sys-time)
                      :-  [%sys %sys-log sys-time]
                          %-  apply-ordering
                              (sys-sys-log-view +<.c / sys-time)
                      :-  [%sys %data-log sys-time]
                          %-  apply-ordering
                              (sys-data-log-view +<.c / sys-time)
                      ==
  =/  vws=views  (gas:view-key *((mop ns-rel-key view) ns-rel-comp) db-views)
  ::
  =/  sys-db  ?:  (~(has by state) %sys)  (~(got by state) %sys)     
              %:  mk-db        ::  first time add sys database
                    %sys
                    (my ~[[%sys sys-time]])
                    sys-time
                    :~  :-  [%sys %databases sys-time]
                            %-  apply-ordering
                                (sys-sys-dbs-view / sys-time)
                        ==
                    ==
  =.  event-log.sys-db
        ^-  (list sys-log-event)
        :-  :*  %sys-log-event
                sys-time
                /
                %create
                %database
                name.c
                ~
                ~
                ~
                ~
                ~
                ~
                    ==
            event-log.sys-db
  =.  sys-db  ?:  =(created-tmsp.sys-db sys-time)  sys-db
  sys-db(view-cache (upd-view-caches state sys-db sys-time ~ %create-database))
  =.  state  (~(put by state) %sys sys-db)
  ::
  :-  :-  %results
          :~  [%message (crip "created database {<name.c>}")]
              [%server-time now]
              [%schema-time sys-time]
              ==
      :+  (~(put by next-schemas) name.c sys-time)
          (~(put by next-data) name.c sys-time)
          (~(put by state) name.c (mk-db name.c ns sys-time db-views))
::
++  alter-db
  |=  $:  c=alter-database:ast
          next-schemas=(map @tas @da)
          next-data=(map @tas @da)
          ==
  ^-  [cmd-result:ast (map @tas @da) (map @tas @da) db-state]
  ?:  =(%sys name.c)          ~|("database %sys cannot be renamed" !!)
  =/  db  ~|  "database {<name.c>} does not exist"
              (~(got by state) name.c)
  ?:  (~(has by state) new-name.c)
    ~|("database {<new-name.c>} already exists" !!)
  =/  sys-time=@da  now
  =/  nxt-schema=schema
        ~|  "ALTER DATABASE: {<name.c>} schema time out of order"
            %:  get-next-schema  sys.db
                                 next-schemas
                                 sys-time
                                 name.c
                                 ==
  =.  name.db  new-name.c
  =/  db-views
        %-  limo  :~  :-  [%sys %namespaces sys-time]
                          %-  apply-ordering
                              (sys-namespaces-view new-name.c / sys-time)
                      :-  [%sys %tables sys-time]
                          %-  apply-ordering
                              (sys-tables-view new-name.c / sys-time)
                      :-  [%sys %table-keys sys-time]
                          %-  apply-ordering
                              (sys-table-keys-view new-name.c / sys-time)
                      :-  [%sys %foreign-keys sys-time]
                          %-  apply-ordering
                              %^  sys-foreign-keys-view  new-name.c
                                                         /
                                                         sys-time
                      :-  [%sys %columns sys-time]
                          %-  apply-ordering
                              (sys-columns-view new-name.c / sys-time)
                      :-  [%sys %sys-log sys-time]
                          %-  apply-ordering
                              (sys-sys-log-view new-name.c / sys-time)
                      :-  [%sys %data-log sys-time]
                          %-  apply-ordering
                              (sys-data-log-view new-name.c / sys-time)
                      ==
  =.  views.nxt-schema       (gas:view-key views.nxt-schema db-views)
  =.  tmsp.nxt-schema        sys-time
  =.  provenance.nxt-schema  /
  =.  sys.db                 (put:schema-key sys.db sys-time nxt-schema)
  =.  view-cache.db
        %^  next-view-cache-keys
            db
            sys-time
            :~  [%sys %namespaces]
                [%sys %tables]
                [%sys %table-keys]
                [%sys %columns]
                [%sys %sys-log]
                [%sys %data-log]
                ==
  =/  sys-db  (~(got by state) %sys)
  =.  event-log.sys-db
        ^-  (list sys-log-event)
        :-  :*  %sys-log-event
                sys-time
                /
                %alter
                %database
                name.c
                ~
                ~
                `new-name.c
                ~
                ~
                `(crip "renamed database {<name.c>} to {<new-name.c>}")
                ==
            event-log.sys-db
  =.  view-cache.sys-db  %:  upd-view-caches  state
                                              sys-db
                                              sys-time
                                              ~
                                              %alter-database
                                              ==
  =.  state  (~(put by (~(del by state) name.c)) new-name.c db)
  =.  state  (~(put by state) %sys sys-db)
  :^  :-  %results
          :~  :-  %action
                  (crip "ALTER DATABASE {<name.c>} RENAME TO {<new-name.c>}")
              [%server-time sys-time]
              [%schema-time sys-time]
              [%message (crip "database {<name.c>} renamed to {<new-name.c>}")]
              ==
      (~(put by (~(del by next-schemas) name.c)) new-name.c sys-time)
      (~(put by (~(del by next-data) name.c)) new-name.c sys-time)
      state
::
++  mk-db
  |=  $:  name=@tas
          =namespaces
          sys-time=@da
          db-views=(list [p=ns-rel-key q=view])
          ==
  ^-  database
  =/  vws=views  (gas:view-key *((mop ns-rel-key view) ns-rel-comp) db-views)
  =/  vw-cache
        %+  gas:view-cache-key
              *((mop ns-rel-key cache) ns-rel-comp)
              %+  turn  db-views
                        |=([p=ns-rel-key q=view] [p [%cache time.p ~]])
  ::
  =/  db-schemas=((mop @da schema) gth)  :+  :-  sys-time
                                                 :*  %schema
                                                     /
                                                     sys-time
                                                     namespaces
                                                     ~
                                                     vws
                                                     ==
                                             ~
                                             ~
  :*  %database
      name
      /
      sys-time
      db-schemas
      :+  :-  sys-time
              [%data our / sys-time ~]
          ~
          ~
      vw-cache
      ?:  =(%sys name)  ~[(namespace-event sys-time / name %sys)]
      :~  (namespace-event sys-time / name %dbo)
          (namespace-event sys-time / name %sys)
          ==
      ==
::
++  namespace-event
  |=  [sys-time=@da provenance=path db=@tas namespace=@tas]
  ^-  sys-log-event
  :*  %sys-log-event
      sys-time
      provenance
      %create
      %namespace
      db
      `namespace
      ~
      ~
      ~
      ~
      ~
      ==
::
++  drop-db
  ::  clear content of %sys view keys caches
  |=  drop=drop-database:ast
  ^-  db-state
  ?:  =(%sys name.drop)  ~|("database %sys cannot be dropped" !!)
  =/  db  ~|  "database {<name.drop>} does not exist"
              (~(got by state) name.drop)
  =/  nop
    ?:  force.drop  %.y
      ?.  (is-content-populated db now)  %.y
      ~|("{<name.drop>} has populated tables and `FORCE` was not specified" !!)
  =/  sys-db  (~(got by state) %sys)
  =.  view-cache.sys-db  %+  run:tab:view-cache-key  view-cache.sys-db
                                                     |=(a=cache [%cache +<.a ~])
  (~(del by (~(put by state) %sys sys-db)) name.drop)
::
++  is-content-populated
  |=  [=database sys-time=@da]
  ^-  ?
  =/  content  (tab:content-key content.database ``@da`(add `@`sys-time 1) 1)
  ?~  content  %.n
  =/  d=data  ->.content
  %^  fold  ~(tap by files.d)
            `?`%.n
            |=([[* =file] state=?] ?:(=(0 rowcount.file) state %.y))
--
