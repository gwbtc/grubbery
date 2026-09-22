::  ghostprompter agent: the ghostwriting chatbot as a CONTAINED, sandboxed
::  nexus, following the docs-agent/itinerary-agent pattern. Its weir is set
::  by the ghostprompter nexus when it mounts /agent: it may read the
::  library, write proposals, read the flow from the /apps/nostr mirror,
::  and poke the metered provider proxy — nothing else. Conversation
::  history lives in chats/main.json, durable and inspectable.
/<  clanker  /lib/clanker.hoon
/&  bundle   /lib/ghostprompter-bundle/
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      ::  the sandbox is NOT self-declared here — it is the weir the host
      ::  sets on this nexus in its mount bole (kernel-enforced). This
      ::  on-load only lays out the clanker's tree (see lib/clanker).
      ::  the prompt is PRODUCT CODE here: %over re-lays it every respin
      (spin:loader ball (rows:ck bundle %over))
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
++  ck  ~(. clanker:clanker [%ghostprompter-agent tool-schema system-seed config-seed])
::  +tool-schema: the Anthropic tool schema for the ghostwriting capabilities.
++  tool-schema
  ^-  json
  :-  %a
  :~  ::  server-side web search: runs on Anthropic's end, metered by the
      ::  proxy from usage.server_tool_use.
      (web-search:clanker 3)
      %:  mk-tool:clanker  'get_feed'
        'Read the current nostr timeline (latest posts, newest first). Each line: [age] author-prefix (id ...): content. Use before proposing.'
        ~[['limit' 'how many posts (default 20, max 50)']]  ~
      ==
      %:  mk-tool:clanker  'list_library'
        'List every document in the user\'s library: name, size, line count.'
        ~  ~
      ==
      %:  mk-tool:clanker  'read_doc'
        'Read a library document by name, in ranges: from/to (1-based lines, max 400 per call), or offset/length (bytes, max 40000). No range = first 200 lines + total. find = search string -> matching line numbers, so you can locate a passage then read around it. Books are whole files; always find, then read a range.'
        ~[['name' 'the document name, e.g. montaigne-essays.txt'] ['from' 'first line (1-based)'] ['to' 'last line, inclusive'] ['offset' 'byte offset (alternative to lines)'] ['length' 'bytes from offset'] ['find' 'search string: returns matching line numbers']]  ~['name']
      ==
      %:  mk-tool:clanker  'list_proposals'
        'List the proposals already on the dashboard, so you never file a duplicate.'
        ~  ~
      ==
      %:  mk-tool-typed:clanker  'propose'
        'File a connection on the dashboard: a topic label, raw material, and at most one genuine open question. posts is the flow side (newline-separated "id-prefix | author-prefix | verbatim excerpt" lines); passage is a VERBATIM library passage; source names its document. No other invented text.'
        ~[['topic' 'string' 'a plain noun-phrase label for the shared topic'] ['question' 'string' 'optional: one genuine open question the material raises — never a take in disguise'] ['posts' 'string' 'newline-separated "id | author | verbatim excerpt" lines from get_feed output'] ['post_ids' 'string[]' 'the FULL ids of the cited posts (get_feed prints them)'] ['passage' 'string' 'one passage copied verbatim from a library document'] ['source' 'string' 'the document filename from list_library'] ['from' 'string' 'first line number of the passage (read_doc shows line numbers)'] ['to' 'string' 'last line number of the passage']]
        ~['topic']
      ==
  ==
::  +run-loop: the agent loop. Each turn pokes the metering proxy; if the
::  model asks for tools, run them (scoped by the agent weir) and loop;
::  else return the final text plus a trace of every tool call.
++  system-seed
  ^-  @t
  '''
  You are the ghostprompter: an INDEXER embedded in the user's nostr
  dashboard, never an author. The user follows a live feed (the flow)
  and keeps a library of their own material. Your entire job is to
  identify topics, recurrences, and overlaps — in the flow, in the
  library, and between them — and to surface the raw material side
  by side. The user does all of the thinking and all of the writing.
  You never generate ideas, angles, arguments, opinions, framings,
  takes, or suggested directions. Not in proposals, not in chat.
  The one exception: a connection may carry ONE genuine, open
  question — a question the juxtaposed material actually raises,
  asked to stimulate the user's own thinking. A question that
  smuggles a position, implies its answer, or leads is a take in
  disguise and forbidden. Everything else you file must be a topic
  label (a plain noun phrase) or text copied VERBATIM from sources.
  Method: get_feed for the flow, list_library + read_doc for the
  material, list_proposals to avoid duplicates, then propose. The
  library holds whole books: never read one end to end. Use read_doc
  with find to locate lines on a topic, then read a from/to range
  around a hit. When you propose, give the passage's source filename
  and from/to line numbers, and the full ids of the cited posts —
  the dashboard opens the real post and jumps to the real lines. A
  connection is: a topic label; optionally that one question; the
  flow side (lines of "id-prefix | author-prefix | verbatim excerpt",
  copied exactly from get_feed output); the library side (a passage
  copied exactly from read_doc output, with the document named). One
  side may be empty — a recurring topic within the library alone, or
  within the flow alone, is a valid connection.
  Quality over volume — surface the two or three strongest
  recurrences, not everything. If nothing connects, say so. In chat,
  report what you indexed in one plain sentence per connection;
  do not elaborate, interpret, or recommend.
  '''
::  +config-seed: default model config, seeded into config.json on load.
++  config-seed
  ^-  json
  %-  pairs:enjs:format
  ~[['model' s+'claude-sonnet-4-6'] ['max_tokens' (numb:enjs:format 2.048)]]
::  +jnum: a json object's numeric field as @ud, or a default.
--
