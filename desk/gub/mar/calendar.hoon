::  calendar: portable calendar intent — config + events
::
::  ^calendar skips the door sample's face to reach the lib import.
::
/<  calendar  /lib/calendar.hoon
|_  =calendar:calendar
++  grab
  |%
  ++  noun  ,calendar:^calendar
  --
++  grow
  |%
  ++  noun  calendar
  ++  json  (calendar-json:^calendar calendar)
  ++  mime
    =/  jon=^json  json
    [/application/json (as-octs:mimes:html (en:json:html jon))]
  --
--
