/<  git-action  /lib/git/action.hoon
|_  =action-state:git-action
++  grab
  |%
  ++  noun  action-state:git-action
  --
++  grow
  |%
  ++  noun  action-state
  ++  json  (state-to-json:git-action action-state)
  ++  mime
    [/application/json (as-octs:mimes:html (en:json:html json))]
  --
--
