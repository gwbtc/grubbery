::  usergroups: a set of usergroup paths — e.g. the groups a desk is
::  OPENED to (peek `share.usergroups` to see who may read its code).
::  Grows to json (array of path strings) for UIs; the group paths are
::  real, strings exist only in the json.
::
|_  groups=(set path)
++  grab
  |%
  ++  noun  ,(set path)
  --
++  grow
  |%
  ++  noun  groups
  ++  json  a+(turn ~(tap in groups) |=(g=path s+(spat g)))
  --
--
