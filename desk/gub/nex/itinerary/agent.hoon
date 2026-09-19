::  itinerary agent: the travel-map chatbot as a CONTAINED, sandboxed nexus,
::  following the docs-agent pattern (nex/shell/docs-agent.hoon). Its weir is
::  set by the itinerary nexus when it mounts it INSIDE a trip dir
::  (/itineraries/<id>/agent): it may read and write its own trip dir and
::  poke the metered provider proxy — nothing else. One agent per trip;
::  conversation history lives in chats/main.json, durable and inspectable.
/<  clanker  /lib/clanker.hoon
/&  bundle   /lib/itinerary-bundle/
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      ::  the sandbox is NOT self-declared here — it is the weir the host
      ::  sets on this nexus in its mount bole (kernel-enforced). This
      ::  on-load only lays out the clanker's tree (see lib/clanker).
      (spin:loader ball (rows:ck bundle %fall))
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          [~ %'main.sig']
        (serve:ck rail prod)
      ==
    --
|%
::  the clanker door, configured with this agent's schema and seeds
++  ck  ~(. clanker:clanker [%itinerary-agent tool-schema system-seed config-seed])
::  +tool-schema: the Anthropic tool schema for the itinerary capabilities.
++  tool-schema
  ^-  json
  :-  %a
  :~  ::  server-side web search: runs on Anthropic's end, no ship plumbing;
      ::  metered by the proxy from usage.server_tool_use.
      (web-search:clanker 3)
      %:  mk-tool:clanker  'read_itinerary'
        'Read this trip\'s itinerary document in full. Returns its JSON: name, desc, dates, tz, center, zoom, categories, pins, zones, schedule, todos.'
        ~  ~
      ==
      %:  mk-tool:clanker  'write_entry'
        'Add or update a pin or zone. entry is the JSON object as a string. Pin: {"name","lat","lng","cat","desc","from":[],"notes"}. Zone: {"name","cat","points":[[lat,lng],...],"desc","notes"} (3+ points). cat must be one of the itinerary categories.'
        ~[['field' '"pins" or "zones"'] ['id' 'the entry id, kebab-case'] ['entry' 'the pin or zone as a JSON object string']]
        ~['field' 'id' 'entry']
      ==
      %:  mk-tool:clanker  'delete_entry'
        'Delete a pin or zone from an itinerary.'
        ~[['field' '"pins" or "zones"'] ['id' 'the entry id to delete']]
        ~['field' 'id']
      ==
      %:  mk-tool:clanker  'write_field'
        'Set ANY field in the itinerary document by slash path: "desc" (markdown trip notes), "name", "center", "zoom", "categories/<key>" ({"label","color"}), or nested paths like "pins/<id>/notes". value is JSON as a string. Empty path replaces the whole document.'
        ~[['path' 'slash path from the document root'] ['value' 'the new value as a JSON string']]
        ~['path' 'value']
      ==
      %:  mk-tool:clanker  'geocode'
        'Exact coordinates/addresses from OpenStreetMap. kind "search": place name or address (include the city) -> candidates with lat/lon; polygon "true" adds boundary geometry for districts/parks (zones). kind "reverse": lat + lon -> the place/address at that point. kind "nearby": every POI with an osm tag (shop:tobacco, amenity:fuel, amenity:pharmacy...) within radius meters of lat/lon — use for "nearest X" questions. ALWAYS use this instead of guessing coordinates.'
        ~[['kind' '"search", "reverse" or "nearby"'] ['query' 'search: place name or address'] ['lat' 'reverse/nearby: latitude'] ['lon' 'reverse/nearby: longitude'] ['polygon' 'search: "true" for boundary geometry'] ['featuretype' 'search: "settlement" biases to districts/neighborhoods — use with polygon for zones'] ['tag' 'nearby: osm tag key:value, e.g. shop:tobacco'] ['radius' 'nearby: meters (default 1500)']]
        ~['kind']
      ==
      %:  mk-tool:clanker  'delete_field'
        'Delete any field from the itinerary document by slash path, e.g. "categories/landmark" or "pins/old-pin".'
        ~[['path' 'slash path from the document root']]
        ~['path']
      ==
      ::  attachments: this trip's files/, the same dir the app's Files tab
      ::  manages. Paths are relative to it and cannot escape it.
      %:  mk-tool:clanker  'list_files'
        'List this trip\'s attached files (uploads and notes). path is an optional subfolder relative to the files root; folders end in "/". Shows mime type and size per file.'
        ~[['path' 'optional subfolder, relative to the files root']]
        ~
      ==
      %:  mk-tool:clanker  'read_file'
        'Read one attached file. path is relative to the files root, e.g. "notes.md" or "tickets/train.txt". Text files return content; binaries (images, PDFs) return only type and size.'
        ~[['path' 'file path relative to the files root']]
        ~['path']
      ==
      %:  mk-tool:clanker  'write_file'
        'Write (create or overwrite) a text file among the attachments: notes, packing lists, research, csv. path is relative to the files root, folders are created as needed. Text only — the user uploads binaries from the Files tab.'
        ~[['path' 'file path relative to the files root'] ['content' 'the text content']]
        ~['path' 'content']
      ==
      %:  mk-tool:clanker  'delete_file'
        'Delete an attached file or a whole subfolder. path is relative to the files root. Cannot delete the root.'
        ~[['path' 'file or folder path relative to the files root']]
        ~['path']
      ==
  ==
::  +run-loop: the agent loop. Each turn pokes the metering proxy; if the
::  model asks for tools, run them (scoped by the agent weir) and loop; else return
::  the final text plus a trace of every tool call.
++  system-seed
  ^-  @t
  '''
  You are the assistant for ONE trip, embedded in a travel-map app. The
  trip's itinerary is a JSON document of pins (points of interest) and
  zones (outlined areas), each with a category, description, and notes.
  You can read it, and edit ANY part of the document: pins and zones
  (write_entry, delete_entry) and everything else — trip description,
  categories, name, map center — via write_field/delete_field. A pin's cat
  must be an existing category key; create the category (write_field on
  categories/<key>) before pinning into it. When the user asks to add a
  place, use the geocode tool for exact coordinates and addresses — never
  guess them; reverse-geocode to answer "what is at these coordinates".
  For zones: first try geocode with polygon "true" (add featuretype
  "settlement" for districts) to get the real boundary — simplify long
  rings to ~20 points before writing. If no polygon exists, pick 4-8
  anchor points yourself (corners, intersections, landmarks that bound
  the area), geocode EACH one, and use those coordinates as the zone's
  points in walk order — never invent vertex coordinates freehand.
  The doc may also carry dates {start, end}, tz, and a schedule map:
  {id: {title, date (YYYY-MM-DD), start/end (HH:MM, local to tz),
  status "fixed" or "tentative", pin (optional pin id), notes}}. Color
  and filtering come from the linked pin's category. A todos map may
  also exist: {id: {text, done (bool)}} — the trip checklist; check
  items off by setting done true, never by deleting them.
  When proposing activities, write them into free gaps as status
  "tentative" (write_field on schedule/<id>) — never move or overwrite
  fixed blocks; the user confirms by flipping tentative to fixed. An
  entry with an EMPTY date sits in the idea bank (unslotted proposals);
  slot one by setting its date.
  The trip also has attachments — files the user uploaded (tickets,
  PDFs, images) or you wrote — reachable with list_files, read_file,
  write_file and delete_file, all relative to the trip's files root.
  Use them for material that doesn't belong in the document: longer
  research, a packing list, a day-by-day writeup (markdown). read_file on
  an image or PDF shows you the actual picture/document — use it to read
  photographed schedules, tickets and maps, and cite the file as the
  source.
  In notes, state where information comes from explicitly as "— source: X"
  and attribute your own inferences to "AI assistant".
  Pick the best-fitting existing category and write the pin. Use
  web_search when freshness matters — opening hours, prices, whether a
  place still exists — not for geography you already know. Read the
  itinerary first so ids, categories and existing entries inform your
  edit. Keep descriptions short and concrete. Confirm what you changed in
  one sentence. If a request is ambiguous, ask.
  '''
::  +config-seed: default model config, seeded into config.json on load.
++  config-seed
  ^-  json
  %-  pairs:enjs:format
  ~[['model' s+'claude-sonnet-4-6'] ['max_tokens' (numb:enjs:format 1.024)]]
::  +jnum: a json object's numeric field as @ud, or a default.
--
