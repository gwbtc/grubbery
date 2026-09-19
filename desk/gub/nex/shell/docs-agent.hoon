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
        'Full-text search the Grubbery handbook docs. Returns matching doc filenames and snippet lines.'
        ~[['query' 'the search terms']]  ~['query']
      ==
      %:  mk-tool:clanker  'read_doc'
        'Read one Grubbery handbook doc in full by its filename (as returned by search_docs).'
        ~[['path' 'the doc filename, e.g. intro.md']]  ~['path']
      ==
      %:  mk-tool:clanker  'search_code'
        'Search the Grubbery SOURCE TREE (the root /code nexus — the actual .hoon implementation) for a string. Returns matching lines with file paths + line numbers.'
        ~[['pattern' 'text to search for'] ['path' 'optional path glob to filter files, e.g. /lib/* or *nexus*']]
        ~['pattern']
      ==
      %:  mk-tool:clanker  'read_code'
        'Read a source file from the root /code nexus (the Grubbery source tree). Path like /lib/nexus.hoon or /nex/shell/docs-agent.hoon.'
        ~[['path' 'file path under /code, e.g. /lib/tarball.hoon']]  ~['path']
      ==
      %:  mk-tool:clanker  'search_desk'
        'Search the raw Grubbery Clay desk — the full source desk, including runtime/kernel and non-/code files (marks, man pages, sys.kelvin). Returns matching lines with file paths + line numbers.'
        ~[['pattern' 'text to search for'] ['path' 'optional path glob, e.g. /mar/* or *kelvin*']]
        ~['pattern']
      ==
      %:  mk-tool:clanker  'read_desk'
        'Read a file from the raw Grubbery Clay desk (source desk — includes files not in /code, like marks, man pages, sys.kelvin). Path like /mar/md.hoon.'
        ~[['path' 'file path within the desk, e.g. /mar/md.hoon']]  ~['path']
      ==
  ==
::  +run-loop: the agent loop. Each turn pokes the metering proxy; if the
::  model asks for tools, run them (scoped to the docs) and loop; else return
::  the final text plus a trace of every tool call.
++  system-seed
  ^-  @t
  '''
  You are the Grubbery assistant, embedded in the Grubbery handbook. You can
  search and read both the handbook docs (search_docs, read_doc) AND the
  actual Grubbery source tree — the root /code nexus (search_code, read_code).
  Search first, read the relevant docs or source, then answer from what they
  actually say. Use the handbook for concepts and the source for exact
  implementation detail. If something isn't covered, say so plainly rather
  than guessing. Be concrete and brief, and cite doc or file paths.
  '''
::  +config-seed: default model config, seeded into config.json on load.
++  config-seed
  ^-  json
  %-  pairs:enjs:format
  ~[['model' s+'claude-sonnet-4-6'] ['max_tokens' (numb:enjs:format 1.024)]]
::  +jnum: a json object's numeric field as @ud, or a default.
--
