/<  obelisk-ast  /lib/obelisk-ast.hoon
/<  server-state  /lib/server-state.hoon
/<  obelisk  /lib/obelisk.hoon
=,  obelisk-ast
=,  server-state
|%
++  test-create-database
  =/  now=@da  ~2024.1.1
  =/  our=@p  ~zod
  =/  [res=(list cmd-result) state=db-state]
    (create:obelisk now our %testdb)
  ?>  ?=(^ res)
  ?>  (~(has by state) %testdb)
  =/  db=database  (~(got by state) %testdb)
  ?>  =(name.db %testdb)
  [%& ~]
++  test-create-table-and-insert
  =/  now=@da  ~2024.1.1
  =/  our=@p  ~zod
  =/  [* state=db-state]
    (create:obelisk now our %testdb)
  =/  [* state=db-state]
    %:  exec:obelisk
      state  now  our  %testdb
      "CREATE TABLE db1..my-table (id @ud, name @t)"
    ==
  =/  [res=(list cmd-result) state=db-state]
    %:  exec:obelisk
      state  now  our  %testdb
      "INSERT INTO db1..my-table (id, name) VALUES (1, 'alice')"
    ==
  ?>  ?=(^ res)
  [%& ~]
++  test-select-after-insert
  =/  now=@da  ~2024.1.1
  =/  our=@p  ~zod
  =/  [* state=db-state]
    (create:obelisk now our %testdb)
  =/  [* state=db-state]
    %:  exec:obelisk
      state  now  our  %testdb
      "CREATE TABLE db1..my-table (id @ud, name @t)"
    ==
  =/  [* state=db-state]
    %:  exec:obelisk
      state  now  our  %testdb
      "INSERT INTO db1..my-table (id, name) VALUES (1, 'alice')"
    ==
  =/  [* state=db-state]
    %:  exec:obelisk
      state  now  our  %testdb
      "INSERT INTO db1..my-table (id, name) VALUES (2, 'bob')"
    ==
  =/  [res=(list cmd-result) state=db-state]
    %:  exec:obelisk
      state  now  our  %testdb
      "SELECT * FROM db1..my-table"
    ==
  ?>  ?=(^ res)
  [%& ~]
++  test-pure-state-transitions
  =/  now=@da  ~2024.1.1
  =/  our=@p  ~zod
  =/  [* s1=db-state]  (create:obelisk now our %db1)
  =/  [* s2=db-state]  (create:obelisk now our %db2)
  ?>  (~(has by s1) %db1)
  ?>  !(~(has by s1) %db2)
  ?>  (~(has by s2) %db2)
  ?>  !(~(has by s2) %db1)
  [%& ~]
--
