::  feed: a fetched+parsed RSS/Atom feed, stored by the feeds nexus
::
/<  rss  /lib/nex/rss.hoon
|_  =feed-store:rss
++  grab
  |%
  ++  noun  ,feed-store:rss
  --
++  grow
  |%
  ++  noun  feed-store
  ++  json  (store-json:rss feed-store)
  ++  mime
    =/  jon=^json  json
    [/application/json (as-octs:mimes:html (en:json:html jon))]
  --
--
