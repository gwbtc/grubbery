/<  ast  /lib/obelisk-ast.hoon
/<  obelisk-types  /lib/obelisk-types.hoon
/<  server-state  /lib/server-state.hoon
/<  main  /lib/obelisk/main.hoon
/<  parse-lib  /lib/obelisk/parse.hoon
=,  obelisk-types
=,  server-state
|%
++  exec
  |=  [state=db-state now=@da our=@p db=@tas script=tape]
  ^-  [(list cmd-result:ast) db-state]
  =/  eng  ~(. main [state our now eny=0v0])
  =/  cmds=(list command:ast)  (parse-urql:eng db script)
  (process-cmds:eng cmds)
++  create
  |=  [now=@da our=@p name=@tas]
  ^-  [(list cmd-result:ast) db-state]
  (exec *db-state now our name "CREATE DATABASE {(trip name)}")
--
