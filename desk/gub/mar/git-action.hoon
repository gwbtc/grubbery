/<  git-action  /lib/git/action.hoon
|_  =action-state:git-action
++  grab
  ::  decode through +read-action-state, never a hard mold: a stored noun
  ::  that does not match the current type starts empty instead of booming.
  |%
  ++  noun  |=(n=* (read-action-state:git-action n))
  --
++  grow
  |%
  ++  noun  action-state
  ++  json  (state-to-json:git-action action-state)
  ++  mime
    [/application/json (as-octs:mimes:html (en:json:html json))]
  --
--
