::  docs-agent: the grubbery docs chatbot as a CONTAINED, sandboxed nexus.
::  Its weir.json IS the sandbox — the WHOLE agent (turn handler and tools)
::  runs bounded by it: it may only READ /docs, the root /code nexus, and
::  the raw grubbery desk source, and POKE the metered provider proxy.
::  Conversation history lives in chats/ as grubs — durable and inspectable.
::  Built on lib/clanker — the shared chatbot toolkit.
/<  clanker  /lib/clanker.hoon
/&  bundle   /lib/docs-bundle/
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
++  ck  ~(. clanker:clanker [%docs-agent tool-schema system-seed config-seed])
::  +tool-schema: the Anthropic tool schema for the docs capabilities.
++  tool-schema
  ^-  json
  :-  %a
  :~  %:  mk-tool:clanker  'search_docs'
        'Full-text search the handbook docs. Returns matching doc filenames and snippet lines.'
        ~[['query' 'the search terms']]  ~['query']
      ==
      %:  mk-tool:clanker  'read_doc'
        'Read one handbook doc in full by its filename (as returned by search_docs), e.g. intro.md.'
        ~[['path' 'the doc filename, e.g. intro.md']]  ~['path']
      ==
      %:  mk-tool:clanker  'search_source'
        'Search the documented target SOURCE — the whole mirrored desk (the actual .hoon implementation plus marks, man pages, sys files). Returns matching lines with file paths + line numbers.'
        ~[['pattern' 'text to search for'] ['path' 'optional path glob to filter files, e.g. /gub/lib/* or *nexus*']]
        ~['pattern']
      ==
      %:  mk-tool:clanker  'read_source'
        'Read a source file from the documented target (the mirrored desk). Path relative to the collection root, e.g. /gub/lib/nexus.hoon, /mar/md.hoon, or /sys.kelvin.'
        ~[['path' 'file path within the target, e.g. /gub/lib/nexus.hoon']]  ~['path']
      ==
  ==
::  +run-loop: the agent loop. Each turn pokes the metering proxy; if the
::  model asks for tools, run them (scoped to the docs) and loop; else return
::  the final text plus a trace of every tool call.
++  system-seed
  ^-  @t
  '''
  You are the documentation assistant, embedded in a Grubbery handbook. You
  read from a local mirror of the documented project: its handbook docs
  (search_docs, read_doc) AND its full source — the whole mirrored desk, the
  actual .hoon implementation plus marks and sys files (search_source,
  read_source). Search first, read the relevant docs or source, then answer
  from what they actually say. Use the handbook for concepts and the source for
  exact implementation detail. If something isn't covered, say so plainly
  rather than guessing. Be concrete and brief, and cite doc or file paths.
  '''
::  +config-seed: default model config, seeded into config.json on load.
++  config-seed
  ^-  json
  %-  pairs:enjs:format
  ~[['model' s+'claude-sonnet-4-6'] ['max_tokens' (numb:enjs:format 1.024)]]
::  +jnum: a json object's numeric field as @ud, or a default.
--
