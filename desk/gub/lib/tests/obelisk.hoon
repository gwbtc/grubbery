/<  test  /lib/test.hoon
/<  obelisk-ast  /lib/obelisk-ast.hoon
/<  server-state  /lib/server-state.hoon
/<  obelisk  /lib/obelisk.hoon
/<  parse-lib  /lib/obelisk/parse.hoon
%-  run-tests:test
!>
|%
++  our  ~zod
++  db  %testdb
++  t1  ~2024.1.1
++  t2  ~2024.1.2
++  t3  ~2024.1.3
++  t4  ~2024.1.4
++  t5  ~2024.1.5
::
++  test-create-database
  |.  ^-  tang
  =/  [res=(list cmd-result:obelisk-ast) state=db-state:server-state]
    (create:obelisk t1 our db)
  ;:  weld
    (expect-eq:test !>(%.y) !>(?=(^ res)))
    (expect-eq:test !>(%.y) !>((~(has by state) db)))
  ==
::
++  test-pure-state-transitions
  |.  ^-  tang
  =/  [* s1=db-state:server-state]  (create:obelisk t1 our %db1)
  =/  [* s2=db-state:server-state]  (create:obelisk t1 our %db2)
  ;:  weld
    (expect-eq:test !>(%.y) !>((~(has by s1) %db1)))
    (expect-eq:test !>(%.n) !>((~(has by s1) %db2)))
    (expect-eq:test !>(%.y) !>((~(has by s2) %db2)))
    (expect-eq:test !>(%.n) !>((~(has by s2) %db1)))
  ==
::
++  test-parse-create-database
  |.  ^-  tang
  =/  res  (mule |.((parse:parse-lib(default-database db) "create database foo")))
  ?:  ?=(%| -.res)
    ['test-parse-create-database: crashed' ~]
  =/  cmds=(list command:obelisk-ast)  p.res
  ;:  weld
    (expect-eq:test !>(1) !>((lent cmds)))
    (expect-eq:test !>(%.y) !>(?=([[%create-database *] *] cmds)))
  ==
::
++  test-parse-create-table
  |.  ^-  tang
  =/  res  (mule |.((parse:parse-lib(default-database db) "create table my-table (id @ud, name @t) primary key (id)")))
  ?:  ?=(%| -.res)
    ['test-parse-create-table: crashed' ~]
  (expect-eq:test !>(%.y) !>(?=(^ p.res)))
::
++  test-parse-create-table-qualified
  |.  ^-  tang
  =/  res  (mule |.((parse:parse-lib(default-database db) "create table testdb..my-table (id @ud, name @t) primary key (id)")))
  ?:  ?=(%| -.res)
    ['test-parse-create-table-qualified: crashed' ~]
  (expect-eq:test !>(%.y) !>(?=(^ p.res)))
::
++  test-parse-insert
  |.  ^-  tang
  =/  res  (mule |.((parse:parse-lib(default-database db) "insert into my-table (id, name) values (1, 'alice')")))
  ?:  ?=(%| -.res)
    ['test-parse-insert: crashed' ~]
  (expect-eq:test !>(%.y) !>(?=(^ p.res)))
::
++  test-parse-select
  |.  ^-  tang
  =/  res  (mule |.((parse:parse-lib(default-database db) "from my-table select *")))
  ?:  ?=(%| -.res)
    ['test-parse-select: crashed' ~]
  (expect-eq:test !>(%.y) !>(?=(^ p.res)))
::
++  test-create-table
  |.  ^-  tang
  =/  [* state=db-state:server-state]
    (create:obelisk t1 our db)
  =/  res  (mule |.((exec:obelisk state t2 our db "create table testdb..my-table (id @ud, name @t) primary key (id)")))
  ?:  ?=(%| -.res)
    (flop p.res)
  (expect-eq:test !>(%.y) !>(?=(^ p.res)))
::
++  test-insert
  |.  ^-  tang
  =/  [* state=db-state:server-state]
    (create:obelisk t1 our db)
  =/  res  (mule |.((exec:obelisk state t2 our db "create table testdb..my-table (id @ud, name @t) primary key (id)")))
  ?:  ?=(%| -.res)
    ['test-insert: create table crashed' (flop p.res)]
  =/  [* state=db-state:server-state]  p.res
  =/  res2  (mule |.((exec:obelisk state t3 our db "insert into testdb..my-table (id, name) values (1, 'alice')")))
  ?:  ?=(%| -.res2)
    ['test-insert: insert crashed' (flop p.res2)]
  (expect-eq:test !>(%.y) !>(?=(^ p.res2)))
::
++  test-select
  |.  ^-  tang
  =/  [* state=db-state:server-state]
    (create:obelisk t1 our db)
  =/  res  (mule |.((exec:obelisk state t2 our db "create table testdb..my-table (id @ud, name @t) primary key (id)")))
  ?:  ?=(%| -.res)
    ['test-select: create table crashed' (flop p.res)]
  =/  [* state=db-state:server-state]  p.res
  =/  res2  (mule |.((exec:obelisk state t3 our db "insert into testdb..my-table (id, name) values (1, 'alice')")))
  ?:  ?=(%| -.res2)
    ['test-select: insert crashed' (flop p.res2)]
  =/  [* state=db-state:server-state]  p.res2
  =/  res3  (mule |.((exec:obelisk state t4 our db "from testdb..my-table select *")))
  ?:  ?=(%| -.res3)
    ['test-select: select crashed' (flop p.res3)]
  (expect-eq:test !>(%.y) !>(?=(^ p.res3)))
--
