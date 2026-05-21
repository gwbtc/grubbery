::  claw nexus: self-building AI agent
::
/<  nex-tools     /lib/nex/tools.hoon
/<  iso-8601      /lib/iso-8601.hoon
/<  cron          /lib/cron.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])
        =/  default-config=json
          %-  pairs:enjs:format
          :~  ['model' s+'claude-sonnet-4-20250514']
              ['api-proxy' s+'anthropic']
              ['context_window' (numb:enjs:format 80.000)]
              ['message_cap' (numb:enjs:format 20.000)]
              ['channel' s+'']
          ==
        =/  default-prompt=wain
          :~  'You are an AI assistant running inside the grubbery system on an Urbit ship.'
              ''
              '# What you are'
              ''
              'Three things to understand:'
              ''
              '  Ball = the filesystem. A tree of directories and files, all in memory.'
              '  Nexus = a program that governs a directory. Identified by a "neck" on the dir.'
              '  Fiber = a running process attached to a file. Your event loop.'
              ''
              'You are a fiber process running inside a claw agent nexus. Your nexus owns'
              'a directory in the ball with all your files: chat, prompts, code,'
              'tools, and children. Everything is persistent across sessions.'
              ''
              'IMPORTANT: You have reference documentation in your filesystem at ./context/docs/.'
              'READ THESE FIRST when you need to understand the system, write code, or debug.'
              '  read road="./context/docs/grubbery-fundamentals.txt"  -- full architecture'
              '  read road="./context/docs/workflows.txt"              -- step-by-step guides'
              'These are files YOU can read. They are NOT the same as read_manual.'
              'read_manual queries live nexus documentation for a specific path.'
              'The docs in ./context/docs/ are comprehensive written guides for you.'
              ''
              '# Your filesystem'
              ''
              '  ./config.json              -- config (model, api-proxy, context_window, message_cap, channel)'
              '  ./page.html                -- your web UI'
              '  ./about.txt                -- your self-description (visible to other agents)'
              '  ./context/                 -- shared context (across all chats)'
              '    prompts/                 -- system prompt files (concatenated alphabetically)'
              '    memories/                -- persistent notes you write to remember things'
              '    docs/                    -- YOUR REFERENCE DOCS. Read these! (see above)'
              '  ./chats/main/              -- your primary chat instance'
              '    chat.json               -- conversation log + event loop (pokes arrive here)'
              '    outbox.json             -- append-only log; outbox tool writes here'
              '    status.json             -- current status (idle/api/tool)'
              '  ./proc/tools/              -- active tool processes (DO NOT write source here)'
              '  ./proc/cron/               -- active cron job processes (managed by cron_add/remove)'
              '  ./apps/                    -- your applications and code'
              '    code/                    -- your build scope (compiled by the grubbery build system)'
              '      nex/                   -- nexus source code'
              '      lib/                   -- libraries'
              '        tools/               -- dynamic tool definitions (.hoon files)'
              '      mar/                   -- mark definitions'
              '  ./children/                -- spawned child nexuses'
              ''
              '# Tools overview'
              ''
              '## File operations'
              '- browse: list directory contents'
              '- read: read a file (supports offset/limit for line ranges)'
              '- write: write a file'
              '- edit: exact string replacement in a file'
              '- delete: delete a file'
              '- mkdir: create a directory'
              '- grep: search file contents by pattern (supports path/name/mark globs)'
              '- glob: find files by path/name/mark patterns'
              ''
              '## Conversation history'
              'Your conversation has a sliding window -- older messages drop out of context.'
              'Use these tools to search and recall beyond the window:'
              '- grep_history: search the FULL conversation (all messages ever, not just'
              '  the current window) by substring. Returns matching lines with message indices.'
              '- recall_messages: insert a [ref:N-M] marker that pulls old messages back'
              '  into the current context at assembly time.'
              '- summarize: send a message range to the LLM for targeted summarization.'
              '  Always specify what kind of summary (process, decisions, technical, action-items).'
              ''
              '## Code and building'
              '- check_bin: verify that code compiles. Use after every write to code.'
              '  Takes a directory path and file stem (e.g. path="./apps/code/nex/foo" name="app").'
              '  Returns compilation errors if it fails.'
              '- check_bang: read the error state of a process. Every fiber process can crash;'
              '  when it does, the crash trace is stored as its "bang." This tool reads that.'
              '  A bang means the process at that path has crashed and needs fixing.'
              '- read_manual: query the on-manu arm of the nexus governing a path.'
              '  Returns live documentation embedded in nexus code about what a path does.'
              '  Different from ./context/docs/ which are static reference guides you read directly.'
              '- read_font: find which code namespace (./apps/code/) is responsible for'
              '  compiling the code that governs a given path.'
              ''
              '## Nexus management'
              '- create_nexus: create a child nexus in ./children/ from compiled code.'
              '  The "code" arg refers to a nexus in your code namespace (e.g. "my-thing/app"'
              '  for ./apps/code/nex/my-thing/app.hoon). The nexus must compile first.'
              '- delete_nexus: remove a child nexus and all its contents.'
              '- spawn_task: create a temporary child claw agent to handle a task.'
              '  The child gets its own conversation, runs the task, and returns the result.'
              '  Different from create_nexus: spawn_task creates another claw agent, while'
              '  create_nexus instantiates custom nexus code you wrote.'
              '- outbox: append to outbox.json to return results to a parent (used by spawned tasks).'
              ''
              '## Sandbox (weir)'
              'Weirs restrict what darts (effects) can pass through a directory.'
              'Darts travel UP through the tree, so a weir blocks operations that try'
              'to reach OUTSIDE the sandboxed area. No weir = fully permissive.'
              'A "veto" error means a weir somewhere along the path blocked your operation.'
              '- read_weir: see sandbox permissions for a directory'
              '- add_weir / del_weir / clear_weir: manage sandbox rules'
              ''
              '## Cron jobs'
              '- cron_add: schedule a recurring message to a chat using cron expressions'
              '  Format: "min hour dom month dow" (e.g. "0 9 * * *" for daily 9am UTC)'
              '- cron_list: list all active cron jobs'
              '- cron_remove: remove a cron job by ID'
              ''
              '# Building nexuses'
              ''
              'A nexus is Hoon code that produces a `nexus:nexus` core with three arms:'
              ''
              '## on-load: initialize the filesystem'
              '  |=  [=sand:nexus =gain:nexus =ball:tarball]'
              '  ^-  [sand:nexus gain:nexus ball:tarball]'
              ''
              'Called when the nexus is created or its code changes. Use the loader to'
              'set up files and directories. Key loader operations:'
              '  %fall -- create file/dir only if absent (keeps existing data on reload)'
              '  %over -- overwrite file/dir unconditionally (resets on reload)'
              '  ver-row:loader -- version tracking for schema migrations'
              ''
              '## on-file: define fiber processes'
              '  |=  [=rail:tarball =mark]'
              '  ^-  spool:fiber:nexus'
              ''
              'Pattern-matches on [path name] to spawn fiber processes. Each process is'
              'an event loop using the fiber monad (;<  result  bind:m  action).'
              ''
              'Common pattern for main.sig (poke handler):'
              '  [~ %main.sig]'
              '  ;<  ~  bind:m  (rise-wait:io prod "failed")'
              '  |-'
              '  ;<  =sage:tarball  bind:m  take-poke:io'
              '  :: handle the poke...'
              '  $  :: loop back for next poke'
              ''
              'Common pattern for reactive files (re-render on changes):'
              '  [[%ui ~] %page.html]'
              '  ;<  init=view:nexus  bind:m  (keep:io /wire some-road ~)'
              '  :: render initial state'
              '  |-'
              '  ;<  upd=view:nexus  bind:m  (take-news:io /wire)'
              '  :: re-render on change'
              '  $'
              ''
              '## on-manu: documentation'
              '  |=  =mana:nexus'
              '  ^-  @t'
              ''
              'Returns documentation strings for paths and files. Queried by read_manual.'
              ''
              '# Key fiberio operations'
              ''
              'All fiber IO uses the pattern: ;<  result  bind:m  (action:io args)'
              ''
              '  peek:io road mark          -- read a file or directory'
              '  peek-exists:io road        -- check if something exists'
              '  make:io road make-spec     -- create a file or directory'
              '  over:io road sage          -- overwrite file content'
              '  cull:io road               -- delete a file or directory'
              '  poke:io road sage          -- send data to another process'
              '  take-poke:io               -- wait for incoming poke'
              '  keep:io wire road mark     -- subscribe to changes'
              '  take-news:io wire          -- wait for subscription update'
              '  drop:io wire road          -- unsubscribe'
              '  replace:io vase            -- overwrite own file content'
              '  get-state-as:io ,type      -- read own content, cast to type'
              '  copy-grub:io src dst       -- copy a file'
              '  copy-fold:io src dst       -- copy a directory'
              '  sleep:io time              -- wait'
              '  get-our:io                 -- get ship name'
              '  get-time:io                -- get current time'
              '  get-here:io                -- get own location (here:nexus)'
              '  get-here:io            -- get absolute rail (crashes if blocked)'
              '  rise-wait:io prod msg      -- crash handler (put at top of process)'
              ''
              '# Build system'
              ''
              'Code lives in ./apps/code/. The grubbery build system compiles it.'
              ''
              'To write and test code:'
              '1. Write source to ./apps/code/nex/my-thing/app.hoon (or lib/, mar/)'
              '2. check_bin path="/apps/code/nex/my-thing" name="app"'
              '3. If it fails, read the error, fix, write again, check again'
              '4. Once it compiles, create_nexus to instantiate it'
              ''
              'Dynamic tools: write source to ./apps/code/lib/tools/my-tool.hoon'
              'NOT ./proc/tools/ (that is where running processes live, not source code).'
              'Must produce a tool:nex-tools core (name, description, parameters, required, handler).'
              'Available immediately after check_bin passes.'
              ''
              '# Reference docs'
              ''
              'There are two kinds of documentation:'
              ''
              '1. ./context/docs/ -- files in your namespace you can read directly.'
              '   These are detailed written guides, not generated.'
              '   Read them with: read road="./context/docs/grubbery-fundamentals.txt"'
              '     grubbery-fundamentals.txt  -- architecture from the ground up'
              '     workflows.txt              -- step-by-step guides for common tasks'
              ''
              '2. read_manual -- queries the on-manu arm of the nexus governing a path.'
              '   This is live, contextual documentation embedded in nexus code.'
              '   Each nexus defines what its directories and files do.'
              '   Use it to understand unfamiliar paths: read_manual path="/some/path"'
              ''
              'IMPORTANT: Before attempting to build nexuses, write code, or debug'
              'unfamiliar errors, read the docs in ./context/docs/ first.'
              'Use read_manual when you encounter a specific path and want to know'
              'what it does or what nexus governs it.'
              ''
              '# Key terms'
              ''
              'ball    -- the filesystem tree (all directories and files)'
              'nexus   -- code (program) that governs a directory in the ball'
              'neck    -- the mark on a directory identifying which nexus runs there'
              'fiber   -- a running process attached to a file'
              'dart    -- an effect emitted by a fiber (make, poke, peek, etc.)'
              'weir    -- sandbox rules on a directory that filter darts passing through'
              'bang    -- a crash trace stored on a process that has failed'
              'sage    -- typed file content: [blot vase] (type identity + data)'
              'blot    -- a mark/type identifier (e.g. [/ %json], [/ %txt])'
              'rail    -- path to a file: [directory-path filename]'
              'fold    -- path to a directory'
              'road    -- absolute or relative path reference'
              ''
              '# Guidelines'
              ''
              '- Stay within scope. Respond to conversation directly. Only reach for tools'
              '  and code when the task actually calls for it.'
              '- When building code, always check_bin after writing. Fix errors iteratively.'
              '- Use read_manual to understand what a specific path does.'
              '- Read ./context/docs/ for architecture and workflow guides.'
              '- Write memories to ./context/memories/ to persist important information.'
              '- Use grep_history to search beyond your context window.'
              '- When you hit an error you do not understand, read the docs before guessing.'
          ==
        =/  fundamentals-doc=wain
          :~  'GRUBBERY FUNDAMENTALS'
              '====================='
              ''
              ''
              '## Why Grubbery Exists'
              ''
              'A Gall agent is one flat process managing one blob of state. If you'
              'want many concurrent concerns, you multiplex them yourself -- dispatch'
              'on wires, manage substates, handle interleaving. It gets complex fast.'
              ''
              'Grubbery solves this by putting processes in a tree. Each file is a'
              'process with its own state. The tree structure lets you:'
              '  - Decompose into many small processes, each managing one file'
              '  - Group related processes in directories'
              '  - Let different code govern different subtrees'
              '  - Sandbox naturally via the tree hierarchy'
              '  - Subscribe to any node by path'
              ''
              'The namespace IS the architecture. Instead of designing internal data'
              'structures, you organize your application as a filesystem where every'
              'node is live.'
              ''
              ''
              '## The Ball'
              ''
              'Everything lives in a single in-memory tree called the ball. It is a'
              'hierarchical filesystem: directories contain files and subdirectories.'
              ''
              '  ball = (axal lump)    -- tree of directory nodes'
              '  sage = [blot vase]    -- typed file content (type identity + data)'
              ''
              'Paths in grubbery distinguish files from directories:'
              '  rail = [path name]    -- file: /foo/bar + config.json'
              '  fold = path           -- directory: /foo/bar/'
              '  road                  -- can be absolute or relative'
              ''
              'Common file types (blots):'
              '  [/ %json]   JSON data'
              '  [/ %txt]    text (wain = list of lines)'
              '  [/ %sig]    empty signal (poke endpoints)'
              '  [/ %mime]   binary data with MIME type'
              ''
              ''
              '## Nexuses'
              ''
              'A nexus is code that governs a directory. A directory becomes governed'
              'when it has a "neck" -- a rail identifying which nexus code to use.'
              ''
              'A nexus has three arms:'
              ''
              '  ++on-load   Sets up the directory structure via the loader.'
              '              Called on creation and whenever code reloads.'
              '              Returns [sand gain ball].'
              ''
              '  ++on-file   Determines which fiber process runs at each file.'
              '              Pattern-matches on [rail mark] to dispatch code.'
              '              This is the primary meaning of "governs."'
              ''
              '  ++on-manu   Returns documentation. Queried by read_manual.'
              ''
              'Nexuses nest. An on-load can create subdirectories with their own'
              'necks, spawning child nexuses. Directory names encode the neck:'
              '  server.server/       neck=[/ %server]'
              '  claw.claw_app/       neck=[/claw %app]'
              ''
              ''
              '## Fibers'
              ''
              'A grub is a file in the namespace. It is two things at once:'
              '  1. Typed data -- the sage (blot + vase) stored in the ball'
              '  2. A running process -- the fiber, whose continuation lives in the pool'
              ''
              'The file IS the fiber state. The sage is what the fiber manipulates.'
              'The continuation (the function waiting for next input) is stored'
              'separately by the runtime. Two halves of one thing.'
              ''
              'A fiber is a monadic event loop using ;< bind syntax:'
              '  ;<  result=type  bind:m  (io-action args)'
              '  :: use result, then continue...'
              ''
              'Fibers receive intakes (pokes, subscription updates, etc) and emit'
              'darts (effects that route through the tree).'
              ''
              ''
              '## Darts and Routing'
              ''
              'A dart is an effect emitted by a fiber. Darts route through the tree:'
              ''
              '  1. Resolve destination to an absolute lane'
              '  2. Find the "governor" -- nearest directory strictly ABOVE both'
              '     source and destination (the neutral authority over both)'
              '  3. Walk UP from source to governor, checking weirs at each dir'
              '  4. If any weir blocks the dart -> %veto sent back to source'
              '  5. Downward movement from governor to destination is always free'
              ''
              'Key dart types:'
              '  %make   create file or directory'
              '  %cull   delete file or directory'
              '  %over   overwrite file content'
              '  %peek   read a node (returns a view)'
              '  %poke   send data to a process'
              '  %keep   subscribe to changes'
              '  %drop   unsubscribe'
              '  %manu   query documentation'
              '  %code   look up compiled code'
              '  %bang   query error state'
              ''
              ''
              '## Sandboxing (Weirs)'
              ''
              'A weir is a set of rules on a directory that filters darts passing'
              'through it. It lists allowed destination prefixes for make, poke,'
              'and peek operations separately.'
              ''
              '  No weir = permissive (everything passes)'
              '  Weirs only checked on the way UP (downward is always free)'
              '  Blocked dart -> %veto intake to the sender'
              ''
              'Your agent instance has a weir set by the claw app:'
              '  make = ~        you cannot create/delete OUTSIDE your subtree'
              '  poke = limited  you can poke the system bowl and the API proxy'
              '  peek = /        you can READ the entire tree'
              ''
              'This means: full read access, write only within your own subtree,'
              'poke restricted to specific endpoints.'
              ''
              ''
              '## Code Namespaces'
              ''
              'Directories with neck [/ %code] are code namespaces. Grubbery'
              'compiles Hoon source files in these directories into artifacts.'
              ''
              'A code namespace contains:'
              '  nex/   nexus definitions'
              '  lib/   shared libraries'
              '  mar/   mark (type) definitions'
              ''
              'Code lookup walks UP the tree to find the nearest /code sibling.'
              'It is hermetic: if the nearest code namespace does not have the'
              'artifact, the lookup returns ~ (no fallback to parent namespaces).'
              ''
              'Your build scope is ./apps/code/. Write source there and use'
              'check_bin to compile. Dynamic tools go in ./apps/code/lib/tools/.'
              ''
              ''
              '## Bangs (Errors)'
              ''
              'A bang is a crash trace that replaces normal operation.'
              ''
              'Process-level: when a fiber crashes, its continuation is replaced'
              'with the crash trace. The process is dead; queued inputs sit idle.'
              'A successful respawn (e.g. on code reload) heals it.'
              ''
              'Nexus-level: when on-load itself crashes, the bang cascades to every'
              'file underneath -- the whole subtree is frozen.'
              ''
              'Use check_bang to inspect error state at a path.'
              ''
              ''
              '## Subscriptions'
              ''
              'Fibers can watch other files/directories for changes:'
              '  keep  -> subscribe, receive %bond (ack + initial view)'
              '  news  -> updates when the target changes'
              '  drop  -> unsubscribe, receive %fell (confirmed)'
              '  fell  -> also arrives if the target is deleted or weir breaks it'
              ''
              'Under the hood, the runtime diffs version counters (born) before'
              'and after mutations, finds changed lanes, and delivers %news.'
              ''
              ''
              '## Marks (Blots)'
              ''
              'A blot is a type identity for file content: [/ %json], [/wallet %account].'
              'A marc is a compiled mark core with three arms:'
              '  vale   validate a noun into a vase'
              '  grow   convert outward to another blot'
              '  grab   convert inward from another blot'
              ''
              'Source lives in /mar/ in code namespaces. The runtime validates'
              'content through marc vale on write.'
              ''
              ''
              '## The Seven Structures'
              ''
              'Grubbery maintains seven parallel structures, all keyed by path:'
              '  Ball   data tree (files and directories)'
              '  Pool   process tree (fiber continuations + input queues)'
              '  Born   version counters (basis for subscription system)'
              '  Sand   weir policy tree'
              '  Gain   history policy tree (which files track versions)'
              '  Silo   content-addressed store for historical versions'
              '  Code   compiled artifacts per code namespace'
              ''
              'Ball holds data. Pool holds processes. They mirror each other:'
              'every grub in the ball has a corresponding process in the pool.'
              ''
              ''
              '## Your Place in the Tree'
              ''
              '  / (root)'
              '    code/                    system code namespace'
              '    claw.claw_app/'
              '      agents/'
              '        you.claw_agent/      your instance'
              '          config.json'
              '          main.sig           your event loop'
              '          context/'
              '            chat.json       conversation log'
              '            prompts/'
              '            memories/'
              '            docs/            these docs'
              '          apps/'
              '            code/            YOUR build scope'
              '          tools/             running tool processes'
              '          children/          sub-agent instances'
              ''
              'You are a fiber process at main.sig, governed by the claw agent'
              'nexus. Your filesystem is real and persistent. Files survive across'
              'sessions. Code you write in ./apps/code/ gets compiled. Nexuses you'
              'create in ./apps/ are live programs. Everything is scoped to your'
              'subtree -- nothing you build outlives your agent instance.'
          ==
        =/  workflows-doc=wain
          :~  'COMMON WORKFLOWS'
              '================'
              ''
              ''
              '## Two spaces, two purposes'
              ''
              './apps/ is your application space:'
              '  ./apps/code/          source code (nexus defs, libs, marks, tools)'
              '  ./apps/my-thing/      running nexus instances you create'
              ''
              './children/ is for sub-agents:'
              '  spawn_task creates temporary claw agent instances here'
              '  These are other AIs handling subtasks, NOT custom programs'
              ''
              'You NEVER modify your own nexus code -- it is authored by the developer,'
              'compiled in the parent code namespace, and governs you from above.'
              ''
              ''
              '## Writing a dynamic tool'
              ''
              'A tool is a .hoon file producing a tool:nex-tools core.'
              ''
              '1. write road="./apps/code/lib/tools/my-tool.hoon" mark="hoon"'
              '2. check_bin code_road="./apps/code/" path="/lib/tools" name="my-tool"'
              '3. Read errors, fix, rewrite, check again until it compiles'
              '4. Once compiled, the tool is live -- no restart needed'
              ''
              'The filename can be anything -- the tool is registered by its ++name arm,'
              'not the filename. But convention is to match (with hyphens in filename,'
              'underscores in name).'
              ''
              'A tool core has these arms:'
              '  ++name         @t cord, the tool name users call'
              '  ++description  @t cord, what it does'
              '  ++parameters   (map @t parameter-def:tools), input params'
              '  ++required     (list @t), which params are required'
              '  ++handler      tool-handler:tools, fiber that runs on invocation'
              ''
              'The handler receives tool-state (with args map) via get-state-as:io'
              'and returns a tool-result (%text or %error).'
              ''
              '### Tips'
              ''
              '- Always import the tools library first:'
              '    /<  tools  /lib/nex/tools.hoon'
              '    ^-  tool:tools'
              '  This gives you tool-state:tools, tool-result:tools, parameter-def:tools.'
              ''
              '- For entropy use get-entropy:io (returns @uvJ).'
              '  For current time use get-now:io (returns @da).'
              '  For location use get-here:io (returns rail:tarball).'
              ''
              '- Read args from the tool-state args map:'
              '    ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)'
              '    =/  val  (~(get by args.st) <cord-key>)'
              '  JSON numbers: ?>(?=(%n -.j) (rash p.j dem)) gives @ud'
              '  JSON strings: ?>(?=(%s -.j) p.j) gives @t'
              '  JSON booleans: ?>(?=(%b -.j) p.j) gives ?'
              ''
              '- Write tool files with mark="hoon" so they compile as Hoon source.'
              '  Without mark, files store as raw mime and will not compile.'
              ''
              '- Read existing tools in ./apps/code/lib/tools/ for reference.'
              '  Also read ./apps/code/lib/nex/tools.hoon for the type definitions.'
              ''
              ''
              '## Building a custom nexus'
              ''
              '1. Write the nexus source:'
              '   write path="./apps/code/nex/my-thing/app.hoon"'
              '   Must produce a nexus:nexus core (on-load, on-file, on-manu).'
              ''
              '2. Compile:'
              '   check_bin path="./apps/code/nex/my-thing" name="app"'
              '   Fix errors iteratively until it builds.'
              ''
              '3. Instantiate:'
              '   create_nexus name="my-instance" code="my-thing/app"'
              '   Creates ./apps/my-instance/ with a neck pointing to your code.'
              '   on-load runs and sets up its filesystem.'
              ''
              '4. Interact:'
              '   Use write/read on files in ./apps/my-instance/'
              '   The instance is a live program with its own processes.'
              ''
              'The code arg in create_nexus is the path within your code namespace'
              '(./apps/code/nex/), NOT a filesystem path.'
              ''
              ''
              '## Common mistakes'
              ''
              '- Writing source to ./proc/tools/ -- that holds running tool PROCESSES,'
              '  not source code. Source goes in ./apps/code/lib/tools/.'
              ''
              '- Manually writing files into nexus instances. Use create_nexus to'
              '  instantiate, then interact through its own files.'
              ''
              '- Confusing the three layers: ball = data, nexus = code, fiber ='
              '  process. You are a fiber, governed by a nexus, in the ball.'
              ''
              '- check_bin takes a directory path + file stem, not a file path.'
              '  E.g. path="./apps/code/nex/foo" name="app".'
              ''
              '- Writing the wrong type to a typed file. Files have typed content'
              '  (sage = blot + vase). Type mismatches crash.'
              ''
              '- Trying to poke or create outside your subtree. Your weir blocks'
              '  it -- you will get a %veto. Use check_bang to inspect errors.'
          ==
        =/  default-conv=json  [%a ~]
        =/  code-dir=ball:tarball  [`[~ `[/ %code] ~] ~]
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%fall %& [/ %'config.json'] %.n [~ [/ %json] !>(default-config)]]
            ::  /main.sig: chat lifecycle + message routing
            [%over %& [/ %'main.sig'] %.n [~ [/ %sig] !>(~)]]
            ::  /chats/main: primary chat instance
            [%fall %| /chats [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /chats/main [~ ~] [~ ~] empty-dir:loader]
            [%fall %& [/chats/main %'chat.json'] %.n [~ [/ %json] !>(default-conv)]]
            [%fall %& [/chats/main %'outbox.json'] %.n [~ [/ %json] !>([%a ~])]]
            [%over %& [/chats/main %'status.json'] %.n [~ [/ %json] !>((pairs:enjs:format ~[['state' s+'idle']]))]]
            ::  /proc/tools: tool execution (flat, [chat]_[tid] naming)
            [%fall %| /proc [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /proc/tools [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /proc/cron [~ ~] [~ ~] empty-dir:loader]
            ::  /context: shared prompts, memories, docs
            [%fall %| /context [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /context/prompts [~ ~] [~ ~] empty-dir:loader]
            [%fall %& [/context/prompts %'main.txt'] %.n [~ [/ %txt] !>(default-prompt)]]
            [%fall %| /context/memories [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /context/docs [~ ~] [~ ~] empty-dir:loader]
            [%over %& [/context/docs %'grubbery-fundamentals.txt'] %.n [~ [/ %txt] !>(fundamentals-doc)]]
            [%over %& [/context/docs %'workflows.txt'] %.n [~ [/ %txt] !>(workflows-doc)]]
            ::  /apps: applications and code
            [%fall %| /apps [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /apps/code [~ ~] [~ ~] code-dir]
            [%fall %| /apps/code/nex [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /apps/code/lib [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /apps/code/lib/tools [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /apps/code/mar [~ ~] [~ ~] empty-dir:loader]
            ::  /ui/chats.json: manifest of active chats
            [%fall %| /ui [~ ~] [~ ~] empty-dir:loader]
            [%fall %& [/ui %'chats.json'] %.n [~ [/ %json] !>([%a ~[s+'main']])]]
            ::  /about.txt: self-description visible to other agents
            =/  default-about=wain
              :~  'A general-purpose claw agent. No specific role assigned yet.'
              ==
            [%fall %& [/ %'about.txt'] %.n [~ [/ %txt] !>(default-about)]]
            ::  /children: spawned child nexuses
            [%fall %| /children [~ ~] [~ ~] empty-dir:loader]
            ::  ui
            [%over %& [/ %'page.html'] %.n [~ [/ %html] !>((crip (en-xml:html (chat-page "" ""))))]]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  /main.sig: chat lifecycle + message routing
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%claw main.sig: failed")
        ::  rebuild chats.json from /chats/ directory on every startup
        ;<  chats-dir=road:tarball  bind:m
          (ancestor-road:io [/claw %agent] [%| /chats])
        ;<  =seen:nexus  bind:m  (peek:io chats-dir ~)
        =/  names=(list @t)
          ?.  ?=([%& %ball *] seen)  ~['main']
          =/  dirs=(list @ta)  ~(tap in ~(key by dir.ball.p.seen))
          ?~  dirs  ~['main']
          (sort dirs aor)
        =/  manifest=json  [%a (turn names |=(n=@t s+n))]
        ;<  chats-road=road:tarball  bind:m
          (ancestor-road:io [/claw %agent] [%& /ui %'chats.json'])
        ;<  exists=?  bind:m  (peek-exists:io chats-road)
        ;<  ~  bind:m
          ?:  exists
            (over:io chats-road [[/ %json] !>(manifest)])
          (make:io chats-road |+[%.n [[/ %json] !>(manifest)] ~])
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=(%o -.jon)  $
        =/  act=@t  (get-str jon 'action')
        ?+    act  $
            %'create-chat'
          =/  chat-name=@ta
            (fall (bind (~(get by p.jon) 'name') |=(=json ?>(?=(%s -.json) p.json))) '')
          ?:  =('' chat-name)
            ~&  >>>  "%claw main.sig: create-chat missing name"
            $
          ::  check if chat already exists
          ;<  chat-road=road:tarball  bind:m
            (ancestor-road:io [/claw %agent] [%& /chats/[chat-name] %'chat.json'])
          ;<  exists=?  bind:m  (peek-exists:io chat-road)
          ?:  exists
            ~&  >>>  ["%claw main.sig: chat already exists" chat-name]
            $
          ~&  >  ["%claw main.sig: creating chat" chat-name]
          ::  create /chats/[name]/ directory
          ;<  chat-dir=road:tarball  bind:m
            (ancestor-road:io [/claw %agent] [%| /chats/[chat-name]])
          ;<  ~  bind:m  (make:io chat-dir &+[*sand:nexus *gain:nexus [~ ~]])
          ::  create chat.json (empty convo)
          ;<  ~  bind:m  (make:io chat-road |+[%.n [[/ %json] !>([%a ~])] ~])
          ::  create outbox.json
          ;<  outbox-road=road:tarball  bind:m
            (ancestor-road:io [/claw %agent] [%& /chats/[chat-name] %'outbox.json'])
          ;<  ~  bind:m  (make:io outbox-road |+[%.n [[/ %json] !>([%a ~])] ~])
          ::  create status.json
          =/  idle=json  (pairs:enjs:format ~[['state' s+'idle']])
          ;<  status-road=road:tarball  bind:m
            (ancestor-road:io [/claw %agent] [%& /chats/[chat-name] %'status.json'])
          ;<  ~  bind:m  (make:io status-road |+[%.n [[/ %json] !>(idle)] ~])
          ::  update chats.json manifest
          ;<  chat-list=(list @t)  bind:m  read-chat-list
          ;<  ~  bind:m  (write-chat-list (snoc chat-list chat-name))
          ~&  >  ["%claw main.sig: chat created" chat-name]
          $
        ::
            %'delete-chat'
          =/  chat-name=@ta
            (fall (bind (~(get by p.jon) 'name') |=(=json ?>(?=(%s -.json) p.json))) '')
          ?:  =('' chat-name)
            ~&  >>>  "%claw main.sig: delete-chat missing name"
            $
          ~&  >  ["%claw main.sig: deleting chat" chat-name]
          ;<  chat-dir=road:tarball  bind:m
            (ancestor-road:io [/claw %agent] [%| /chats/[chat-name]])
          ;<  ~  bind:m  (cull:io chat-dir)
          ::  TODO: clean up orphaned tool files in /proc/tools/ prefixed with chat-name
          ::  update chats.json manifest
          ;<  chat-list=(list @t)  bind:m  read-chat-list
          ;<  ~  bind:m  (write-chat-list (skip chat-list |=(n=@t =(n chat-name))))
          ~&  >  ["%claw main.sig: chat deleted" chat-name]
          $
        ::
            %'message'
          =/  chat=@t  (get-str jon 'chat')
          =/  content=@t  (get-str jon 'content')
          ?:  |(=('' chat) =('' content))
            ~&  >>>  "%claw main.sig: message missing chat or content"
            $
          =/  chat-name=@ta  (crip (cass:so (trip chat)))
          =/  msg=json
            (pairs:enjs:format ~[['action' s+'message'] ['content' s+content]])
          ;<  chat-road=road:tarball  bind:m
            (ancestor-road:io [/claw %agent] [%& /chats/[chat-name] %'chat.json'])
          ;<  ~  bind:m  (poke:io chat-road [/ %json] !>(msg))
          $
        ==
          ::  /chats/*/chat.json: per-chat event loop
          ::
          [[%chats @ ~] %'chat.json']
        =/  chat-name=@ta  i.t.path.rail
        ;<  ~  bind:m  (rise-wait:io prod "%claw chat: failed")
        ::  if main chat, watch config and subscribe to channel inbox
        ;<  [cur-chan=@t chan-seen=@ud]  bind:m  (init-channel-sub chat-name)
        |-
        ;<  =main-event  bind:m  take-main-event
        ~&  >>  ["%claw main.sig: got event" -.main-event]
        ?-    -.main-event
            %news
          ::  channel inbox: new messages from linked channel
          ?:  ?=([%'chan-inbox' ~] wire.main-event)
            ?.  ?=(%file -.view.main-event)  $
            =/  j=json  (fall (mole |.(!<(json q.sage.view.main-event))) *json)
            =/  msgs=(list json)
              ?.  ?=(%a -.j)  ~
              p.j
            =/  new-count=@ud  (lent msgs)
            ?:  (lte new-count chan-seen)  $
            =/  new-msgs=(list json)  (slag chan-seen msgs)
            =.  chan-seen  new-count
            =/  texts=(list [from=@t text=@t])
              %+  murn  new-msgs
              |=  m=json
              ?.  ?=(%o -.m)  ~
              =/  text  (~(get by p.m) 'text')
              =/  from  (~(get by p.m) 'from')
              ?.  ?=([~ %s *] text)  ~
              `[(fall (bind from |=(j=json ?>(?=(%s -.j) p.j))) 'unknown') p.u.text]
            ?~  texts  $
            ~&  >  ["%claw: channel inbound" (lent texts) "messages"]
            ;<  config=json  bind:m  read-config
            =/  model=@t  (get-str config 'model')
            =/  api-name=@t
              =/  p  (get-str config 'api-proxy')
              ?:(=('' p) 'anthropic' p)
            =/  ctx-window=@ud  (get-num config 'context_window' 80.000)
            =/  msg-cap=@ud  (get-num config 'message_cap' 20.000)
            ;<  =convo  bind:m  read-chat
            =/  combined=@t
              %-  crip
              %-  zing
              %+  turn  texts
              |=  [from=@t text=@t]
              "[{(trip from)} via channel]: {(trip text)}\0a"
            =/  updated=^convo  (snoc convo [%msg 'user' combined])
            ;<  ~  bind:m  (write-chat updated)
            ;<  tools=(map @t tool:nex-tools)  bind:m  get-tools
            ;<  final=^convo  bind:m  (agent-turn chat-name model api-name ctx-window msg-cap updated tools)
            ;<  ~  bind:m  (set-status chat-name [%idle ~])
            ;<  ~  bind:m  (forward-to-channel chat-name final updated)
            $
          ::  config changed: check if channel field changed
          ?:  ?=([%cfg ~] wire.main-event)
            ?.  =(%main chat-name)  $
            ;<  config=json  bind:m  read-config
            =/  new-chan=@t  (get-str config 'channel')
            ?:  =(new-chan cur-chan)  $
            ~&  >  ["%claw: channel changed" cur-chan "=>" new-chan]
            ::  drop old subscription if any
            ;<  ~  bind:m
              ?:  =('' cur-chan)  (pure:m ~)
              =/  old-fold=path  (cord-to-path cur-chan)
              ;<  old-road=road:tarball  bind:m
                (ancestor-road:io [/claw %app] [%& (weld /channels old-fold) %'inbox.json'])
              (drop:io /chan-inbox old-road)
            ::  subscribe to new channel if any
            ?:  =('' new-chan)
              =.  cur-chan  ''
              =.  chan-seen  0
              $
            =/  new-fold=path  (cord-to-path new-chan)
            ;<  new-road=road:tarball  bind:m
              (ancestor-road:io [/claw %app] [%& (weld /channels new-fold) %'inbox.json'])
            ;<  inbox-view=view:nexus  bind:m  (keep:io /chan-inbox new-road ~)
            =/  cnt=@ud
              ?.  ?=(%file -.inbox-view)  0
              =/  j=json  (fall (mole |.(!<(json q.sage.inbox-view))) *json)
              ?.  ?=(%a -.j)  0
              (lent p.j)
            ~&  >>  ["%claw: subscribed to new channel, seen" cnt]
            =.  cur-chan  new-chan
            =.  chan-seen  cnt
            $
          ::  deferred tool result arrived via subscription
          ::  only handle /tool-done/* wires; ignore stale news from other subs
          ?.  ?=([%'tool-done' @ ~] wire.main-event)  $
          =/  tid=@ta  i.t.wire.main-event
          ?.  ?=(%file -.view.main-event)  $
          =/  tst=tool-state:nex-tools  !<(tool-state:nex-tools q.sage.view.main-event)
          ?.  =(%done step.tst)  $
          =/  tool-file=@ta  (crip "{(trip chat-name)}_{(trip tid)}")
          ;<  tool-road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%& /proc/tools tool-file])
          ;<  ~  bind:m  (drop:io /tool-done/[tid] tool-road)
          =/  res=extracted-result  (extract-tool-result tst)
          ~&  >  ["%claw: deferred result for" tid]
          ;<  config=json  bind:m  read-config
          =/  model=@t  (get-str config 'model')
          =/  api-name=@t
            =/  p  (get-str config 'api-proxy')
            ?:(=('' p) 'anthropic' p)
          =/  ctx-window=@ud  (get-num config 'context_window' 80.000)
          =/  msg-cap=@ud  (get-num config 'message_cap' 20.000)
          ;<  =convo  bind:m  read-chat
          =/  updated=^convo
            (snoc convo [%msg 'user' (crip "[spawn_task result]: {(trip text.res)}")])
          ;<  ~  bind:m  (write-chat updated)
          ;<  tools=(map @t tool:nex-tools)  bind:m  get-tools
          ;<  final=^convo  bind:m  (agent-turn chat-name model api-name ctx-window msg-cap updated tools)
          ;<  ~  bind:m  (set-status chat-name [%idle ~])
          ;<  ~  bind:m  (forward-to-channel chat-name final updated)
          $
            %poke
          ~&  >>  ["%claw poke from:" from.main-event]
          =/  =sage:tarball  sage.main-event
          ~&  >>  ["%claw poke: mark" name.p.sage]
        ?+    name.p.sage  $
            %json
          =/  jon=json  !<(json q.sage)
          ~&  >>  ["%claw poke json:" jon]
          ?.  ?=([%o *] jon)  $
          =/  act=@t  (fall (bind (~(get by p.jon) 'action') |=(=json ?>(?=(%s -.json) p.json))) '')
          ~&  >>  ["%claw poke action:" act]
          ?+    act  $
              %'interrupt'
            ::  when inside await-call-or-interrupt, this poke is consumed there.
            ::  when we reach here, it means we're in the main event loop —
            ::  check for a deferred tool to kill.
            =/  tool-id=@t
              (fall (bind (~(get by p.jon) 'id') |=(=json ?>(?=(%s -.json) p.json))) '')
            ?:  =('' tool-id)
              ~&  >  "%claw: interrupt (no request in-flight)"
              $
            ::  kill deferred tool proc
            =/  tid=@ta  (slav %tas tool-id)
            =/  tool-file=@ta  (crip "{(trip chat-name)}_{(trip tid)}")
            ;<  tool-road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%& /proc/tools tool-file])
            ;<  ~  bind:m  (drop:io /tool-done/[tid] tool-road)
            ;<  ~  bind:m  (cull:io tool-road)
            ~&  >  ["%claw: killed deferred tool" tid]
            ;<  ~  bind:m  (set-status chat-name [%idle ~])
            ::  append interrupted marker to chat
            ;<  =convo  bind:m  read-chat
            =/  updated=^convo
              (snoc convo [%tool-result tool-id '[tool interrupted by user]'])
            ;<  ~  bind:m  (write-chat updated)
            $
          ::
              %'set-model'
            =/  model=@t  (fall (bind (~(get by p.jon) 'model') |=(=json ?>(?=(%s -.json) p.json))) '')
            ?:  =('' model)
              ~&  >>>  "%claw: ignoring empty model"
              $
            ;<  config=json  bind:m  read-config
            =/  updated=json
              [%o (~(put by ?>(?=(%o -.config) p.config)) 'model' s+model)]
            ;<  ~  bind:m  (write-config updated)
            ~&  >  ["%claw: model set to" model]
            $
          ::
              %'message'
            =/  content=@t  (fall (bind (~(get by p.jon) 'content') |=(=json ?>(?=(%s -.json) p.json))) '')
            ~&  >>  ["%claw message:" content]
            ?:  =('' content)  $
            ;<  outbox=(list json)  bind:m  (read-outbox chat-name)
            ?:  !=(~ outbox)
              ~&  >  "%claw: nexus finished, ignoring message"
              $
            ;<  config=json  bind:m  read-config
            =/  model=@t  (get-str config 'model')
            =/  api-name=@t
              =/  p  (get-str config 'api-proxy')
              ?:(=('' p) 'anthropic' p)
            =/  ctx-window=@ud  (get-num config 'context_window' 80.000)
            =/  msg-cap=@ud  (get-num config 'message_cap' 20.000)
            ::  read chat, append user message
            ;<  =convo  bind:m  read-chat
            =/  updated=^convo  (snoc convo [%msg 'user' content])
            ;<  ~  bind:m  (write-chat updated)
            ::  discover tools
            ;<  tools=(map @t tool:nex-tools)  bind:m  get-tools
            ::  enter agent turn loop
            ;<  final=^convo  bind:m  (agent-turn chat-name model api-name ctx-window msg-cap updated tools)
            ;<  ~  bind:m  (set-status chat-name [%idle ~])
            ;<  ~  bind:m  (forward-to-channel chat-name final updated)
            ::  Send push notification with last assistant message
            =/  last-text=@t
              =/  rev=^convo  (flop final)
              |-
              ?~  rev  'New message'
              ?.  ?=(%msg -.i.rev)  $(rev t.rev)
              ?.  =('assistant' role.i.rev)  $(rev t.rev)
              (end [3 140] content.i.rev)
            ~&  >  [%claw-push-sending %text last-text %chat chat-name]
            ;<  ~  bind:m  (send-push:io [~ ~ ~ ['claw' last-text ~ ~ `chat-name]])
            ~&  >  [%claw-push-sent %ok ~]
            $
          ::
              %'clear'
            ;<  ~  bind:m  (write-chat ~)
            ~&  >  "%claw: chat cleared"
            $
          ::
              %'link-channel'
            ::  {"action": "link-channel", "channel": "telegram/main-bot"}
            =/  chan-road=@t
              (fall (bind (~(get by p.jon) 'channel') |=(=json ?>(?=(%s -.json) p.json))) '')
            ?:  =('' chan-road)  $
            ;<  config=json  bind:m  read-config
            =/  updated=json
              [%o (~(put by ?>(?=(%o -.config) p.config)) 'channel' s+chan-road)]
            ;<  ~  bind:m  (write-config updated)
            ~&  >  ["%claw: linked to channel" chan-road]
            $
          ::
              %'unlink-channel'
            ;<  config=json  bind:m  read-config
            =/  updated=json
              [%o (~(put by ?>(?=(%o -.config) p.config)) 'channel' s+'')]
            ;<  ~  bind:m  (write-config updated)
            ~&  >  "%claw: unlinked from channel"
            $
          ==
        ==
        ==
          ::  /proc/tools/*: tool execution ([chat]_[tid] naming)
          ::
          [[%proc %tools ~] @]
        ;<  ~  bind:m  (rise-tool prod)
        ;<  st=tool-state:nex-tools  bind:m
          (get-state-as:io ,tool-state:nex-tools)
        ?:  =(%done step.st)  (pure:m ~)
        ::  tool execution
        ;<  got=(each tool:nex-tools tang)  bind:m
          (await-tool tool.st)
        ?:  ?=(%| -.got)
          =/  result-data=json
            (pairs:enjs:format ~[['type' s+'error'] ['message' s+(crip "Unknown tool: {(trip tool.st)}")]])
          (replace:io !>(`tool-state:nex-tools`[tool.st args.st %done data.st `result-data]))
        =/  tl=tool:nex-tools  p.got
        ;<  result=tool-result:nex-tools  bind:m  handler.tl
        =/  result-json=json
          ?-  -.result
            %text   (pairs:enjs:format ~[['type' s+'text'] ['text' s+text.result]])
            %error  (pairs:enjs:format ~[['type' s+'error'] ['message' s+message.result]])
            %mime
          =/  media-type=@t  (mite-to-cord:nex-tools p.mime.result)
          =/  b64=@t  (en:base64:mimes:html q.mime.result)
          %-  pairs:enjs:format
          :~  ['type' s+'mime']
              ['media_type' s+media-type]
              ['data' s+b64]
          ==
          ==
        (replace:io !>(`tool-state:nex-tools`[tool.st args.st %done data.st `result-json]))
          ::  /proc/cron/*: cron job fiber (schedule + fire loop)
          ::
          [[%proc %cron ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%claw cron: failed")
        ;<  st=json  bind:m  (get-state-as:io ,json)
        ?.  ?=(%o -.st)  stay:m
        =/  schedule=@t
          (fall (bind (~(get by p.st) 'schedule') |=(=json ?>(?=(%s -.json) p.json))) '')
        =/  chat=@t
          (fall (bind (~(get by p.st) 'chat') |=(=json ?>(?=(%s -.json) p.json))) '')
        =/  message=@t
          (fall (bind (~(get by p.st) 'message') |=(=json ?>(?=(%s -.json) p.json))) '')
        ?:  |(=('' schedule) =('' chat) =('' message))
          ~&  >>>  "%claw cron: missing schedule, chat, or message"
          stay:m
        |-
        ;<  now=@da  bind:m  get-time:io
        =/  next=(unit @da)  (next-cron-fire:cron schedule now)
        ?~  next
          ~&  >>>  "%claw cron: invalid schedule {(trip schedule)}"
          stay:m
        ~&  >  "%claw cron: waiting until {(scow %da u.next)}"
        ;<  ~  bind:m
          (poke:io &+&+[/sys/behn %'main.timer-state'] [[/ %timer-set] !>(`[wire @da]`[/cron u.next])])
        ;<  *  bind:m  take-poke:io
        ~&  >  "%claw cron: firing to chat {(trip chat)}"
        =/  msg=json
          (pairs:enjs:format ~[['action' s+'message'] ['content' s+message]])
        ;<  chat-road=road:tarball  bind:m
          (ancestor-road:io [/claw %agent] [%& /chats/[(crip (cass:so (trip chat)))] %'chat.json'])
        ;<  ~  bind:m  (poke:io chat-road [/ %json] !>(msg))
        $
          ::  /page.html: rendered chat page
          ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%claw page: failed")
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  ball-id=tape
          %-  zing
          %+  join  "/"
          ^-  (list tape)
          (turn path.here trip)
        ;<  app-road=road:tarball  bind:m
          (ancestor-road:io [/claw %app] [%& / %'page.html'])
        =/  app-url=tape
          ?:  ?=([%| * %& *] app-road)
          =/  steps=@ud  p.p.app-road
          =/  base=path  (scag (sub (lent path.here) steps) path.here)
          =/  rel-path=path  path.p.q.p.app-road
          =/  full=path  (weld base rel-path)
          =/  pax=tape
            %-  zing
            %+  join  "/"
            ^-  (list tape)
            (turn full trip)
          "/grubbery/ball/{pax}/{(trip name.p.q.p.app-road)}"
          ""
        ;<  ~  bind:m  (replace:io !>((crip (en-xml:html (chat-page ball-id app-url)))))
        stay:m
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Subdirectory under claw.'
            ~
          'AI agent nexus. Chat with LLMs, build sub-nexuses.'
        ==
          %|
        ?+  rail.p.mana  'File under claw.'
          [~ %'config.json']                   'Agent config: model, api-proxy, context_window, message_cap, channel.'
          [~ %'main.sig']                      'Chat lifecycle (create/delete) + message routing.'
          [~ %'page.html']                     'Chat interface.'
          [[%chats @ ~] %'chat.json']          'Chat conversation log + event loop. Pokes arrive here.'
          [[%chats @ ~] %'status.json']        'Chat status: idle/api/tool.'
          [[%chats @ ~] %'outbox.json']        'Append-only result log.'
        ==
      ==
    --
::
::  types and helpers
::
|%
::  conversation entry
::
+$  entry
  $%  [%msg role=@t content=@t]
      [%tool-use id=@t name=@t input=json]
      [%tool-result tool-use-id=@t content=@t]
      [%tool-result-media tool-use-id=@t text=@t media-type=@t data=@t]
  ==
::  a conversation is an ordered list of entries
::
+$  convo  (list entry)
::  agent status for UI
::
+$  agent-status
  $%  [%idle ~]
      [%api ~]
      [%tool id=@ta]
  ==
::
::
++  get-str
  |=  [jon=json key=@t]
  ^-  @t
  ?~  jon  ''
  ?.  ?=(%o -.jon)  ''
  =/  val=(unit json)  (~(get by p.jon) key)
  ?~  val  ''
  ?.  ?=(%s -.u.val)  ''
  p.u.val
::
++  get-num
  |=  [jon=json key=@t default=@ud]
  ^-  @ud
  ?.  ?=(%o -.jon)  default
  =/  val=(unit json)  (~(get by p.jon) key)
  ?~  val  default
  ?.  ?=(%n -.u.val)  default
  (fall (rush p.u.val dem) default)
::
++  resolve-proxy
  |=  api-name=@t
  =/  m  (fiber:fiber:nexus ,road:tarball)
  ^-  form:m
  ?:  =('' api-name)
    (pure:m (cord-to-road:tarball ''))
  (ancestor-road:io [/claw %app] [%& /apis/[api-name] %'main.sig'])
::
+$  main-event
  $%  [%poke =from:fiber:nexus =sage:tarball]
      [%news =wire =view:nexus]
  ==
::
++  take-main-event
  =/  m  (fiber:fiber:nexus ,main-event)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in)]
      [~ %poke * *]
    ?:  =([/ %timer-wake] p.sage.u.in)
      [%skip ~]
    [%done %poke [from sage]:u.in]
      [~ %news * *]
    [%done %news [wire view]:u.in]
  ==
::
::
++  read-prompts
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  prompts-road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%| /context/prompts])
  ;<  =seen:nexus  bind:m  (peek:io prompts-road ~)
  ?.  ?=([%& %ball *] seen)
    (pure:m '')
  ?~  fil.ball.p.seen
    (pure:m '')
  =/  names=(list @ta)
    (sort ~(tap in ~(key by contents.u.fil.ball.p.seen)) aor)
  =/  parts=(list @t)  ~
  |-
  ?~  names
    ?~  parts  (pure:m '')
    =/  ordered=(list @t)  (flop parts)
    =/  out=tape
      %-  zing
      %+  join  "\0a\0a"
      ^-  (list tape)
      (turn ordered trip)
    (pure:m (crip out))
  =/  name=@ta  i.names
  ;<  file-road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%& /context/prompts name])
  ;<  file-seen=seen:nexus  bind:m  (peek:io file-road ~)
  ?.  ?=([%& %file *] file-seen)
    $(names t.names)
  ;<  =mime  bind:m  (sage-to-mime:io sage.p.file-seen)
  =/  txt=@t  (crip (trip q.q.mime))
  ?:  =('' txt)
    $(names t.names)
  $(names t.names, parts [txt parts])
::
++  read-memories
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  mem-road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%| /context/memories])
  ;<  =seen:nexus  bind:m  (peek:io mem-road ~)
  ?.  ?=([%& %ball *] seen)
    (pure:m '')
  ?~  fil.ball.p.seen
    (pure:m '')
  =/  names=(list @ta)
    (sort ~(tap in ~(key by contents.u.fil.ball.p.seen)) aor)
  =/  parts=(list @t)  ~
  |-
  ?~  names
    ?~  parts  (pure:m '')
    =/  ordered=(list @t)  (flop parts)
    =/  out=tape
      %-  zing
      %+  join  "\0a\0a"
      ^-  (list tape)
      (turn ordered trip)
    (pure:m (crip out))
  =/  name=@ta  i.names
  ;<  file-road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%& /context/memories name])
  ;<  file-seen=seen:nexus  bind:m  (peek:io file-road ~)
  ?.  ?=([%& %file *] file-seen)
    $(names t.names)
  ;<  =mime  bind:m  (sage-to-mime:io sage.p.file-seen)
  =/  txt=@t  (crip (trip q.q.mime))
  ?:  =('' txt)
    $(names t.names)
  $(names t.names, parts [txt parts])
::
++  read-config
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%& / %'config.json'])
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m *json)
  (pure:m (fall (mole |.(!<(json q.sage.p.seen))) *json))
::
++  write-config
  |=  updated=json
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%& / %'config.json'])
  (over:io road [[/ %json] !>(updated)])
::
++  read-outbox
  |=  chat-name=@ta
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ;<  road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%& /chats/[chat-name] %'outbox.json'])
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m ~)
  =/  jon=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
  ?.  ?=(%a -.jon)  (pure:m ~)
  (pure:m p.jon)
::
++  init-channel-sub
  |=  chat-name=@ta
  =/  m  (fiber:fiber:nexus ,[@t @ud])
  ^-  form:m
  ?.  =(%main chat-name)  (pure:m ['' 0])
  ::  watch config for channel changes
  ;<  cfg-road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%& / %'config.json'])
  ;<  *  bind:m  (keep:io /cfg cfg-road ~)
  ;<  chan-name=@t  bind:m  read-channel
  ?:  =('' chan-name)  (pure:m ['' 0])
  =/  chan-fold=path  (cord-to-path chan-name)
  ;<  inbox-road=road:tarball  bind:m
    (ancestor-road:io [/claw %app] [%& (weld /channels chan-fold) %'inbox.json'])
  ;<  inbox-view=view:nexus  bind:m  (keep:io /chan-inbox inbox-road ~)
  =/  cnt=@ud
    ?.  ?=(%file -.inbox-view)  0
    =/  j=json  (fall (mole |.(!<(json q.sage.inbox-view))) *json)
    ?.  ?=(%a -.j)  0
    (lent p.j)
  ~&  >>  ["%claw: channel inbox subscribed, seen" cnt]
  (pure:m [chan-name cnt])
::
++  read-channel
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  config=json  bind:m  read-config
  (pure:m (get-str config 'channel'))
::
++  read-chat-list
  =/  m  (fiber:fiber:nexus ,(list @t))
  ^-  form:m
  ;<  road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%& /ui %'chats.json'])
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m ~['main'])
  =/  jon=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
  ?.  ?=(%a -.jon)  (pure:m ~['main'])
  (pure:m (murn p.jon |=(j=json ?.(?=(%s -.j) ~ `p.j))))
::
++  write-chat-list
  |=  names=(list @t)
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%& /ui %'chats.json'])
  (over:io road [[/ %json] !>([%a (turn names |=(n=@t s+n))])])
::
++  set-status
  |=  [chat-name=@ta st=agent-status]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  status=json
    ?-  -.st
      %idle  (pairs:enjs:format ~[['state' s+'idle']])
      %api   (pairs:enjs:format ~[['state' s+'api']])
      %tool  (pairs:enjs:format ~[['state' s+'tool'] ['id' s+id.st]])
    ==
  ;<  road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%& /chats/[chat-name] %'status.json'])
  (over:io road [[/ %json] !>(status)])
::
++  join-texts
  |=  texts=(list @t)
  ^-  @t
  ?~  texts  ''
  =/  acc=tape  (trip i.texts)
  |-
  ?~  t.texts  (crip acc)
  $(t.texts t.t.texts, acc (weld acc (weld "\0a\0a" (trip i.t.texts))))
::
::  +signal-typing: send typing indicator to linked channel
::
++  signal-typing
  |=  chat-name=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  =(%main chat-name)  (pure:m ~)
  ;<  chan-name=@t  bind:m  read-channel
  ?:  =('' chan-name)  (pure:m ~)
  =/  chan-fold=path  (cord-to-path chan-name)
  ;<  send-road=road:tarball  bind:m
    (ancestor-road:io [/claw %app] [%& (weld /channels chan-fold) %'send.sig'])
  =/  typing-body=json
    (pairs:enjs:format ~[['action' s+'typing']])
  ;<  ~  bind:m  (poke:io send-road [/ %json] !>(typing-body))
  (pure:m ~)
::
::  +forward-to-channel: if conv has a linked channel, send new assistant msgs
::
++  forward-to-channel
  |=  [chat-name=@ta final=convo before=convo]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  =(%main chat-name)  (pure:m ~)
  ;<  chan-name=@t  bind:m  read-channel
  ?:  =('' chan-name)  (pure:m ~)
  ::  extract new assistant messages (final has more entries than before)
  =/  new-entries=(list entry)  (slag (lent before) final)
  =/  texts=(list @t)
    %+  murn  new-entries
    |=  =entry
    ?.  ?=(%msg -.entry)  ~
    ?.  =('assistant' role.entry)  ~
    `content.entry
  ?~  texts  (pure:m ~)
  =/  combined=@t  (join-texts texts)
  =/  chan-fold=path  (cord-to-path chan-name)
  ;<  send-road=road:tarball  bind:m
    (ancestor-road:io [/claw %app] [%& (weld /channels chan-fold) %'send.sig'])
  =/  send-body=json
    (pairs:enjs:format ~[['text' s+combined]])
  ~&  >  ["%claw: forwarding to channel" chan-name]
  ;<  ~  bind:m  (poke:io send-road [/ %json] !>(send-body))
  (pure:m ~)
::
::  +strip-hoon: remove .hoon suffix from filename
::
++  strip-hoon
  |=  name=@ta
  ^-  @ta
  =/  t=tape  (trip name)
  =/  len=@ud  (lent t)
  ?.  (gth len 5)  name
  ?.  =(".hoon" (slag (sub len 5) t))  name
  (crip (scag (sub len 5) t))
::
::  +get-tool-chat-name: extract chat name from tool filename
::
::  Tool files are named [chat]_[tid]. @ta can't contain '_',
::  so splitting on first '_' reliably gives the chat name.
::  Falls back to 'main' if no underscore found.
::
++  get-tool-chat-name
  |=  =rail:tarball
  ^-  @ta
  =/  t=tape  (trip name.rail)
  =/  idx=(unit @ud)  (find "_" t)
  ?~  idx  %main
  (crip (scag u.idx t))
::
::  built-in tools map
::
++  builtins
  ^-  (map @t tool:nex-tools)
  %-  malt
  :~  [name:browse-tool browse-tool]
      [name:read-tool read-tool]
      [name:write-tool write-tool]
      [name:edit-tool edit-tool]
      [name:delete-tool delete-tool]
      [name:mkdir-tool mkdir-tool]
      [name:create-nexus-tool create-nexus-tool]
      [name:delete-nexus-tool delete-nexus-tool]
      [name:check-bin-tool check-bin-tool]
      [name:check-bang-tool check-bang-tool]
      [name:read-manual-tool read-manual-tool]
      [name:read-font-tool read-font-tool]
      [name:read-weir-tool read-weir-tool]
      [name:add-weir-tool add-weir-tool]
      [name:del-weir-tool del-weir-tool]
      [name:clear-weir-tool clear-weir-tool]
      [name:outbox-tool outbox-tool]
      [name:spawn-task-tool spawn-task-tool]
      [name:grep-files-tool grep-files-tool]
      [name:glob-files-tool glob-files-tool]
      [name:grep-history-tool grep-history-tool]
      [name:recall-messages-tool recall-messages-tool]
      [name:summarize-tool summarize-tool]
      [name:list-agents-tool list-agents-tool]
      [name:search-agents-tool search-agents-tool]
      [name:cron-add-tool cron-add-tool]
      [name:cron-list-tool cron-list-tool]
      [name:cron-remove-tool cron-remove-tool]
  ==
::
::  +get-tools: return built-in tools merged with dynamic tools from apps/code/lib/tools
::
++  get-tools
  =/  m  (fiber:fiber:nexus ,(map @t tool:nex-tools))
  ^-  form:m
  ::  start with built-in tools
  =/  result=(map @t tool:nex-tools)  builtins
  ::  merge dynamic tools from apps/code/lib/tools
  ;<  tools-dir=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%| /apps/code/lib/tools])
  ;<  src-seen=seen:nexus  bind:m  (peek:io tools-dir ~)
  ?.  ?=([%& %ball *] src-seen)
    (pure:m result)
  ?~  fil.ball.p.src-seen
    (pure:m result)
  =/  names=(list @ta)
    %+  turn  ~(tap by contents.u.fil.ball.p.src-seen)
    |=([name=@ta *] (strip-hoon name))
  |-
  ?~  names  (pure:m result)
  =/  name=@ta  i.names
  ;<  tool-road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%& /apps/code/lib/tools name])
  ;<  res=built:nexus  bind:m  (get-code-full:io tool-road)
  ?.  ?=(%vase -.res)  $(names t.names)
  =/  got=(each tool:nex-tools tang)
    (mule |.(!<(tool:nex-tools vase.res)))
  ?.  ?=(%& -.got)  $(names t.names)
  $(names t.names, result (~(put by result) name:p.got p.got))
::
::  +await-tool: look up a tool by name -- builtins first, then dynamic
::
::  Discovers dynamic tools the same way +get-tools does, using
::  ancestor-road so it works from any depth.
::
++  await-tool
  |=  tool=@t
  =/  m  (fiber:fiber:nexus ,(each tool:nex-tools tang))
  ^-  form:m
  =/  builtin=(unit tool:nex-tools)  (~(get by builtins) tool)
  ?^  builtin  (pure:m &+u.builtin)
  ::  discover dynamic tools from apps/code/lib/tools
  ;<  tools-dir=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%| /apps/code/lib/tools])
  ;<  src-seen=seen:nexus  bind:m  (peek:io tools-dir ~)
  ?.  ?=([%& %ball *] src-seen)
    (pure:m [%| ~[leaf+"tool not found: {(trip tool)}"]])
  ?~  fil.ball.p.src-seen
    (pure:m [%| ~[leaf+"tool not found: {(trip tool)}"]])
  =/  names=(list @ta)
    %+  turn  ~(tap by contents.u.fil.ball.p.src-seen)
    |=([name=@ta *] (strip-hoon name))
  |-
  ?~  names
    (pure:m [%| ~[leaf+"tool not found: {(trip tool)}"]])
  =/  name=@ta  i.names
  ;<  tool-road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%& /apps/code/lib/tools name])
  ;<  res=built:nexus  bind:m  (get-code-full:io tool-road)
  ?.  ?=(%vase -.res)  $(names t.names)
  =/  got=(each tool:nex-tools tang)
    (mule |.(!<(tool:nex-tools vase.res)))
  ?.  ?=(%& -.got)  $(names t.names)
  ?.  =(tool name:p.got)  $(names t.names)
  (pure:m &+p.got)
::
::  +rise-tool: handle tool process crash
::
++  rise-tool
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=(%rise -.prod)  (pure:m ~)
  %-  (slog leaf+"%claw tool crashed" tang.prod)
  ;<  st=tool-state:nex-tools  bind:m
    (get-state-as:io ,tool-state:nex-tools)
  =/  err-msg=@t  (render-tang:build tang.prod)
  =/  result-data=json
    (pairs:enjs:format ~[['type' s+'error'] ['message' s+(crip "crash\0a{(trip err-msg)}")]])
  =/  new-vase=(each vase tang)
    (mule |.(!>(`tool-state:nex-tools`[tool.st args.st %done data.st `result-data])))
  ?:  ?=(%| -.new-vase)
    %-  (slog leaf+"%claw: crash handler failed to build vase" ~)
    =/  fallback=tool-state:nex-tools  ['' ~ %done ~ `(pairs:enjs:format ~[['type' s+'error'] ['message' s+'tool crashed and recovery failed']])]
    (replace:io !>(fallback))
  (replace:io p.new-vase)
::
::  +tools-to-json: convert tool map to Anthropic tools array
::
++  tools-to-json
  |=  tools=(map @t tool:nex-tools)
  ^-  json
  :-  %a
  %+  turn  ~(val by tools)
  |=  tl=tool:nex-tools
  =/  props=(list [@t json])
    %+  turn  ~(tap by parameters.tl)
    |=  [k=@t def=parameter-def:nex-tools]
    [k (pairs:enjs:format ~[['type' s+(crip (trip type.def))] ['description' s+description.def]])]
  %-  pairs:enjs:format
  :~  ['name' s+name.tl]
      ['description' s+description.tl]
      :-  'input_schema'
      %-  pairs:enjs:format
      :~  ['type' s+'object']
          ['properties' [%o (~(gas by *(map @t json)) props)]]
          ['required' [%a (turn required.tl |=(r=@t s+r))]]
      ==
  ==
::
::  +agent-turn: the main agentic loop
::
::  sends prompt to API, handles tool_use responses, loops until end_turn
::
++  agent-turn
  |=  [chat-name=@ta model=@t api-name=@t ctx-window=@ud msg-cap=@ud =convo tools=(map @t tool:nex-tools)]
  =/  m  (fiber:fiber:nexus ,^convo)
  ^-  form:m
  ~&  >>  "%claw agent-turn: start"
  ;<  base-sys=@t  bind:m  read-prompts
  ~&  >>  "%claw agent-turn: got prompts"
  ;<  memories=@t  bind:m  read-memories
  ~&  >>  "%claw agent-turn: got memories"
  ;<  now=@da  bind:m  get-time:io
  ~&  >>  ["%claw agent-turn: got time" now]
  ;<  our=ship  bind:m  get-our:io
  ~&  >>  "%claw agent-turn: got our"
  ;<  here=rail:tarball  bind:m  get-here-abs:io
  ~&  >>  "%claw agent-turn: got here"
  =/  runtime-ctx=@t
    %-  crip
    ;:  weld
      ::  "Current time (UTC): {(en:datetime-local:iso-8601 now)}\0a"
      "Ship: {(scow %p our)}\0a"
      "Location: {(spud (snoc path.here name.here))}"
    ==
  |-
  =/  sys-prompt=@t
    %-  crip
    ;:  weld
      (trip base-sys)
      "\0a\0a"
      (trip runtime-ctx)
      ?:  =('' memories)  ""
      :(weld "\0a\0a## Memories\0a\0a" (trip memories))
    ==
  ::  subtract prompt + tool defs from window budget
  =/  prompt-tokens=@ud  (max 1 (div (met 3 sys-prompt) 4))
  =/  tools-tokens=@ud
    ?:  =(~ tools)  0
    (max 1 (div (met 3 (en:json:html (tools-to-json tools))) 4))
  =/  effective-window=@ud
    ?:  (gth (add prompt-tokens tools-tokens) ctx-window)  1.000
    (sub ctx-window (add prompt-tokens tools-tokens))
  =/  api-msgs-list=(list json)  (assemble convo effective-window msg-cap)
  ::  build API request body
  =/  api-msgs=json  [%a api-msgs-list]
  =/  sys-block=json
    %-  pairs:enjs:format
    :~  ['type' s+'text']
        ['text' s+sys-prompt]
        ['cache_control' (pairs:enjs:format ~[['type' s+'ephemeral']])]
    ==
  =/  body-pairs=(list [@t json])
    :~  ['model' s+model]
        ['max_tokens' (numb:enjs:format 4.096)]
        ['system' [%a ~[sys-block]]]
        ['messages' api-msgs]
    ==
  =?  body-pairs  !=(~ tools)
    (snoc body-pairs ['tools' (tools-to-json tools)])
  =/  payload=json  (pairs:enjs:format body-pairs)
  ::  signal typing to linked channel
  ;<  ~  bind:m  (signal-typing chat-name)
  ~&  >  ["%claw: sending to" model]
  ::  call the api proxy via calls/ pattern
  ;<  proxy=road:tarball  bind:m  (resolve-proxy api-name)
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  call-id=@t  (scot %uv (end [3 8] eny))
  =/  main-road=road:tarball  proxy
  =/  call-road=road:tarball
    ::  same bend as proxy but targeting calls/{id}.json instead of main.sig
    ?>  ?=(%| -.proxy)
    =/  steps=@ud  p.p.proxy
    ^-  road:tarball
    [%| steps %& [~[%apis api-name %calls] (crip "{(trip call-id)}.json")]]
  ::  subscribe to call file before it exists
  ;<  *  bind:m  (keep:io /api-call call-road ~)
  ::  poke main.sig to create the call
  =/  poke-body=json
    (pairs:enjs:format ~[['id' s+call-id] ['body' payload]])
  ;<  ~  bind:m  (poke:io main-road [/ %json] !>(poke-body))
  ~&  >>  ["%claw: call" call-id "created, waiting for response"]
  ;<  ~  bind:m  (set-status chat-name [%api ~])
  ::  wait for news with status=done, or interrupt poke
  ;<  resp=(unit json)  bind:m  (await-call-or-interrupt /api-call)
  ::  drop subscription
  ;<  ~  bind:m  (drop:io /api-call call-road)
  ::  handle interrupt
  ?~  resp
    ~&  >  "%claw: interrupted"
    =/  int-convo=^convo  (snoc convo [%msg 'assistant' '[interrupted]'])
    ;<  ~  bind:m  (write-chat int-convo)
    (pure:m int-convo)
  ::  parse API response from JSON
  =/  parsed=(unit api-response)  (parse-json-response u.resp)
  ?~  parsed
    =/  raw=@t
      ?:  =(*json u.resp)  'empty response (vase extraction failed)'
      =/  full=tape  (trip (en:json:html u.resp))
      (crip ?:((lth (lent full) 200) full (weld (scag 200 full) "...")))
    =/  err-msg=@t  (crip "Error: failed to parse API response: {(trip raw)}")
    =/  err-convo=^convo  (snoc convo [%msg 'assistant' err-msg])
    ;<  ~  bind:m  (write-chat err-convo)
    (pure:m err-convo)
  ::  append all content blocks incrementally
  =/  updated=^convo
    %+  roll  content-blocks.u.parsed
    |=  [=content-block acc=_convo]
    ?-  -.content-block
        %text      (snoc acc [%msg 'assistant' text.content-block])
        %tool-use  (snoc acc [%tool-use id.content-block name.content-block input.content-block])
    ==
  ;<  ~  bind:m  (write-chat updated)
  ::  if end_turn or no tool calls, we're done
  =/  calls=(list content-block)
    (skim content-blocks.u.parsed |=(=content-block ?=(%tool-use -.content-block)))
  ?~  calls
    (pure:m updated)
  ::  execute tools, append results incrementally
  ~&  >  ["%claw: executing" (lent calls) "tool calls"]
  ;<  result=(unit ^convo)  bind:m  (run-tool-calls chat-name updated calls)
  ?~  result
    ::  interrupted during tool execution — exit turn
    (pure:m updated)
  $(convo u.result)
::
::  +run-tool-calls: execute tool calls via /tools grubs
::
::  Waits for each tool to reach %ack or %done (whichever comes first).
::  If %ack, the tool is still running -- re-subscribes on /tool-done/[tid]
::  so main.sig's event loop picks up the eventual %done.
::  If %done, the tool completed synchronously -- subscription dropped.
::
++  run-tool-calls
  |=  [chat-name=@ta =convo calls=(list content-block)]
  =/  m  (fiber:fiber:nexus ,(unit ^convo))
  ^-  form:m
  |-
  ?~  calls  (pure:m `convo)
  =/  call=content-block  i.calls
  ?>  ?=(%tool-use -.call)
  =/  tool-args=(map @t json)
    ?.  ?=(%o -.input.call)  ~
    p.input.call
  =/  ts=tool-state:nex-tools
    [name.call tool-args %start ~ ~]
  =/  tid=@ta  id.call
  =/  tool-file=@ta  (crip "{(trip chat-name)}_{(trip tid)}")
  ;<  tool-road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%& /proc/tools tool-file])
  ;<  ~  bind:m  (set-status chat-name [%tool tid])
  ;<  *  bind:m  (keep:io /tool-wait/[tid] tool-road ~)
  ;<  ~  bind:m  (make:io tool-road |+[%.n [[/ %tool-state] !>(ts)] ~])
  ;<  ack=(unit [extracted-result ?])  bind:m  (await-tool-ack tid)
  ;<  ~  bind:m  (drop:io /tool-wait/[tid] tool-road)
  ?~  ack
    ::  interrupted — kill tool, write marker, return
    ;<  ~  bind:m  (cull:io tool-road)
    ~&  >  ["%claw: tool interrupted" tid]
    =/  updated=^convo  (snoc convo [%tool-result id.call '[tool interrupted by user]'])
    ;<  ~  bind:m  (write-chat updated)
    ;<  ~  bind:m  (set-status chat-name [%idle ~])
    (pure:m ~)
  =/  res=extracted-result  -.u.ack
  =/  more=?  +.u.ack
  ::  append result to convo and write immediately
  =/  updated=^convo
    ?:  is-mime.res
      (snoc convo [%tool-result-media id.call text.res media-type.res data.res])
    (snoc convo [%tool-result id.call text.res])
  ;<  ~  bind:m  (write-chat updated)
  ?:  more
    ::  tool ack'd but still running -- subscribe on /tool-done for main loop
    ;<  *  bind:m  (keep:io /tool-done/[tid] tool-road ~)
    $(calls t.calls, convo updated)
  $(calls t.calls, convo updated)
::
::  +await-tool-ack: wait for tool grub to reach %ack or %done
::
::  Returns [result-text more=?] where more=%.y means the tool
::  is still running and will eventually reach %done.
::
++  await-tool-ack
  |=  tid=@ta
  =/  m  (fiber:fiber:nexus ,(unit [extracted-result ?]))
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in)]
    ::  interrupt poke — return ~
    ::
      [~ %poke * *]
    =/  jon=json  (fall (mole |.(!<(json q.sage.u.in))) *json)
    ?.  ?=(%o -.jon)  [%skip ~]
    =/  act=(unit json)  (~(get by p.jon) 'action')
    ?.  ?=([~ %s %'interrupt'] act)  [%skip ~]
    [%done ~]
    ::  news on tool subscription
    ::
      [~ %news * *]
    ?.  =(/tool-wait/[tid] wire.u.in)  [%skip ~]
    ?.  ?=(%file -.view.u.in)  [%skip ~]
    =/  st=tool-state:nex-tools  !<(tool-state:nex-tools q.sage.view.u.in)
    ?:  =(%ack step.st)
      [%done `[(extract-tool-result st) %.y]]
    ?.  =(%done step.st)  [%skip ~]
    [%done `[(extract-tool-result st) %.n]]
  ==
::
::  +extract-tool-result: pull text from tool-state update
::
::  +extract-tool-result: pull result from tool-state update
::  returns [text is-mime media-type b64-data]
::
+$  extracted-result  [text=@t is-mime=? media-type=@t data=@t]
++  extract-tool-result
  |=  st=tool-state:nex-tools
  ^-  extracted-result
  ?~  update.st  ['tool returned no result' %.n '' '']
  ?.  ?=(%o -.u.update.st)  ['tool returned no result' %.n '' '']
  =/  result-type=(unit json)  (~(get by p.u.update.st) 'type')
  ?:  ?=([~ %s %'error'] result-type)
    =/  err=@t  (fall (bind (~(get by p.u.update.st) 'message') |=(j=json ?>(?=(%s -.j) p.j))) 'unknown error')
    [(crip "ERROR: {(trip err)}") %.n '' '']
  ?:  ?=([~ %s %'mime'] result-type)
    =/  media-type=@t  (fall (bind (~(get by p.u.update.st) 'media_type') |=(j=json ?>(?=(%s -.j) p.j))) '')
    =/  b64=@t  (fall (bind (~(get by p.u.update.st) 'data') |=(j=json ?>(?=(%s -.j) p.j))) '')
    [(crip "[binary: {(trip media-type)}]") %.y media-type b64]
  [(fall (bind (~(get by p.u.update.st) 'text') |=(j=json ?>(?=(%s -.j) p.j))) '') %.n '' '']
::
::  +await-call-or-interrupt: wait for call response OR interrupt poke
::
::  Returns (some json) on API response, ~ on interrupt.
::  Listens for both news on the call subscription wire and interrupt pokes.
::
++  await-call-or-interrupt
  |=  =wire
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in)]
    ::  interrupt poke — return ~
    ::
      [~ %poke * *]
    =/  jon=json  (fall (mole |.(!<(json q.sage.u.in))) *json)
    ?.  ?=(%o -.jon)  [%skip ~]
    =/  act=(unit json)  (~(get by p.jon) 'action')
    ?.  ?=([~ %s %'interrupt'] act)  [%skip ~]
    [%done ~]
    ::  news on call subscription — check for status=done
    ::
      [~ %news * *]
    ?.  =(wire wire.u.in)  [%skip ~]
    ?.  ?=(%file -.view.u.in)  [%skip ~]
    =/  jon=json  (fall (mole |.(!<(json q.sage.view.u.in))) *json)
    ?.  ?=(%o -.jon)  [%skip ~]
    =/  status=(unit json)  (~(get by p.jon) 'status')
    ?.  ?=([~ %s %'done'] status)  [%skip ~]
    =/  resp=json  (fall (~(get by p.jon) 'response') [%o ~])
    [%done `resp]
  ==
::
::  API response types
::
+$  content-block
  $%  [%text text=@t]
      [%tool-use id=@t name=@t input=json]
  ==
+$  api-response
  $:  stop-reason=@t
      content-blocks=(list content-block)
  ==
::
::  +parse-api-response: parse Anthropic Messages API response
::
++  parse-json-response
  |=  data=json
  ^-  (unit api-response)
  ?.  ?=(%o -.data)  ~
  ::  check for error
  =/  typ=(unit json)  (~(get by p.data) 'type')
  ?:  ?=([~ %s %'error'] typ)
    =/  err=(unit json)  (~(get by p.data) 'error')
    =/  err-msg=@t
      ?~  err  'unknown error'
      ?:  ?=(%o -.u.err)
        (fall (bind (~(get by p.u.err) 'message') |=(j=json ?>(?=(%s -.j) p.j))) 'unknown error')
      'unknown error'
    ~&  >>>  ["%claw: API error" err-msg]
    `[%'end_turn' [%text (crip "API error: {(trip err-msg)}")]~]
  ::  extract stop_reason
  =/  stop=@t
    (fall (bind (~(get by p.data) 'stop_reason') |=(j=json ?>(?=(%s -.j) p.j))) 'end_turn')
  ::  extract content blocks
  =/  content-arr=(unit json)  (~(get by p.data) 'content')
  ?~  content-arr  ~
  ?.  ?=(%a -.u.content-arr)  ~
  =/  blocks=(list content-block)
    %+  murn  p.u.content-arr
    |=  j=json
    ^-  (unit content-block)
    ?.  ?=(%o -.j)  ~
    =/  block-type=(unit json)  (~(get by p.j) 'type')
    ?:  ?=([~ %s %'text'] block-type)
      =/  text=(unit json)  (~(get by p.j) 'text')
      ?~  text  ~
      ?.  ?=(%s -.u.text)  ~
      `[%text p.u.text]
    ?:  ?=([~ %s %'tool_use'] block-type)
      =/  id=(unit json)  (~(get by p.j) 'id')
      =/  name=(unit json)  (~(get by p.j) 'name')
      =/  input=(unit json)  (~(get by p.j) 'input')
      ?~  id  ~
      ?~  name  ~
      ?.  ?=(%s -.u.id)  ~
      ?.  ?=(%s -.u.name)  ~
      `[%tool-use p.u.id p.u.name (fall input [%o ~])]
    ~
  `[stop blocks]
::
++  read-chat
  =/  m  (fiber:fiber:nexus ,convo)
  ^-  form:m
  ;<  jon=json  bind:m  (get-state-as:io ,json)
  (pure:m (parse-convo jon))
::
++  write-chat
  |=  =convo
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (replace:io !>((convo-to-json convo)))
::
++  parse-convo
  |=  jon=json
  ^-  convo
  ?.  ?=(%a -.jon)  ~
  %+  murn  p.jon
  |=  =json
  ^-  (unit entry)
  ?.  ?=(%o -.json)  ~
  =/  type=(unit @t)  (bind (~(get by p.json) 'type') |=(j=^json ?>(?=(%s -.j) p.j)))
  ?:  ?=([~ %'tool_use'] type)
    =/  id=@t  (fall (bind (~(get by p.json) 'id') |=(j=^json ?>(?=(%s -.j) p.j))) '')
    =/  name=@t  (fall (bind (~(get by p.json) 'name') |=(j=^json ?>(?=(%s -.j) p.j))) '')
    =/  input=^json  (fall (~(get by p.json) 'input') [%o ~])
    `[%tool-use id name input]
  ?:  ?=([~ %'tool_result'] type)
    =/  tid=@t  (fall (bind (~(get by p.json) 'tool_use_id') |=(j=^json ?>(?=(%s -.j) p.j))) '')
    =/  content=@t  (fall (bind (~(get by p.json) 'content') |=(j=^json ?>(?=(%s -.j) p.j))) '')
    `[%tool-result tid content]
  ?:  ?=([~ %'tool_result_media'] type)
    =/  tid=@t  (fall (bind (~(get by p.json) 'tool_use_id') |=(j=^json ?>(?=(%s -.j) p.j))) '')
    =/  text=@t  (fall (bind (~(get by p.json) 'text') |=(j=^json ?>(?=(%s -.j) p.j))) '')
    =/  media-type=@t  (fall (bind (~(get by p.json) 'media_type') |=(j=^json ?>(?=(%s -.j) p.j))) '')
    =/  b64=@t  (fall (bind (~(get by p.json) 'data') |=(j=^json ?>(?=(%s -.j) p.j))) '')
    `[%tool-result-media tid text media-type b64]
  ::  default: message
  =/  role=(unit @t)  (bind (~(get by p.json) 'role') |=(j=^json ?>(?=(%s -.j) p.j)))
  =/  content=(unit @t)  (bind (~(get by p.json) 'content') |=(j=^json ?>(?=(%s -.j) p.j)))
  ?~  role  ~
  ?~  content  ~
  `[%msg u.role u.content]
::
++  convo-to-json
  |=  =convo
  ^-  json
  :-  %a
  %+  turn  convo
  |=  =entry
  ?-  -.entry
      %msg
    (pairs:enjs:format ~[['role' s+role.entry] ['content' s+content.entry]])
      %tool-use
    %-  pairs:enjs:format
    :~  ['type' s+'tool_use']
        ['id' s+id.entry]
        ['name' s+name.entry]
        ['input' input.entry]
    ==
      %tool-result
    %-  pairs:enjs:format
    :~  ['type' s+'tool_result']
        ['tool_use_id' s+tool-use-id.entry]
        ['content' s+content.entry]
    ==
      %tool-result-media
    %-  pairs:enjs:format
    :~  ['type' s+'tool_result_media']
        ['tool_use_id' s+tool-use-id.entry]
        ['text' s+text.entry]
        ['media_type' s+media-type.entry]
        ['data' s+data.entry]
    ==
  ==
::
::  +assemble: build API messages JSON from conversation
::
::  returns list of API message objects with sliding window.
::  walks backward from end, keeping entries within token budget.
::  if truncated, prepends a note about earlier history.
::  resolves [ref:N-M] in tool results from full convo.
::  truncates individual messages exceeding msg-cap tokens.
::  consecutive tool-use entries get merged into one assistant message.
::  consecutive tool-result entries get merged into one user message.
::
++  assemble
  |=  [=convo ctx-window=@ud msg-cap=@ud]
  ^-  (list json)
  =/  total=@ud  (lent convo)
  =/  cap-chars=@ud  (mul msg-cap 4)
  ::  sliding window: walk backward, keep entries within budget
  =/  windowed=^convo
    =/  budget=@ud  ctx-window
    =/  rev=^convo  (flop convo)
    =/  kept=^convo  ~
    |-
    ?~  rev  kept
    =/  tok=@ud  (entry-tokens i.rev)
    ?:  (gth tok budget)  kept
    $(rev t.rev, kept [i.rev kept], budget (sub budget tok))
  ::  drop orphaned tool entries at start of window
  ::  window must start with a %msg to avoid dangling tool_result/tool_use
  =/  windowed=^convo
    |-
    ?~  windowed  ~
    ?:  ?=(%msg -.i.windowed)  windowed
    $(windowed t.windowed)
  =/  skipped=@ud  (sub total (lent windowed))
  =/  skipped-tokens=@ud
    %+  roll  (scag skipped convo)
    |=  [e=entry acc=@ud]
    (add acc (entry-tokens e))
  =/  window-start=@ud  skipped
  =/  window-count=@ud  (lent windowed)
  =/  window-tokens=@ud
    %+  roll  windowed
    |=  [e=entry acc=@ud]
    (add acc (entry-tokens e))
  =/  prefix=(unit json)
    ?:  =(0 skipped)  ~
    =/  note=@t
      %-  crip
      ;:  weld
        "[Conversation history truncated. "
        (a-co:co skipped)
        " earlier messages (est. "
        (a-co:co skipped-tokens)
        " tokens) not shown, covering messages 0-"
        (a-co:co (dec skipped))
        ". Current window shows "
        (a-co:co window-count)
        " messages (est. "
        (a-co:co window-tokens)
        " tokens), messages "
        (a-co:co window-start)
        "-"
        (a-co:co (dec total))
        ".]"
      ==
    `(pairs:enjs:format ~[['role' s+'user'] ['content' s+note]])
  ::  assemble the windowed entries
  =/  msgs=(list json)  ?~(prefix ~ [u.prefix]~)
  =/  pending-tools=(list json)  ~
  =/  pending-results=(list json)  ~
  =/  walk=^convo  windowed
  |-  ^-  (list json)
  =/  flush-tools=_msgs
    ?~  pending-tools  msgs
    :_  msgs
    %-  pairs:enjs:format
    ~[['role' s+'assistant'] ['content' [%a (flop pending-tools)]]]
  =/  flush-results=_msgs
    ?~  pending-results  msgs
    :_  msgs
    %-  pairs:enjs:format
    ~[['role' s+'user'] ['content' [%a (flop pending-results)]]]
  ?~  walk
    =.  msgs  flush-tools
    =.  msgs  flush-results
    (flop msgs)
  ?-  -.i.walk
      %msg
    =.  msgs  flush-tools
    =.  msgs  flush-results
    =/  txt=@t  (cap-content content.i.walk cap-chars)
    %=  $
      walk  t.walk
      pending-tools  ~
      pending-results  ~
      msgs  :_  msgs
             (pairs:enjs:format ~[['role' s+role.i.walk] ['content' s+txt]])
    ==
      %tool-use
    =.  msgs  flush-results
    =.  pending-results  ~
    =/  block=json
      %-  pairs:enjs:format
      :~  ['type' s+'tool_use']
          ['id' s+id.i.walk]
          ['name' s+name.i.walk]
          ['input' input.i.walk]
      ==
    $(walk t.walk, pending-tools [block pending-tools])
      %tool-result
    =.  msgs  flush-tools
    =.  pending-tools  ~
    ::  resolve [ref:N-M] markers from full convo
    =/  txt=@t  (resolve-content content.i.walk convo cap-chars)
    =/  block=json
      %-  pairs:enjs:format
      :~  ['type' s+'tool_result']
          ['tool_use_id' s+tool-use-id.i.walk]
          ['content' s+txt]
      ==
    $(walk t.walk, pending-results [block pending-results])
      %tool-result-media
    =.  msgs  flush-tools
    =.  pending-tools  ~
    ::  multimodal: content is an array of blocks (text label + media)
    =/  media-block=json
      %-  pairs:enjs:format
      :~  ['type' s+(media-block-type media-type.i.walk)]
          :-  'source'
          %-  pairs:enjs:format
          :~  ['type' s+'base64']
              ['media_type' s+media-type.i.walk]
              ['data' s+data.i.walk]
          ==
      ==
    =/  block=json
      %-  pairs:enjs:format
      :~  ['type' s+'tool_result']
          ['tool_use_id' s+tool-use-id.i.walk]
          ['content' [%a ~[media-block]]]
      ==
    $(walk t.walk, pending-results [block pending-results])
  ==
::  +media-block-type: map media type cord to Claude content block type
::  image/* -> 'image', application/pdf -> 'document'
::
++  media-block-type
  |=  mt=@t
  ^-  @t
  =/  t=tape  (trip mt)
  ?:  =("application/pdf" t)  'document'
  ?:  ?=(^ (find "image/" t))  'image'
  'document'
::
::  +cap-content: truncate content to char limit with note
::
++  cap-content
  |=  [txt=@t limit=@ud]
  ^-  @t
  ?:  (lte (met 3 txt) limit)  txt
  =/  original=@ud  (met 3 txt)
  %-  crip
  ;:  weld
    (scag limit (trip txt))
    "\0a\0a[truncated: showing "
    (a-co:co (div limit 4))
    " of ~"
    (a-co:co (div original 4))
    " est. tokens]"
  ==
::
::  +resolve-content: resolve [ref:N-M] markers, then cap
::
++  resolve-content
  |=  [txt=@t full=convo limit=@ud]
  ^-  @t
  =/  t=tape  (trip txt)
  ?.  ?&  (gte (lent t) 5)
          =("[ref:" (scag 5 t))
      ==
    (cap-content txt limit)
  ::  parse [ref:N-M]
  =/  inner=tape  (slag 5 t)
  =/  close=(unit @ud)  (find "]" inner)
  ?~  close  (cap-content txt limit)
  =/  range=tape  (scag u.close inner)
  =/  dash=(unit @ud)  (find "-" range)
  ?~  dash  (cap-content txt limit)
  =/  from=@ud  (fall (rush (crip (scag u.dash range)) dem) 0)
  =/  to=@ud  (fall (rush (crip (slag +(u.dash) range)) dem) 0)
  ::  resolve entries from full convo
  =/  resolved=tape
    %-  zing
    %+  turn  (gulf from to)
    |=  idx=@ud
    ^-  tape
    ?:  (gte idx (lent full))  ~
    =/  e=entry  (snag idx full)
    ;:  weld
      "["
      (a-co:co idx)
      "] "
      ?-  -.e
          %msg
        ;:  weld  (trip role.e)  ": "  (trip content.e)  ==
          %tool-use
        (weld "tool_use: " (trip name.e))
          %tool-result
        (weld "tool_result: " (trip content.e))
          %tool-result-media
        (weld "tool_result: " (trip text.e))
      ==
      "\0a"
    ==
  (cap-content (crip resolved) limit)
::
::  split a tape into lines by newline
::
++  to-lines
  |=  t=tape
  ^-  (list tape)
  =/  acc=(list tape)  ~
  =/  cur=tape  ~
  |-
  ?~  t
    (flop [cur acc])
  ?:  =(i.t '\0a')
    $(t t.t, acc [cur acc], cur ~)
  $(t t.t, cur (snoc cur i.t))
::
::  estimate tokens for a conversation entry (~4 chars per token)
::
++  entry-tokens
  |=  =entry
  ^-  @ud
  =/  chars=@ud
    ?-  -.entry
        %msg          (met 3 content.entry)
        %tool-use     (add (met 3 name.entry) (met 3 (en:json:html input.entry)))
        %tool-result  (met 3 content.entry)
        ::  images are roughly 1600 tokens per 1MB; estimate from base64 size
        %tool-result-media  (max (met 3 text.entry) (div (met 3 data.entry) 800))
    ==
  (max 1 (div chars 4))
::
::
::
++  chat-page
  |=  [ball-id=tape app-url=tape]
  ^-  manx
  ;html
    ;head
      ;title: claw
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  style-text
      ==
    ==
    ;body
      ;div#app
        ;div#header
          ;div
            ;h1
              ;a(href "{app-url}", style "color: inherit; text-decoration: none;"): claw
            ==
            ;div.f3.mono.s-2: AI agent nexus
          ==
          ;div
            ;button#menu-btn(onclick "toggleSidebar()"): ☰
            ;button#clear-btn.hdr-btn: clear
            ;button#about-btn.hdr-btn: about
            ;button#config-btn.hdr-btn: config
          ==
        ==
        ;div#cfg-backdrop
          ;div#cfg-modal
            ;div#cfg-header
              ;span: Config
              ;div
                ;button#cfg-save.hdr-btn: save
                ;button#cfg-close.hdr-btn: close
              ==
            ==
            ;label.cfg-label: Model
            ;input#cfg-model(type "text", placeholder "claude-sonnet-4-20250514");
            ;label.cfg-label: Context window (tokens)
            ;input#cfg-window(type "number", placeholder "80000");
            ;label.cfg-label: Message cap (tokens)
            ;input#cfg-msgcap(type "number", placeholder "20000");
            ;label.cfg-label: API proxy (e.g. anthropic)
            ;input#cfg-proxy(type "text", placeholder "anthropic");
            ;label.cfg-label: Channel (e.g. telegram/main-bot)
            ;input#cfg-channel(type "text", placeholder "leave empty for none");
            ;div#cfg-status;
          ==
        ==
        ;div#abt-backdrop
          ;div#abt-modal
            ;div#abt-header
              ;span: About
              ;div
                ;button#abt-save.hdr-btn: save
                ;button#abt-close.hdr-btn: close
              ==
            ==
            ;textarea#abt-text(rows "6", placeholder "Describe this agent...", style "width:100%;font-family:monospace;font-size:12px;border:1px solid #333;border-radius:6px;padding:10px;resize:vertical;background:#111;color:#eee;outline:none;");
            ;div#abt-status;
          ==
        ==
        ;div#body
          ;div#sidebar
            ;div#chat-list;
            ;button#new-chat-btn: + new chat
          ==
          ;div#sidebar-overlay(onclick "toggleSidebar()");
          ;div#main
            ;div#messages;
            ;div#loading;
            ;form#prompt-form(onsubmit "sendMessage(event)")
              ;div.input-row
                ;textarea#input(rows "1", placeholder "Say something...", autocomplete "off");
                ;button#stop-btn(type "button"): Stop
                ;button(type "submit"): Send
              ==
            ==
          ==
        ==
      ==
      ;script
        ;+  ;/  (script-text ball-id)
      ==
    ==
  ==
::
++  style-text
  ^-  tape
  """
  * \{ margin: 0; padding: 0; box-sizing: border-box; }
  body \{ font-family: -apple-system, system-ui, sans-serif; background: #111; color: #eee; height: 100vh; }
  #app \{ display: flex; flex-direction: column; height: 100vh; }
  #header \{ padding: 12px 16px; border-bottom: 1px solid #333; flex-shrink: 0; display: flex; justify-content: space-between; align-items: flex-start; }
  #header h1 \{ font-size: 20px; font-weight: 700; }
  #header > div \{ display: flex; gap: 6px; }
  #body \{ flex: 1; display: flex; overflow: hidden; }
  #sidebar \{ width: 160px; flex-shrink: 0; border-right: 1px solid #222; display: flex; flex-direction: column; padding: 8px 0; overflow-y: auto; }
  #main \{ flex: 1; display: flex; flex-direction: column; overflow: hidden; max-width: 700px; width: 100%; margin: 0 auto; padding: 0 16px; }
  #messages \{ flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 8px; padding: 8px 0; }
  .msg \{ padding: 8px 12px; border-radius: 8px; max-width: 85%; white-space: pre-wrap; word-wrap: break-word; font-size: 14px; line-height: 1.5; }
  .msg.user \{ background: #2563eb; color: white; align-self: flex-end; }
  .msg.assistant \{ background: #222; border: 1px solid #333; align-self: flex-start; }
  .msg.system \{ background: #1a1a2e; border: 1px solid #333; align-self: center; font-size: 12px; color: #888; }
  .msg.pending \{ opacity: 0.5; }
  .empty \{ color: #555; font-size: 14px; padding: 40px 0; text-align: center; }
  #prompt-form \{ flex-shrink: 0; padding: 12px 0; border-top: 1px solid #333; }
  .input-row \{ display: flex; gap: 8px; }
  #input \{ flex: 1; padding: 10px 14px; border-radius: 8px; border: 1px solid #333; background: #1a1a1a; color: #eee; font-size: 14px; outline: none; resize: none; overflow-y: hidden; font-family: inherit; line-height: 1.5; max-height: 200px; }
  #input:focus \{ border-color: #2563eb; }
  button \{ padding: 10px 20px; border-radius: 8px; border: none; background: #2563eb; color: white; font-size: 14px; cursor: pointer; }
  button:hover \{ background: #1d4ed8; }
  .f3 \{ color: #888; }
  .mono \{ font-family: monospace; }
  .s-2 \{ font-size: 12px; }
  .hdr-btn \{ font-size: 11px; padding: 4px 10px; border-radius: 4px; border: 1px solid #444; background: none; color: #888; cursor: pointer; }
  .hdr-btn:hover \{ color: #eee; border-color: #666; }
  #cfg-backdrop \{ display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.6); z-index: 100; }
  #cfg-backdrop.open \{ display: flex; align-items: center; justify-content: center; }
  #cfg-modal \{ background: #1a1a1a; border: 1px solid #333; border-radius: 8px; width: 90%; max-width: 400px; padding: 20px; }
  #cfg-header \{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  #cfg-header span \{ font-size: 14px; font-weight: 600; }
  #cfg-header div \{ display: flex; gap: 6px; }
  .cfg-label \{ display: block; font-size: 12px; color: #888; margin: 12px 0 4px; }
  #cfg-model, #cfg-window, #cfg-msgcap, #cfg-proxy, #cfg-channel \{ width: 100%; padding: 8px 10px; border-radius: 6px; border: 1px solid #333; background: #111; color: #eee; font-size: 13px; font-family: monospace; outline: none; box-sizing: border-box; }
  #cfg-model:focus, #cfg-window:focus, #cfg-msgcap:focus, #cfg-proxy:focus, #cfg-channel:focus \{ border-color: #2563eb; }
  #cfg-status \{ margin-top: 10px; font-size: 12px; color: #4ade80; }
  #loading \{ height: 2px; background: transparent; overflow: hidden; flex-shrink: 0; }
  #loading.active \{ background: #333; }
  #loading.active::after \{ content: ''; display: block; height: 100%; width: 30%; background: #2563eb; animation: slide 1s ease-in-out infinite; }
  @keyframes slide \{ 0% \{ transform: translateX(-100%); } 100% \{ transform: translateX(400%); } }
  #abt-backdrop \{ display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.6); z-index: 100; }
  #abt-backdrop.open \{ display: flex; align-items: center; justify-content: center; }
  #abt-modal \{ background: #1a1a1a; border: 1px solid #333; border-radius: 8px; width: 90%; max-width: 400px; padding: 20px; }
  #abt-header \{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  #abt-header span \{ font-size: 14px; font-weight: 600; }
  #abt-header div \{ display: flex; gap: 6px; }
  #abt-status \{ margin-top: 10px; font-size: 12px; color: #4ade80; }
  #abt-text:focus \{ border-color: #2563eb; }
  #stop-btn \{ display: none; background: none; color: #f87171; border: 1px solid #f87171; padding: 10px 16px; }
  #stop-btn:hover \{ background: rgba(248,113,113,0.1); }
  #stop-btn.active \{ display: block; }
  #chat-list \{ flex: 1; display: flex; flex-direction: column; gap: 2px; }
  .chat-item \{ font-size: 13px; padding: 6px 12px; color: #888; cursor: pointer; display: flex; justify-content: space-between; align-items: center; border-radius: 4px; margin: 0 6px; }
  .chat-item:hover \{ color: #eee; background: #1a1a1a; }
  .chat-item.active \{ color: #eee; background: #1a1a2e; cursor: default; }
  .chat-del \{ font-size: 14px; color: #444; cursor: pointer; line-height: 1; opacity: 0; }
  .chat-item:hover .chat-del \{ opacity: 1; }
  .chat-del:hover \{ color: #f87171; }
  #new-chat-btn \{ font-size: 12px; padding: 6px 12px; margin: 4px 6px; border-radius: 4px; border: 1px dashed #333; background: none; color: #555; cursor: pointer; text-align: left; }
  #new-chat-btn:hover \{ color: #888; border-color: #555; background: none; }
  #menu-btn \{ display: none; font-size: 18px; padding: 4px 8px; border-radius: 4px; border: 1px solid #444; background: none; color: #888; cursor: pointer; line-height: 1; }
  #menu-btn:hover \{ color: #eee; border-color: #666; }
  #sidebar-overlay \{ display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 49; }
  #sidebar-overlay.open \{ display: block; }
  @media (max-width: 600px) \{
    #menu-btn \{ display: block; }
    #sidebar \{ position: fixed; top: 0; left: 0; bottom: 0; width: 220px; z-index: 50; background: #111; border-right: 1px solid #333; transform: translateX(-100%); transition: transform 0.2s ease; padding-top: 16px; }
    #sidebar.open \{ transform: translateX(0); }
    #main \{ padding: 0 10px; max-width: 100%; }
    .msg \{ max-width: 95%; font-size: 13px; }
    #header \{ padding: 10px 12px; }
    #header > div \{ flex-wrap: wrap; gap: 4px; }
    #input \{ font-size: 16px; }
    .input-row button \{ padding: 10px 14px; }
  }
  """
::
++  script-text
  |=  ball-id=tape
  ^-  tape
  ;:  weld
    "var API = '/grubbery/api';\0avar BALL = '{ball-id}';\0avar CHAT = new URLSearchParams(location.search).get('chat') || 'main';\0a"
  """
  function toggleSidebar() \{
    document.getElementById('sidebar').classList.toggle('open');
    document.getElementById('sidebar-overlay').classList.toggle('open');
  }

  function renderMessages(entries) \{
    var el = document.getElementById('messages');
    el.innerHTML = '';
    if (!entries || !entries.length) \{
      el.innerHTML = '<div class="empty">No messages yet</div>';
      return;
    }
    for (var i = 0; i < entries.length; i++) \{
      var e = entries[i];
      var div = document.createElement('div');
      if (e.type === 'tool_use') \{
        div.className = 'msg system';
        div.textContent = '[tool] ' + e.name;
      } else if (e.type === 'tool_result') \{
        div.className = 'msg system';
        div.textContent = '> ' + (e.content || '').slice(0, 200);
      } else if (e.role === 'user' && e.content && e.content.indexOf('[spawn_task result]:') === 0) \{
        div.className = 'msg system';
        div.textContent = '> ' + e.content.slice(20).trim().slice(0, 200);
      } else \{
        if (e.role === 'system') continue;
        div.className = 'msg ' + e.role;
        div.textContent = e.content;
      }
      el.appendChild(div);
    }
    el.scrollTop = el.scrollHeight;
  }

  var sseCtrl = null;
  var sseRdr = null;

  function sendMessage(e) \{
    e.preventDefault();
    var input = document.getElementById('input');
    var text = input.value.trim();
    if (!text) return;
    input.value = '';
    input.style.height = 'auto';
    fetch(API + '/poke/' + BALL + '/chats/' + CHAT + '/chat.json?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'message', content: text})
    });
  }

  var input = document.getElementById('input');
  input.addEventListener('input', function() \{
    this.style.height = 'auto';
    this.style.height = Math.min(this.scrollHeight, 200) + 'px';
  });
  input.addEventListener('keydown', function(e) \{
    if (e.key === 'Enter' && !e.shiftKey) \{
      e.preventDefault();
      sendMessage(e);
    }
  });

  document.getElementById('clear-btn').onclick = function() \{
    if (!confirm('Clear chat?')) return;
    fetch(API + '/poke/' + BALL + '/chats/' + CHAT + '/chat.json?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'clear'})
    });
  };

  // config modal
  document.getElementById('config-btn').onclick = function() \{
    fetch(API + '/file/' + BALL + '/config.json?mark=json')
      .then(function(r) \{ return r.json() })
      .then(function(cfg) \{
        document.getElementById('cfg-model').value = cfg.model || '';
        document.getElementById('cfg-proxy').value = cfg['api-proxy'] || 'anthropic';
        document.getElementById('cfg-window').value = cfg.context_window || '80000';
        document.getElementById('cfg-msgcap').value = cfg.message_cap || '20000';
        document.getElementById('cfg-channel').value = cfg.channel || '';
      }).catch(function() \{});
    document.getElementById('cfg-backdrop').classList.add('open');
  };
  document.getElementById('cfg-close').onclick = function() \{
    document.getElementById('cfg-backdrop').classList.remove('open');
  };
  document.getElementById('cfg-save').onclick = function() \{
    var model = document.getElementById('cfg-model').value.trim() || 'claude-sonnet-4-20250514';
    var proxy = document.getElementById('cfg-proxy').value.trim() || 'anthropic';
    var win = parseInt(document.getElementById('cfg-window').value) || 80000;
    var cap = parseInt(document.getElementById('cfg-msgcap').value) || 20000;
    var channel = document.getElementById('cfg-channel').value.trim();
    fetch(API + '/over/' + BALL + '/config.json?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{model: model, 'api-proxy': proxy, context_window: win, message_cap: cap, channel: channel})
    });
    document.getElementById('cfg-status').textContent = 'saved';
    setTimeout(function() \{
      document.getElementById('cfg-status').textContent = '';
      document.getElementById('cfg-backdrop').classList.remove('open');
    }, 800);
  };

  // about modal
  document.getElementById('about-btn').onclick = function() \{
    fetch(API + '/file/' + BALL + '/about.txt?mark=txt')
      .then(function(r) \{ return r.text() })
      .then(function(t) \{ document.getElementById('abt-text').value = t; })
      .catch(function() \{ document.getElementById('abt-text').value = ''; });
    document.getElementById('abt-status').textContent = '';
    document.getElementById('abt-backdrop').classList.add('open');
  };
  document.getElementById('abt-close').onclick = function() \{
    document.getElementById('abt-backdrop').classList.remove('open');
  };
  document.getElementById('abt-backdrop').onclick = function(e) \{
    if (e.target === this) this.classList.remove('open');
  };
  document.getElementById('abt-save').onclick = async function() \{
    var text = document.getElementById('abt-text').value;
    var r = await fetch(API + '/over/' + BALL + '/about.txt?mark=txt', \{
      method: 'POST',
      headers: \{'Content-Type': 'text/plain'},
      body: text
    });
    var st = document.getElementById('abt-status');
    if (r.ok) \{
      st.textContent = 'saved';
      st.style.color = '#4ade80';
      setTimeout(function() \{ document.getElementById('abt-backdrop').classList.remove('open'); }, 800);
    } else \{
      st.textContent = 'save failed';
      st.style.color = '#f87171';
    }
  };

  async function connectSSE() \{
    if (sseRdr) try \{ sseRdr.cancel(); } catch(e) \{}
    if (sseCtrl) sseCtrl.abort();
    sseCtrl = new AbortController();
    try \{
      var r = await fetch(API + '/keep/' + BALL + '/chats/' + CHAT + '/chat.json?mark=json', \{
        headers: \{Accept: 'text/event-stream'},
        signal: sseCtrl.signal
      });
      sseRdr = r.body.getReader();
      var dec = new TextDecoder();
      var buf = '';
      while (true) \{
        var chunk = await sseRdr.read();
        if (chunk.done) break;
        buf += dec.decode(chunk.value, \{stream: true});
        var evts = buf.split('\\n\\n');
        buf = evts.pop();
        for (var i = 0; i < evts.length; i++) \{
          if (!evts[i].trim()) continue;
          var data = '';
          var lines = evts[i].split('\\n');
          for (var j = 0; j < lines.length; j++) \{
            if (lines[j].indexOf('data: ') === 0) data += lines[j].slice(6);
          }
          if (!data) continue;
          try \{
            var msgs = JSON.parse(data);
            renderMessages(msgs);
          } catch(e) \{}
        }
      }
    } catch(e) \{
      if (e.name !== 'AbortError') setTimeout(connectSSE, 2000);
    }
  }

  window.addEventListener('beforeunload', function() \{
    if (sseRdr) try \{ sseRdr.cancel(); } catch(e) \{}
    if (sseCtrl) sseCtrl.abort();
    if (statusEs) statusEs.close();
    if (chatListEs) chatListEs.close();
  });

  // Stop button
  var stopBtn = document.getElementById('stop-btn');
  var currentStatus = \{state: 'idle'};
  stopBtn.onclick = function() \{
    if (currentStatus.state === 'idle') return;
    if (currentStatus.state === 'tool') \{
      if (!confirm('Abort tool? This may leave state inconsistent.')) return;
      fetch(API + '/poke/' + BALL + '/chats/' + CHAT + '/chat.json?mark=json', \{
        method: 'POST',
        headers: \{'Content-Type': 'application/json'},
        body: JSON.stringify(\{action: 'interrupt', id: currentStatus.id})
      });
    } else \{
      fetch(API + '/poke/' + BALL + '/chats/' + CHAT + '/chat.json?mark=json', \{
        method: 'POST',
        headers: \{'Content-Type': 'application/json'},
        body: JSON.stringify(\{action: 'interrupt'})
      });
    }
  };

  // Status SSE
  var statusEs = null;
  function connectStatusSSE() \{
    if (statusEs) statusEs.close();
    statusEs = new EventSource(API + '/keep/' + BALL + '/chats/' + CHAT + '/status.json?mark=json');
    statusEs.addEventListener('upd status.json', function(e) \{
      try \{
        var s = JSON.parse(e.data);
        currentStatus = s;
        var ld = document.getElementById('loading');
        if (s.state !== 'idle') \{
          ld.classList.add('active');
          stopBtn.classList.add('active');
          stopBtn.textContent = s.state === 'tool' ? 'abort' : 'stop';
        } else \{
          ld.classList.remove('active');
          stopBtn.classList.remove('active');
          stopBtn.textContent = 'stop';
        }
      } catch(x) \{}
    });
    statusEs.onerror = function() \{ statusEs.close(); statusEs = null; setTimeout(connectStatusSSE, 2000); };
  }

  // Load chat
  fetch(API + '/file/' + BALL + '/chats/' + CHAT + '/chat.json?mark=json')
    .then(function(r) \{ return r.json() })
    .then(renderMessages)
    .catch(function() \{});
  // Load current status
  fetch(API + '/file/' + BALL + '/chats/' + CHAT + '/status.json?mark=json')
    .then(function(r) \{ return r.json() })
    .then(function(s) \{
      currentStatus = s;
      var ld = document.getElementById('loading');
      if (s.state !== 'idle') \{
        ld.classList.add('active');
        stopBtn.classList.add('active');
        stopBtn.textContent = s.state === 'tool' ? 'abort' : 'stop';
      }
    }).catch(function() \{});
  connectSSE();
  connectStatusSSE();

  // Chat list via SSE
  var chatListEs = null;
  var pendingNav = null;

  function renderChatList(names, skipCache) \{
    if (!Array.isArray(names) || !names.length) names = ['main'];
    if (!skipCache) try \{ sessionStorage.setItem('claw-chats', JSON.stringify(names)); } catch(x) \{}
    // navigate after create/delete if pending
    if (pendingNav) \{
      var target = pendingNav;
      if (target.charAt(0) === '+' && names.indexOf(target.slice(1)) >= 0) \{
        pendingNav = null;
        location.search = '?chat=' + target.slice(1);
        return;
      }
      if (target.charAt(0) === '-' && names.indexOf(target.slice(1)) < 0) \{
        pendingNav = null;
        if (target.slice(1) === CHAT) \{ location.search = '?chat=main'; return; }
      }
    }
    var el = document.getElementById('chat-list');
    el.innerHTML = '';
    for (var i = 0; i < names.length; i++) \{
      var name = names[i];
      var item = document.createElement('div');
      item.className = 'chat-item' + (name === CHAT ? ' active' : '');
      var label = document.createElement('span');
      label.textContent = name;
      item.appendChild(label);
      if (name !== CHAT) \{
        item.setAttribute('data-chat', name);
        item.onclick = function() \{ location.search = '?chat=' + this.getAttribute('data-chat'); };
      }
      var del = document.createElement('span');
      del.className = 'chat-del';
      del.textContent = String.fromCharCode(215);
      del.setAttribute('data-chat', name);
      del.onclick = function(e) \{
        e.stopPropagation();
        var n = this.getAttribute('data-chat');
        if (!confirm('Delete chat "' + n + '"?')) return;
        pendingNav = '-' + n;
        fetch(API + '/poke/' + BALL + '/main.sig?mark=json', \{
          method: 'POST',
          headers: \{'Content-Type': 'application/json'},
          body: JSON.stringify(\{action: 'delete-chat', name: n})
        });
      };
      item.appendChild(del);
      el.appendChild(item);
    }
  }

  function connectChatListSSE() \{
    if (chatListEs) chatListEs.close();
    chatListEs = new EventSource(API + '/keep/' + BALL + '/ui/chats.json?mark=json');
    chatListEs.addEventListener('upd chats.json', function(e) \{
      try \{ renderChatList(JSON.parse(e.data)); } catch(x) \{}
    });
    chatListEs.onerror = function() \{
      chatListEs.close();
      chatListEs = null;
      setTimeout(connectChatListSSE, 2000);
    };
  }

  document.getElementById('new-chat-btn').onclick = function() \{
    var name = prompt('Chat name (lowercase, no spaces):');
    if (!name) return;
    name = name.toLowerCase().replace(/[^a-z0-9\\-]/g, '-').replace(/^-|-$/g, '');
    if (!name) return;
    pendingNav = '+' + name;
    fetch(API + '/poke/' + BALL + '/main.sig?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'create-chat', name: name})
    });
  };

  try \{ var cached = JSON.parse(sessionStorage.getItem('claw-chats')); if (cached) renderChatList(cached, true); } catch(x) \{}
  fetch(API + '/file/' + BALL + '/ui/chats.json?mark=json')
    .then(function(r) \{ return r.json() })
    .then(function(d) \{ renderChatList(d); })
    .catch(function() \{ if (!sessionStorage.getItem('claw-chats')) renderChatList(['main']); });
  connectChatListSSE();

  // Push notification subscription (matches web-pusher pattern)
  function urlB64ToUint8(b64) \{
    var pad = '='.repeat((4 - b64.length % 4) % 4);
    var raw = atob((b64 + pad).split('-').join('+').split('_').join('/'));
    var arr = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) arr[i] = raw.charCodeAt(i);
    return arr;
  }
  function bufToB64Url(buf) \{
    var bytes = new Uint8Array(buf);
    var s = '';
    for (var i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
    return btoa(s).split('+').join('-').split('/').join('_').split('=').join('');
  }
  (async function() \{
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) return;
    try \{
      var reg = await navigator.serviceWorker.register('/grubbery/push/sw', \{scope: '/'});
      if (!reg.active) \{
        await new Promise(function(resolve) \{
          var sw = reg.installing || reg.waiting;
          if (!sw) return resolve();
          sw.addEventListener('statechange', function() \{
            if (sw.state === 'activated') resolve();
          });
        });
      }
      var sub = await reg.pushManager.getSubscription();
      if (sub) return;
      var resp = await fetch('/grubbery/push/vapid-key');
      var vapidKey = await resp.text();
      sub = await reg.pushManager.subscribe(\{
        userVisibleOnly: true,
        applicationServerKey: urlB64ToUint8(vapidKey)
      });
      var p256dh = bufToB64Url(sub.getKey('p256dh'));
      var auth = bufToB64Url(sub.getKey('auth'));
      await fetch('/grubbery/push/subscribe', \{
        method: 'POST',
        headers: \{'Content-Type': 'application/json'},
        body: JSON.stringify(\{endpoint: sub.endpoint, p256dh: p256dh, auth: auth})
      });
    } catch(e) \{ console.log('Push registration failed:', e); }
  })();
  """
  ==

::
::  built-in tools
::
::  +get-arg: extract a string argument from tool state
::
++  get-arg
  |=  [st=tool-state:nex-tools key=@t]
  ^-  (unit @t)
  (bind (~(get by args.st) key) |=(j=json ?>(?=(%s -.j) p.j)))
::
::  +agent-road: adjust a road so relative paths resolve from the agent root
::
::  Tools run at /proc/tools/[tid], two levels below the agent. The LLM thinks
::  in terms of the agent directory, so ./foo should mean agent-root/foo,
::  not /proc/tools/[tid]/foo. This prepends ../../ to relative roads.
::
++  agent-road
  |=  raw=@t
  ^-  road:tarball
  =/  t=tape  (trip raw)
  =/  adjusted=@t
    ::  only adjust ./ (agent-relative), not ../ (already traversing)
    ?:  =("./" (scag 2 t))
      (crip (weld "../../" (slag 2 t)))
    ::  bare ../ paths: add two more levels to account for tool depth
    ?:  =(".." (scag 2 t))
      (crip (weld "../../" t))
    raw
  (cord-to-road:tarball adjusted)
::
::
++  browse-tool
  ^-  tool:nex-tools
  |%
  ++  name  'browse'
  ++  description
    ^~  %-  crip
    ;:  weld
      "List files and subdirectories at a path in this nexus. "
      "Accepts a road string: absolute (/proc/tools/) or "
      "relative (./context/, ../). Trailing slash for directories."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to a directory (e.g. "/", "./context/", "./apps/")']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    ;<  =seen:nexus  bind:m  (peek:io road ~)
    ?.  ?=([%& %ball *] seen)
      (pure:m [%error (crip "Not a directory: {(trip u.raw)}")])
    =/  sub-dirs=(list @ta)  ~(tap in ~(key by dir.ball.p.seen))
    =/  files=(list [@ta @tas])
      ?~  fil.ball.p.seen  ~
      %+  turn  ~(tap by contents.u.fil.ball.p.seen)
      |=([n=@ta c=content:tarball] [n name.p.sage.c])
    =/  dir-text=tape
      ?~  sub-dirs  ""
      (zing (turn sub-dirs |=(d=@ta "\0a  {(trip d)}/")))
    =/  file-text=tape
      ?~  files  ""
      (zing (turn files |=([n=@ta *] "\0a  {(trip n)}")))
    (pure:m [%text (crip :(weld (trip u.raw) dir-text file-text))])
  --
::
++  read-tool
  ^-  tool:nex-tools
  |%
  ++  name  'read'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Read a file from this nexus. Paths are relative to the agent root "
      "(e.g. ./config.json, ./context/chat.json) or absolute. "
      "Use offset/limit to read a specific line range from large files."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    ^-  (list [@t parameter-def:nex-tools])
    :~  ['road' [%string 'Path to a file (e.g. "./config.json")']]
        ['offset' [%number 'Start line (1-indexed, default: 1)']]
        ['limit' [%number 'Max lines to return (default: all)']]
    ==
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    ;<  =seen:nexus  bind:m  (peek:io road ~)
    ?.  ?=([%& %file *] seen)
      (pure:m [%error (crip "Not found: {(trip u.raw)}")])
    =/  off=@ud
      =/  v  (~(get by args.st) 'offset')
      ?~  v  0
      ?:  ?=(%n -.u.v)  (fall (rush p.u.v dem) 0)
      ?:  ?=(%s -.u.v)  (fall (rush p.u.v dem) 0)
      0
    =/  lim=@ud
      =/  v  (~(get by args.st) 'limit')
      ?~  v  0
      ?:  ?=(%n -.u.v)  (fall (rush p.u.v dem) 0)
      ?:  ?=(%s -.u.v)  (fall (rush p.u.v dem) 0)
      0
    ?:  &(=(0 off) =(0 lim))
      ::  no range specified, return full file
      (render-grub-content:nex-tools seen)
    ::  range read: convert to text and slice by lines
    ;<  =mime  bind:m  (sage-to-mime:io sage.p.seen)
    =/  text=tape  (trip ;;(@t q.q.mime))
    =/  lines=(list tape)  (to-lines text)
    =/  total=@ud  (lent lines)
    =/  start=@ud  ?:(=(0 off) 0 (dec off))
    =/  sliced=(list tape)
      =/  after=(list tape)  (slag start lines)
      ?:(=(0 lim) after (scag lim after))
    =/  end=@ud  (add start (lent sliced))
    =/  header=tape
      "[mark: {(spud (snoc path.p.sage.p.seen name.p.sage.p.seen))}] [lines {<(add start 1)>}-{<end>} of {<total>}]\0a"
    =/  numbered=tape
      %-  zing
      =/  n=@ud  (add start 1)
      |-
      ?~  sliced  ~
      =/  line=tape  :(weld (a-co:co n) "\09" i.sliced "\0a")
      [line $(sliced t.sliced, n +(n))]
    (pure:m [%text (crip (weld header numbered))])
  --
::
++  write-tool
  ^-  tool:nex-tools
  |%
  ++  name  'write'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Write a file in this nexus. "
      "Accepts a road string pointing to a file: "
      "absolute (/config.json) or relative (./apps/code/lib/tools/my-tool.hoon). "
      "Creates the file if it doesn't exist, overwrites if it does. "
      "Set mark to store as a specific mark (e.g. \"hoon\", \"/wallet/account\"). "
      "Without mark, stores as raw mime. "
      "Content is passed through mime conversion."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['road' [%string 'Road to a file (e.g. "./config.json", "./apps/code/lib/tools/foo.hoon")']]
        ['content' [%string 'Text content to write']]
        ['mark' [%string 'Target mark as a blot path (e.g. "hoon", "/wallet/account"). Omit to store as mime.']]
    ==
  ++  required  ~['road' 'content']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    ?~  content=(get-arg st 'content')
      (pure:m [%error 'Missing required argument: content'])
    =/  dest-blot=(unit blot:tarball)
      ?~  mk=(get-arg st 'mark')  ~
      ?:  =('' u.mk)  ~
      ::  parse as blot path
      =/  pax=path
        ?:  =('/' (end 3 u.mk))  (stab u.mk)
        (stab (cat 3 '/' u.mk))
      ?~  pax  ~
      `[(snip `path`pax) (rear pax)]
    =/  road=road:tarball  (agent-road u.raw)
    =/  src-mime=mime  [/text/plain (as-octs:mimes:html u.content)]
    ;<  exists=?  bind:m  (peek-exists:io road)
    ?:  exists
      ?^  dest-blot
        (pure:m [%error 'Cannot change blot of existing file. Delete it first, then recreate with the desired blot.'])
      ;<  ~  bind:m  (over:io road [[/ %mime] !>(src-mime)])
      (pure:m [%text (crip "Wrote {(trip u.raw)}")])
    ;<  ~  bind:m  (make:io road |+[%.n [[/ %mime] !>(src-mime)] dest-blot])
    (pure:m [%text (crip "Created {(trip u.raw)}")])
  --
::
++  edit-tool
  ^-  tool:nex-tools
  |%
  ++  name  'edit'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Edit a file via exact string replacement. "
      "Fails if old_string is not found or matches multiple locations. "
      "Set replace_all to replace every occurrence."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  ~(gas by *(map @t parameter-def:nex-tools))
    :~  ['road' [%string 'Road to the file to edit']]
        ['old_string' [%string 'Exact text to find and replace']]
        ['new_string' [%string 'Replacement text']]
        ['replace_all' [%boolean 'Replace all occurrences (default: false)']]
    ==
  ++  required  ~['road' 'old_string' 'new_string']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    ?~  old=(get-arg st 'old_string')
      (pure:m [%error 'Missing required argument: old_string'])
    ?~  new=(get-arg st 'new_string')
      (pure:m [%error 'Missing required argument: new_string'])
    =/  replace-all=?
      =/  ra  (~(get by args.st) 'replace_all')
      ?~  ra  %.n
      ?:  ?=([~ %b *] ra)  p.u.ra
      %.n
    =/  road=road:tarball  (agent-road u.raw)
    ;<  =seen:nexus  bind:m  (peek:io road ~)
    ?.  ?=([%& %file *] seen)
      (pure:m [%error (crip "Not found: {(trip u.raw)}")])
    ;<  =mime  bind:m  (sage-to-mime:io sage.p.seen)
    =/  txt=tape  (trip q.q.mime)
    =/  result=(each tape @tas)
      (tape-replace:nex-tools txt (trip u.old) (trip u.new) replace-all)
    ?.  ?=(%& -.result)
      ?+  p.result
        (pure:m [%error 'Edit failed'])
          %not-found
        (pure:m [%error 'old_string not found in file'])
          %not-unique
        (pure:m [%error 'old_string matches multiple locations. Provide more context or set replace_all.'])
          %empty-search
        (pure:m [%error 'old_string cannot be empty'])
      ==
    =/  new-mime=^mime  [/text/plain (as-octs:mimes:html (crip p.result))]
    ;<  ~  bind:m  (over:io road [[/ %mime] !>(new-mime)])
    (pure:m [%text (crip "Edited {(trip u.raw)}")])
  --
::
++  delete-tool
  ^-  tool:nex-tools
  |%
  ++  name  'delete'
  ++  description  'Delete a file from this nexus.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to the file to delete']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    ;<  ~  bind:m  (cull:io road)
    (pure:m [%text (crip "Deleted {(trip u.raw)}")])
  --
::
++  mkdir-tool
  ^-  tool:nex-tools
  |%
  ++  name  'mkdir'
  ++  description  'Create a directory in this nexus.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to the directory to create (e.g. "/children/my-thing/")']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    =/  new-ball=ball:tarball  [`[~ ~ ~] ~]
    ;<  ~  bind:m  (make:io road &+[*sand:nexus *gain:nexus new-ball])
    (pure:m [%text (crip "Created directory {(trip u.raw)}")])
  --
::
++  create-nexus-tool
  ^-  tool:nex-tools
  |%
  ++  name  'create_nexus'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Create a nexus (directory with code) in this nexus. "
      "Provide the road for the new directory and the code "
      "path pointing to the nexus source (e.g. /claw/agent)."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['road' [%string 'Road to the new nexus directory']]
        ['code' [%string 'Code path as a rail (e.g. "/nex/claw/agent")']]
    ==
  ++  required  ~['road' 'code']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    ?~  code-raw=(get-arg st 'code')
      (pure:m [%error 'Missing required argument: code'])
    =/  road=road:tarball  (agent-road u.raw)
    =/  code-pax=path  (stab u.code-raw)
    ?~  code-pax
      (pure:m [%error 'Code path cannot be empty'])
    =/  code-rail=rail:tarball  [(snip `path`code-pax) (rear code-pax)]
    =/  new-ball=ball:tarball  [`[~ `code-rail ~] ~]
    ;<  ~  bind:m  (make:io road &+[*sand:nexus *gain:nexus new-ball])
    (pure:m [%text (crip "Created nexus {(trip u.raw)} with code {(trip u.code-raw)}")])
  --
::
++  delete-nexus-tool
  ^-  tool:nex-tools
  |%
  ++  name  'delete_nexus'
  ++  description  'Delete a nexus directory and all its contents.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to the nexus directory to delete']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    ;<  ~  bind:m  (cull:io road)
    (pure:m [%text (crip "Deleted nexus {(trip u.raw)}")])
  --
::
++  read-manual-tool
  ^-  tool:nex-tools
  |%
  ++  name  'read_manual'
  ++  description  'Look up on-manu documentation for any path. Use to understand what a directory or file does.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to look up docs for']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    ;<  doc=@t  bind:m  (manu-road:io road)
    ?:  =('' doc)
      (pure:m [%text (crip "No documentation found for {(trip u.raw)}")])
    (pure:m [%text doc])
  --
::
++  read-font-tool
  ^-  tool:nex-tools
  |%
  ++  name  'read_font'
  ++  description  'Find which code namespace governs a path.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to query']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    ;<  res=(unit bend:tarball)  bind:m  (get-font:io road)
    ?~  res
      (pure:m [%text (crip "No code found governing {(trip u.raw)}")])
    (pure:m [%text (crip "Code: {(trip (road-to-cord:tarball [%| u.res]))}")])
  --
::
++  read-weir-tool
  ^-  tool:nex-tools
  |%
  ++  name  'read_weir'
  ++  description  'Read sandbox (weir) rules for a directory. Shows which roads are allowed for write, poke, and read.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to the directory to inspect (e.g. "./" or "./children/")']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  dir-road=road:tarball  (agent-road u.raw)
    ;<  dir-seen=seen:nexus  bind:m  (peek:io dir-road ~)
    ?.  ?=([%& %ball *] dir-seen)
      (pure:m [%error (crip "Not a directory or not found: {(trip u.raw)}")])
    =/  weir=weir:nexus  (fall fil.sand.p.dir-seen [~ ~ ~])
    ?:  &(=(~ make.weir) =(~ poke.weir) =(~ peek.weir))
      (pure:m [%text (crip "No weir at {(trip u.raw)} -- unrestricted")])
    =/  render
      |=  roads=(set road:tarball)
      ^-  tape
      =/  lst=(list road:tarball)  ~(tap in roads)
      ?~  lst  "  (none)\0a"
      %-  zing
      %+  turn  lst
      |=(=road:tarball "  {(trip (road-to-cord:tarball road))}\0a")
    %-  pure:m
    :-  %text
    %-  crip
    ;:  weld
      "Weir at {(trip u.raw)}:\0a\0a"
      "write (make) allowed:\0a"  (render make.weir)
      "\0apoke allowed:\0a"  (render poke.weir)
      "\0aread (peek) allowed:\0a"  (render peek.weir)
    ==
  --
::
++  add-weir-tool
  ^-  tool:nex-tools
  |%
  ++  name  'add_weir'
  ++  description  'Add a sandbox (weir) rule to a directory. Categories: write, poke, read.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['road' [%string 'Road to the directory to add the rule to']]
        ['category' [%string 'Rule category: "write", "poke", or "read"']]
        ['allow_road' [%string 'Road to allow (e.g. "/" for root, "./apps/" for apps dir)']]
    ==
  ++  required  ~['road' 'category' 'allow_road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    ?~  cat=(get-arg st 'category')
      (pure:m [%error 'Missing required argument: category'])
    ?~  allow=(get-arg st 'allow_road')
      (pure:m [%error 'Missing required argument: allow_road'])
    =/  dir-road=road:tarball  (agent-road u.raw)
    =/  allow-road=road:tarball  (cord-to-road:tarball u.allow)
    ;<  dir-seen=seen:nexus  bind:m  (peek:io dir-road ~)
    =/  cur=weir:nexus
      ?.  ?=([%& %ball *] dir-seen)  [~ ~ ~]
      (fall fil.sand.p.dir-seen [~ ~ ~])
    =/  new=weir:nexus
      ?+  u.cat  cur
        %'write'  cur(make (~(put in make.cur) allow-road))
        %'poke'   cur(poke (~(put in poke.cur) allow-road))
        %'read'   cur(peek (~(put in peek.cur) allow-road))
      ==
    ;<  ~  bind:m  (sand:io dir-road `new)
    (pure:m [%text (crip "Added {(trip u.cat)} rule to {(trip u.raw)}")])
  --
::
++  del-weir-tool
  ^-  tool:nex-tools
  |%
  ++  name  'del_weir'
  ++  description  'Remove a sandbox (weir) rule from a directory.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['road' [%string 'Road to the directory']]
        ['category' [%string 'Rule category: "write", "poke", or "read"']]
        ['allow_road' [%string 'Road to remove from the allow list']]
    ==
  ++  required  ~['road' 'category' 'allow_road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    ?~  cat=(get-arg st 'category')
      (pure:m [%error 'Missing required argument: category'])
    ?~  allow=(get-arg st 'allow_road')
      (pure:m [%error 'Missing required argument: allow_road'])
    =/  dir-road=road:tarball  (agent-road u.raw)
    =/  del-road=road:tarball  (cord-to-road:tarball u.allow)
    ;<  dir-seen=seen:nexus  bind:m  (peek:io dir-road ~)
    =/  cur=weir:nexus
      ?.  ?=([%& %ball *] dir-seen)  [~ ~ ~]
      (fall fil.sand.p.dir-seen [~ ~ ~])
    =/  new=weir:nexus
      ?+  u.cat  cur
        %'write'  cur(make (~(del in make.cur) del-road))
        %'poke'   cur(poke (~(del in poke.cur) del-road))
        %'read'   cur(peek (~(del in peek.cur) del-road))
      ==
    ;<  ~  bind:m  (sand:io dir-road `new)
    (pure:m [%text (crip "Removed {(trip u.cat)} rule from {(trip u.raw)}")])
  --
::
++  clear-weir-tool
  ^-  tool:nex-tools
  |%
  ++  name  'clear_weir'
  ++  description  'Clear all sandbox (weir) rules from a directory, giving it unrestricted access.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to the directory to clear']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    ;<  ~  bind:m  (sand:io road ~)
    (pure:m [%text (crip "Cleared weir from {(trip u.raw)}")])
  --
::
++  check-bin-tool
  ^-  tool:nex-tools
  |%
  ++  name  'check_bin'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Check if a build artifact compiled successfully. "
      "Provide the code namespace road and artifact name. "
      "Example: code_road='/apps/code/lib/tools/' name='my-tool' "
      "to check a compiled tool. Returns the error tang "
      "if compilation failed, or confirms success."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['code_road' [%string 'Road to code directory (e.g. "/apps/code/lib/tools/", "./code/lib/")']]
        ['name' [%string 'Artifact name (e.g. "my-tool")']]
    ==
  ++  required  ~['code_road' 'name']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'code_road')
      (pure:m [%error 'Missing required argument: code_road'])
    ?~  nam=(get-arg st 'name')
      (pure:m [%error 'Missing required argument: name'])
    =/  dir-road=road:tarball  (agent-road u.raw)
    =/  bin-name=@ta  (crip (trip u.nam))
    =/  code-road=road:tarball
      ?-  -.dir-road
        %&  ?-(-.p.dir-road %& dir-road, %| [%& %& p.p.dir-road bin-name])
        %|  ?-(-.q.p.dir-road %& dir-road, %| [%| p.p.dir-road %& p.q.p.dir-road bin-name])
      ==
    ;<  res=built:nexus  bind:m  (get-code-full:io code-road)
    ?:  ?=(%vase -.res)
      (pure:m [%text (crip "OK: {(trip u.raw)}{(trip u.nam)} compiled successfully")])
    ?.  ?=(%tang -.res)
      (pure:m [%text (crip "OK: {(trip u.raw)}{(trip u.nam)} -- non-vase artifact")])
    =/  rendered=tape
      %-  zing
      %+  turn  (flop tang.res)
      |=(=tank (weld ~(ram re tank) "\0a"))
    (pure:m [%text (crip "FAILED: {(trip u.raw)}{(trip u.nam)}\0a{rendered}")])
  --
::
++  check-bang-tool
  ^-  tool:nex-tools
  |%
  ++  name  'check_bang'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Check runtime health at a path. "
      "Returns any nexus-level or per-file errors (bangs). "
      "Use after writing code to see if anything broke. "
      "Example: road='/' to check the whole nexus."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to check (e.g. "/", "/apps/code/", "./code/")']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    ;<  res=(each bangs:nexus (unit tang))  bind:m  (get-bang:io road)
    ?:  ?=(%| -.res)
      ?~  p.res
        (pure:m [%error (crip "Path not found: {(trip u.raw)}")])
      =/  rendered=tape
        (zing (turn (flop u.p.res) |=(=tank (weld ~(ram re tank) "\0a"))))
      (pure:m [%error (crip "Query failed:\0a{rendered}")])
    =/  =bangs:nexus  p.res
    =/  out=tape  ""
    =?  out  ?=(^ bang.bangs)
      =/  rendered=tape
        (zing (turn (flop u.bang.bangs) |=(=tank (weld ~(ram re tank) "\0a"))))
      "NEXUS BANG:\0a{rendered}"
    =/  errs=(list [@ta (unit tang)])  ~(tap by err.bangs)
    =/  file-out=tape
      %-  zing
      %+  murn  errs
      |=  [name=@ta err=(unit tang)]
      ^-  (unit tape)
      ?~  err  ~
      =/  rendered=tape
        (zing (turn (flop u.err) |=(=tank (weld ~(ram re tank) "\0a"))))
      `"\0a{(trip name)}: BANGED\0a{rendered}"
    =.  out  (weld out file-out)
    ?:  =('' (crip out))
      (pure:m [%text (crip "OK: {(trip u.raw)} -- no errors")])
    (pure:m [%text (crip out)])
  --
::
++  outbox-tool
  ^-  tool:nex-tools
  |%
  ++  name  'outbox'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Append a result to outbox.json. "
      "Used to return results to a parent (spawned tasks) or post updates. "
      "Once written, no more messages are accepted."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['result' [%string 'The final result text to return']]
        ['status' [%string 'Status: "complete", "error", "partial" (default: "complete")']]
    ==
  ++  required  ~['result']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  result=(get-arg st 'result')
      (pure:m [%error 'Missing required argument: result'])
    =/  status=@t
      (fall (get-arg st 'status') 'complete')
    =/  result-json=json
      %-  pairs:enjs:format
      :~  ['status' s+status]
          ['result' s+u.result]
      ==
    ;<  here=rail:tarball  bind:m  get-here-abs:io
    =/  chat-name=@ta  (get-tool-chat-name here)
    =/  road=road:tarball  (agent-road (crip "./chats/{(trip chat-name)}/outbox.json"))
    ;<  cur=(list json)  bind:m  (read-outbox chat-name)
    =/  updated=json  [%a (snoc cur result-json)]
    ;<  ~  bind:m  (over:io road [[/ %json] !>(updated)])
    (pure:m [%text 'Finished -- result appended to outbox.json'])
  --
::
++  await-child-result
  |=  pfx=tape
  =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
  ^-  form:m
  =/  outbox-road=road:tarball
    (agent-road (crip "{pfx}/chats/main/outbox.json"))
  ::  drop any stale subscription from a previous run, then subscribe fresh
  ;<  ~  bind:m  (drop:io /spawn-result outbox-road)
  ;<  *  bind:m  (keep:io /spawn-result outbox-road ~)
  ::  check if outbox already has entries before waiting
  ;<  =seen:nexus  bind:m  (peek:io outbox-road ~)
  =/  existing=(list json)
    ?.  ?=([%& %file *] seen)  ~
    =/  outbox=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
    ?.  ?=(%a -.outbox)  ~
    p.outbox
  ?^  existing
    ;<  ~  bind:m  (drop:io /spawn-result outbox-road)
    ;<  result=tool-result:nex-tools  bind:m  (extract-child-result (rear existing))
    ::  clean up child nexus
    ;<  ~  bind:m  (cull:io (agent-road (crip "{pfx}/")))
    ~&  >  ["%claw: spawn_task cleaned up" pfx]
    (pure:m result)
  |-
  ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /spawn-result)
  ?:  ?=(%wake -.nw)  $
  ?.  ?=(%file -.view.nw)  $
  =/  outbox=json  (fall (mole |.(!<(json q.sage.view.nw))) *json)
  ?.  ?&  ?=(%a -.outbox)
          !=(~ p.outbox)
      ==
    $
  ;<  ~  bind:m  (drop:io /spawn-result outbox-road)
  ;<  result=tool-result:nex-tools  bind:m  (extract-child-result (rear p.outbox))
  ::  clean up child nexus
  ;<  ~  bind:m  (cull:io (agent-road (crip "{pfx}/")))
  ~&  >  ["%claw: spawn_task cleaned up" pfx]
  (pure:m result)
::
++  extract-child-result
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
  ^-  form:m
  ?~  jon  (pure:m [%error 'spawn_task: child outbox entry is empty'])
  ?.  ?=(%o -.jon)  (pure:m [%error 'spawn_task: child outbox entry is not an object'])
  =/  status=@t
    (fall (bind (~(get by p.jon) 'status') |=(j=json ?>(?=(%s -.j) p.j))) 'unknown')
  =/  result=@t
    (fall (bind (~(get by p.jon) 'result') |=(j=json ?>(?=(%s -.j) p.j))) 'no result text')
  ?:  =('error' status)
    (pure:m [%error result])
  (pure:m [%text result])
::
++  spawn-task-tool
  ^-  tool:nex-tools
  |%
  ++  name  'spawn_task'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Spawn a named child claw nexus to handle a task asynchronously. "
      "Creates the nexus at ./children/<name>/, copies config, "
      "and sends the message. Returns immediately with an ack, "
      "then delivers the final result when the child finishes. "
      "Use a short descriptive name unique to this task (e.g. 'research-api', 'build-parser')."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['name' [%string 'Unique name for the child (e.g. "research-api", "build-parser")']]
        ['message' [%string 'Task message to send to the child']]
        ['prompt' [%string 'System prompt for the child (written to /context/prompts/task.txt)']]
        ['code' [%string 'Code path for the nexus (default: "/claw/agent")']]
    ==
  ++  required  ~['name' 'message']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ::  if resuming from ack, skip creation -- just re-subscribe and wait
    ?:  =(%ack step.st)
      =/  pfx=tape
        =/  d=json  data.st
        ?~  d  ""
        ?.  ?=(%o -.d)  ""
        =/  v  (~(get by p.d) 'pfx')
        ?~  v  ""
        ?.  ?=(%s -.u.v)  ""
        (trip p.u.v)
      ?:  =(~ pfx)
        (pure:m [%error 'spawn_task: lost child path on restart'])
      (await-child-result pfx)
    ::  normal creation flow
    ?~  name=(get-arg st 'name')
      (pure:m [%error 'Missing required argument: name'])
    ?~  message=(get-arg st 'message')
      (pure:m [%error 'Missing required argument: message'])
    =/  code=@t  (fall (get-arg st 'code') '/claw/agent')
    =/  tid=@ta  (crip (cass:so (trip u.name)))
    =/  tid-t=tape  (trip tid)
    ::  create child nexus (agent-road adjusts for tool depth)
    =/  pfx=tape  "./children/{tid-t}"
    =/  child-road=road:tarball  (agent-road (crip "{pfx}/"))
    ::  check if child already exists
    ;<  exists=?  bind:m  (peek-exists:io (agent-road (crip "{pfx}/chats/main/chat.json")))
    ?:  exists
      (pure:m [%error (crip "Child '{tid-t}' already exists. Use a unique name.")])
    =/  code-pax=path  (stab code)
    ?~  code-pax
      (pure:m [%error 'Code path cannot be empty'])
    =/  code-rail=rail:tarball  [(snip `path`code-pax) (rear code-pax)]
    =/  new-ball=ball:tarball  [`[~ `code-rail ~] ~]
    ;<  ~  bind:m  (make:io child-road &+[*sand:nexus *gain:nexus new-ball])
    ::  read parent config (../../config.json from tool proc)
    ;<  parent-config=json  bind:m
      =/  m  (fiber:fiber:nexus ,json)
      =/  road=road:tarball  (agent-road './config.json')
      ;<  =seen:nexus  bind:m  (peek:io road ~)
      ?.  ?=([%& %file *] seen)  (pure:m *json)
      (pure:m (fall (mole |.(!<(json q.sage.p.seen))) *json))
    =/  child-config-road=road:tarball
      (agent-road (crip "{pfx}/config.json"))
    ;<  cfg-exists=?  bind:m  (peek-exists:io child-config-road)
    ;<  ~  bind:m
      ?:  cfg-exists
        (over:io child-config-road [[/ %json] !>(parent-config)])
      (make:io child-config-road |+[%.n [[/ %json] !>(parent-config)] ~])
    ::  write task prompt with finish instructions
    =/  base-instructions=@t
      %-  crip
      ;:  weld
        "You are running as a subtask of a parent nexus.\0a"
        "When you have completed your work, you MUST call the `outbox` tool "
        "with your result text in the `result` parameter.\0a"
        "This is the ONLY way to return your result to the parent. "
        "Do not just respond with text -- call `outbox`.\0a"
      ==
    =/  full-prompt=@t
      =/  user-prompt=(unit @t)  (get-arg st 'prompt')
      ?~  user-prompt  base-instructions
      (crip "{(trip base-instructions)}\0a{(trip u.user-prompt)}")
    =/  prompt-road=road:tarball
      (agent-road (crip "{pfx}/context/prompts/task.txt"))
    =/  prompt-wain=wain  (to-wain:format full-prompt)
    ;<  ~  bind:m
      =/  m  (fiber:fiber:nexus ,~)
      ;<  pex=?  bind:m  (peek-exists:io prompt-road)
      ?:  pex
        (over:io prompt-road [[/ %txt] !>(prompt-wain)])
      (make:io prompt-road |+[%.n [[/ %txt] !>(prompt-wain)] ~])
    ::  poke child with message
    =/  msg-json=json
      (pairs:enjs:format ~[['action' s+'message'] ['content' s+u.message]])
    =/  child-sig-road=road:tarball
      (agent-road (crip "{pfx}/chats/main/chat.json"))
    ;<  ~  bind:m
      (send-dart:io [%node /spawn-task child-sig-road %poke [[/ %json] !>(msg-json)]])
    ::  ack -- store pfx in data so we can resume on restart
    =/  ack-data=json
      %-  pairs:enjs:format
      :~  ['type' s+'text']
          ['text' s+(crip "Task started at ./children/{tid-t}/")]
          ['pfx' s+(crip pfx)]
      ==
    ;<  ~  bind:m
      (replace:io !>(`tool-state:nex-tools`[tool.st args.st %ack ack-data `ack-data]))
    ::  subscribe and wait for result
    (await-child-result pfx)
  --
::
++  grep-files-tool
  ^-  tool:nex-tools
  |%
  ++  name  'grep'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Search file contents for a string. Returns matching lines with "
      "file paths and line numbers. Optionally filter by path, name, or mark pattern."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['pattern' [%string 'Text string to search for']]
        ['path' [%string 'Directory path glob filter (e.g. "/context/*")']]
        ['name' [%string 'Filename glob filter (e.g. "*config*")']]
        ['mark' [%string 'Mark/extension glob filter (e.g. "hoon", "json")']]
    ==
  ++  required  ~['pattern']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'pattern')
      (pure:m [%error 'Missing required argument: pattern'])
    =/  search=tape  (trip u.raw)
    =/  pat-path=(unit @t)  (get-arg st 'path')
    =/  pat-name=(unit @t)  (get-arg st 'name')
    =/  pat-mark=(unit @t)  (get-arg st 'mark')
    ::  browse agent root
    ;<  agent-root=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%| /])
    ;<  =seen:nexus  bind:m  (peek:io agent-root ~)
    ?.  ?=([%& %ball *] seen)
      (pure:m [%error 'Could not read ball'])
    =/  candidates=(list [rail:tarball content:tarball])
      %+  skim  ~(tap ba:tarball ball.p.seen)
      |=  [=rail:tarball =content:tarball]
      =/  fp=tape  ?~(path.rail "/" (trip (spat path.rail)))
      =/  fn=tape  (trip name.rail)
      =/  fm=tape  (trip name.p.sage.content)
      ?&  ?~(pat-path %.y (glob-match:nex-tools (trip u.pat-path) fp))
          ?~(pat-name %.y (glob-match:nex-tools (trip u.pat-name) fn))
          ?~(pat-mark %.y (glob-match:nex-tools (trip u.pat-mark) fm))
      ==
    =|  results=(list tape)
    =/  total=@ud  0
    |-
    ?~  candidates
      ?~  results
        (pure:m [%text 'No matches found'])
      =/  out=tape  (zing (flop results))
      (pure:m [%text (crip "Found {<total>} matches:{out}")])
    =/  [=rail:tarball =content:tarball]  i.candidates
    =/  label=tape
      =/  pax=tape  ?~(path.rail "/" (trip (spat path.rail)))
      "{pax}/{(trip name.rail)}"
    ;<  file-road=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%& rail])
    ;<  file-seen=seen:nexus  bind:m  (peek:io file-road ~)
    ?.  ?=([%& %file *] file-seen)
      $(candidates t.candidates)
    ;<  =mime  bind:m  (sage-to-mime:io sage.p.file-seen)
    =/  text=tape  (trip ;;(@t q.q.mime))
    =/  lines=(list tape)  (to-lines text)
    =/  line-num=@ud  1
    =/  hits=(list tape)  ~
    |-
    ?~  lines
      =/  new-results=(list tape)
        ?~  hits  results
        (weld (flop hits) results)
      ^$(candidates t.candidates, results new-results, total (add total (lent hits)))
    =?  hits  !=(~ (find search i.lines))
      :_  hits
      "\0a{label}:{<line-num>}: {i.lines}"
    $(lines t.lines, line-num +(line-num))
  --
::
++  glob-files-tool
  ^-  tool:nex-tools
  |%
  ++  name  'glob'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Search for files by path, name, and/or mark. "
      "All patterns support * wildcards. Omitted filters match everything."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['path' [%string 'Directory path glob filter (e.g. "/context/*")']]
        ['name' [%string 'Filename glob filter (e.g. "*config*")']]
        ['mark' [%string 'Mark/extension glob filter (e.g. "hoon", "json")']]
    ==
  ++  required  ~
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    =/  pat-path=(unit @t)  (get-arg st 'path')
    =/  pat-name=(unit @t)  (get-arg st 'name')
    =/  pat-mark=(unit @t)  (get-arg st 'mark')
    ;<  agent-root=road:tarball  bind:m  (ancestor-road:io [/claw %agent] [%| /])
    ;<  =seen:nexus  bind:m  (peek:io agent-root ~)
    ?.  ?=([%& %ball *] seen)
      (pure:m [%error 'Could not read ball'])
    =/  matches=(list [rail:tarball @tas])
      %+  murn  ~(tap ba:tarball ball.p.seen)
      |=  [=rail:tarball =content:tarball]
      =/  fp=tape  ?~(path.rail "/" (trip (spat path.rail)))
      =/  fn=tape  (trip name.rail)
      =/  fm=tape  (trip name.p.sage.content)
      ?.  ?&  ?~(pat-path %.y (glob-match:nex-tools (trip u.pat-path) fp))
              ?~(pat-name %.y (glob-match:nex-tools (trip u.pat-name) fn))
              ?~(pat-mark %.y (glob-match:nex-tools (trip u.pat-mark) fm))
          ==
        ~
      `[rail name.p.sage.content]
    ?~  matches
      (pure:m [%text 'No matches found'])
    =/  result=tape
      %-  zing
      %+  turn  matches
      |=  [=rail:tarball mark=@tas]
      =/  pax=tape  ?~(path.rail "/" (trip (spat path.rail)))
      "\0a{pax}/{(trip name.rail)}"
    (pure:m [%text (crip "Found {<(lent matches)>} matches:{result}")])
  --
::
++  grep-history-tool
  ^-  tool:nex-tools
  |%
  ++  name  'grep_history'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Search the full conversation history (including messages outside the current "
      "context window) for a substring. Returns matching entries with their index, "
      "role, and the matching line. Use recall_messages to pull specific results "
      "into the current context."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    ~[['query' [%string 'Substring to search for (case-insensitive)']]]
  ++  required  ~['query']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'query')
      (pure:m [%error 'Missing required argument: query'])
    =/  query=tape  (cass (trip u.raw))
    ;<  here=rail:tarball  bind:m  get-here-abs:io
    =/  chat-name=@ta  (get-tool-chat-name here)
    =/  conv-road=road:tarball  (agent-road (crip "./chats/{(trip chat-name)}/chat.json"))
    ;<  =seen:nexus  bind:m  (peek:io conv-road ~)
    ?.  ?=([%& %file *] seen)
      (pure:m [%text 'Could not read chat.'])
    =/  jon=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
    =/  conv=convo  (parse-convo jon)
    =/  results=tape  ~
    =/  idx=@ud  0
    =/  walk=convo  conv
    |-
    ?~  walk
      ?~  results
        (pure:m [%text 'No matches found.'])
      (pure:m [%text (crip results)])
    =/  e=entry  i.walk
    =/  content=tape
      ?-  -.e
          %msg                (trip content.e)
          %tool-use           (weld "tool_use: " (trip name.e))
          %tool-result        (trip content.e)
          %tool-result-media  (trip text.e)
      ==
    =/  role=tape
      ?-  -.e
          %msg                (trip role.e)
          %tool-use           "assistant"
          %tool-result        "tool_result"
          %tool-result-media  "tool_result"
      ==
    ::  search each line of content
    =/  lines=(list tape)  (to-lines content)
    =/  line-hits=tape
      %-  zing
      %+  murn  lines
      |=  line=tape
      ^-  (unit tape)
      =/  lower=tape  (cass line)
      ?~  (find query lower)  ~
      =/  display=tape  ?:((gth (lent line) 200) (weld (scag 200 line) "...") line)
      `:(weld "[" (a-co:co idx) "] " role ": " display "\0a")
    %=  $
      walk   t.walk
      idx    +(idx)
      results  (weld results line-hits)
    ==
  --
::
++  recall-messages-tool
  ^-  tool:nex-tools
  |%
  ++  name  'recall_messages'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Include messages from the conversation history by index range. "
      "The content is resolved at assembly time from the full stored history. "
      "Use grep_history first to find relevant message indices."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['from' [%number 'Start message index (inclusive)']]
        ['to' [%number 'End message index (inclusive)']]
    ==
  ++  required  ~['from' 'to']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    =/  from=@ud
      =/  v  (~(get by args.st) 'from')
      ?~  v  0
      ?:  ?=(%n -.u.v)  (fall (rush p.u.v dem) 0)
      ?:  ?=(%s -.u.v)  (fall (rush p.u.v dem) 0)
      0
    =/  to=@ud
      =/  v  (~(get by args.st) 'to')
      ?~  v  0
      ?:  ?=(%n -.u.v)  (fall (rush p.u.v dem) 0)
      ?:  ?=(%s -.u.v)  (fall (rush p.u.v dem) 0)
      0
    ?:  (gth from to)
      (pure:m [%error '"from" must be <= "to"'])
    (pure:m [%text (crip "[ref:{(a-co:co from)}-{(a-co:co to)}]")])
  --
::
++  summarize-tool
  ^-  tool:nex-tools
  |%
  ++  name  'summarize'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Summarize conversation messages by sending them to the LLM. "
      "Accepts one or more message ranges (e.g. '0-5,20-30,50-60'). "
      "Gaps between ranges are visible to the LLM via index numbers. "
      "Use grep_history first to identify relevant message indices. "
      "Always specify what kind of summary you need in the prompt: "
      "process (step-by-step what happened), decisions (choices and reasoning), "
      "technical (tools/code/configs), or action-items (what's next). "
      "Summaries are saved to /summaries/ for future reference."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    ^-  (list [@t parameter-def:nex-tools])
    :~  ['ranges' [%string 'Message ranges: "0-5" or "0-5,20-30,50-60"']]
        ['prompt' [%string 'What kind of summary: process, decisions, technical, action-items, or custom instruction']]
    ==
  ++  required  ~['ranges']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    =/  ranges-raw=@t  (fall (get-arg st 'ranges') '')
    =/  ranges=(list [@ud @ud])  (parse-ranges ranges-raw)
    ?~  ranges
      (pure:m [%error 'Could not parse ranges. Use format: "0-5" or "0-5,20-30"'])
    =/  user-prompt=@t
      (fall (get-arg st 'prompt') 'Provide a concise chronological summary of what happened.')
    ::  read conversation
    ;<  here=rail:tarball  bind:m  get-here-abs:io
    =/  chat-name=@ta  (get-tool-chat-name here)
    =/  conv-road=road:tarball  (agent-road (crip "./chats/{(trip chat-name)}/chat.json"))
    ;<  =seen:nexus  bind:m  (peek:io conv-road ~)
    ?.  ?=([%& %file *] seen)
      (pure:m [%error 'Could not read chat.'])
    =/  jon=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
    =/  full=convo  (parse-convo jon)
    ::  slice all ranges and build transcript
    =/  transcript=tape
      %-  zing
      %+  turn  ranges
      |=  [from=@ud to=@ud]
      (render-range full from to)
    ?:  =(~ transcript)
      (pure:m [%error 'No messages in specified ranges.'])
    ::  read config for model + proxy + context window
    =/  cfg-road=road:tarball  (agent-road './config.json')
    ;<  cfg-seen=seen:nexus  bind:m  (peek:io cfg-road ~)
    =/  config=json
      ?.  ?=([%& %file *] cfg-seen)  *json
      (fall (mole |.(!<(json q.sage.p.cfg-seen))) *json)
    =/  model=@t
      =/  m  (get-str config 'model')
      ?:(=('' m) 'claude-sonnet-4-20250514' m)
    =/  api-name=@t
      =/  p  (get-str config 'api-proxy')
      ?:(=('' p) 'anthropic' p)
    =/  ctx-window=@ud  (get-num config 'context_window' 80.000)
    ::  truncate transcript to context window (~4 chars/token)
    =/  max-chars=@ud  (mul ctx-window 4)
    =/  truncated=?  (gth (lent transcript) max-chars)
    =?  transcript  truncated  (scag max-chars transcript)
    ::  build ranges label for header
    =/  ranges-label=tape
      %-  zing
      %+  join  ","
      ^-  (list tape)
      %+  turn  ranges
      |=  [from=@ud to=@ud]
      "{(a-co:co from)}-{(a-co:co to)}"
    =?  ranges-label  truncated
      "{ranges-label} (TRUNCATED to ~{(a-co:co ctx-window)} tokens)"
    ::  build request
    =/  payload=json
      %-  pairs:enjs:format
      :~  ['model' s+model]
          ['max_tokens' (numb:enjs:format 4.096)]
          :-  'system'
          :-  %s
          %-  crip
          =/  total=@ud  (lent full)
          ;:  weld
            "You are summarizing selected message ranges [{ranges-label}] "
            "from a conversation with {(a-co:co total)} messages total. "
            "Gaps in indices mean messages were skipped. "
            "Focus on the provided messages only.\0a\0a"
            "Rules:\0a"
            "- Use third-person perspective (never first-person)\0a"
            "- Be chronological and concrete\0a"
            "- Note problems encountered, changes in behavior, and breakthroughs\0a"
            "- Preserve key details and context, not just conclusions\0a\0a"
            "User instruction: "
            (trip user-prompt)
          ==
          :-  'messages'
          :-  %a
          :~  %-  pairs:enjs:format
              :~  ['role' s+'user']
                  ['content' s+(crip transcript)]
              ==
          ==
      ==
    ;<  proxy=road:tarball  bind:m
      (ancestor-road:io [/claw %app] [%& /apis/[api-name] %'main.sig'])
    ;<  eny=@uvJ  bind:m  get-entropy:io
    =/  call-id=@t  (scot %uv (end [3 8] eny))
    ;<  call-road=road:tarball  bind:m
      (ancestor-road:io [/claw %app] [%& /apis/[api-name]/calls (crip "{(trip call-id)}.json")])
    ;<  *  bind:m  (keep:io /sum-call call-road ~)
    =/  poke-body=json
      (pairs:enjs:format ~[['id' s+call-id] ['body' payload]])
    ;<  ~  bind:m  (poke:io proxy [/ %json] !>(poke-body))
    ;<  resp=json  bind:m  (await-sum-call /sum-call)
    ;<  ~  bind:m  (drop:io /sum-call call-road)
    =/  parsed=(unit api-response)  (parse-json-response resp)
    ?~  parsed
      (pure:m [%error 'Failed to parse API response.'])
    =/  text=@t
      %-  crip
      %-  zing
      %+  turn  content-blocks.u.parsed
      |=  =content-block
      ?+  -.content-block  ""
        %text  (trip text.content-block)
      ==
    =/  header=@t
      %-  crip
      ;:  weld
        "[Summary of messages [{ranges-label}] from "
        (a-co:co (lent full))
        " total]\0a"
      ==
    =/  summary-text=@t  (crip :(weld (trip header) (trip text)))
    ::  save to /summaries/
    =/  sum-id=@t  (scot %uv (end [3 8] eny))
    =/  sum-json=json
      %-  pairs:enjs:format
      :~  ['ranges' s+ranges-raw]
          ['prompt' s+user-prompt]
          ['summary' s+summary-text]
      ==
    ;<  sum-dir=road:tarball  bind:m
      (ancestor-road:io [/claw %agent] [%| /chats/[chat-name]/summaries])
    ;<  dir-exists=?  bind:m  (peek-exists:io sum-dir)
    ;<  ~  bind:m
      ?.  dir-exists
        (make:io sum-dir &+[*sand:nexus *gain:nexus [~ ~]])
      (pure:(fiber:fiber:nexus ,~) ~)
    =/  sum-file=@ta  (crip "{(trip sum-id)}.json")
    ;<  sum-road=road:tarball  bind:m
      (ancestor-road:io [/claw %agent] [%& /chats/[chat-name]/summaries sum-file])
    ;<  ~  bind:m  (make:io sum-road |+[%.n [[/ %json] !>(sum-json)] ~])
    (pure:m [%text summary-text])
  --
::
::  +cord-to-path: split "foo/bar/baz" into /foo/bar/baz
::
++  cord-to-path
  |=  src=@t
  ^-  path
  =/  t=tape  (trip src)
  ?~  t  /
  =/  pax=path
    %+  scan  t
    (more fas (cook crip (star ;~(less fas next))))
  (skip pax |=(s=@ta =('' s)))
::
::  +render-range: render a slice of convo as indexed transcript
::
++  render-range
  |=  [full=convo from=@ud to=@ud]
  ^-  tape
  =/  sliced=convo  (scag (add (sub to from) 1) (slag from full))
  %-  zing
  =/  idx=@ud  from
  |-
  ?~  sliced  ~
  =/  e=entry  i.sliced
  =/  line=tape
    ?-  -.e
      %msg                :(weld "[" (a-co:co idx) "] " (trip role.e) ": " (trip content.e) "\0a")
      %tool-use           :(weld "[" (a-co:co idx) "] tool_use: " (trip name.e) "\0a")
      %tool-result        :(weld "[" (a-co:co idx) "] tool_result: " (trip content.e) "\0a")
      %tool-result-media  :(weld "[" (a-co:co idx) "] tool_result: " (trip text.e) "\0a")
    ==
  [line $(sliced t.sliced, idx +(idx))]
::
::  +parse-ranges: parse "0-5,20-30" into (list [@ud @ud])
::
++  parse-ranges
  |=  raw=@t
  ^-  (list [@ud @ud])
  =/  t=tape  (trip raw)
  ::  strip whitespace
  =.  t  (skip t |=(c=@t =(c ' ')))
  ?~  t  ~
  %+  murn
    (split-on t ',')
  |=  seg=tape
  ^-  (unit [@ud @ud])
  =/  parts=(list tape)  (split-on seg '-')
  ?+  (lent parts)  ~
      %1
    =/  n=(unit @ud)  (rush (crip (snag 0 parts)) dem)
    ?~  n  ~
    `[u.n u.n]
      %2
    =/  a=(unit @ud)  (rush (crip (snag 0 parts)) dem)
    =/  b=(unit @ud)  (rush (crip (snag 1 parts)) dem)
    ?~  a  ~
    ?~  b  ~
    ?:  (gth u.a u.b)  ~
    `[u.a u.b]
  ==
::
::  +split-on: split tape on a character
::
++  split-on
  |=  [t=tape c=@t]
  ^-  (list tape)
  =/  acc=(list tape)  ~
  =/  cur=tape  ~
  |-
  ?~  t
    (flop [(flop cur) acc])
  ?:  =(i.t c)
    $(t t.t, acc [(flop cur) acc], cur ~)
  $(t t.t, cur [i.t cur])
::
::  +await-sum-call: wait for API call to reach status=done, return response
::
++  await-sum-call
  |=  =wire
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  |-
  ;<  upd=view:nexus  bind:m  (take-news:io wire)
  ?.  ?=([%file *] upd)  $
  =/  j=json  (fall (mole |.(!<(json q.sage.upd))) *json)
  ?.  ?=(%o -.j)  $
  =/  status=(unit json)  (~(get by p.j) 'status')
  ?.  ?=([~ %s %'done'] status)  $
  (pure:m (fall (~(get by p.j) 'response') [%o ~]))
::
++  list-agents-tool
  ^-  tool:nex-tools
  |%
  ++  name  'list_agents'
  ++  description
    ^~  %-  crip
    ;:  weld
      "List all sibling agents and their about.txt descriptions. "
      "Returns each agent's name and self-description so you can "
      "find the right agent to talk to for a task."
    ==
  ++  parameters  *(map @t parameter-def:nex-tools)
  ++  required  *(list @t)
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ;<  here=rail:tarball  bind:m  get-here-abs:io
    ::  path is .../agents/[name]/proc/tools; agent name is 3rd from end
    =/  self-name=@ta
      =/  p=path  path.here
      =/  l=@  (lent p)
      ?:  (lth l 3)  *@ta
      (snag (sub l 3) p)
    ::  peek at ../  (agents dir from agent root)
    =/  agents-road=road:tarball  (agent-road '../')
    ;<  =seen:nexus  bind:m  (peek:io agents-road ~)
    ?.  ?=([%& %ball *] seen)
      (pure:m [%error 'Could not read agents directory'])
    =/  names=(list @ta)
      (sort ~(tap in ~(key by dir.ball.p.seen)) aor)
    =/  out=(list tape)  ~
    |-
    ?~  names
      ?~  out
        (pure:m [%text 'No agents found.'])
      (pure:m [%text (crip (zing (flop out)))])
    =/  name=@ta  i.names
    =/  about-road=road:tarball
      (agent-road (crip "../{(trip name)}/about.txt"))
    ;<  about-seen=seen:nexus  bind:m  (peek:io about-road ~)
    =/  about=tape
      ?.  ?=([%& %file *] about-seen)  "(no about.txt)"
      =/  wn=(each wain tang)  (mule |.(!<(wain q.sage.p.about-seen)))
      ?.  ?=(%& -.wn)  "(unreadable)"
      (trip (of-wain:format p.wn))
    =/  tag=tape  ?:(=(name self-name) " [self]" "")
    =/  line=tape  "{(trip name)}{tag}: {about}\0a"
    $(names t.names, out [line out])
  --
::
++  search-agents-tool
  ^-  tool:nex-tools
  |%
  ++  name  'search_agents'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Search sibling agents' about.txt files for a keyword. "
      "Returns matching agents with their descriptions. "
      "Use this to find an agent with specific capabilities."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['query' [%string 'Keyword to search for in agent descriptions']]])
  ++  required  ~['query']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  query=(get-arg st 'query')
      (pure:m [%error 'Missing required argument: query'])
    ;<  here=rail:tarball  bind:m  get-here-abs:io
    =/  self-name=@ta
      =/  p=path  path.here
      =/  l=@  (lent p)
      ?:  (lth l 3)  *@ta
      (snag (sub l 3) p)
    =/  needle=tape  (cass:so (trip u.query))
    =/  agents-road=road:tarball  (agent-road '../')
    ;<  =seen:nexus  bind:m  (peek:io agents-road ~)
    ?.  ?=([%& %ball *] seen)
      (pure:m [%error 'Could not read agents directory'])
    =/  names=(list @ta)
      (sort ~(tap in ~(key by dir.ball.p.seen)) aor)
    =/  out=(list tape)  ~
    |-
    ?~  names
      ?~  out
        (pure:m [%text (crip "No agents matching '{(trip u.query)}'.")])
      (pure:m [%text (crip (zing (flop out)))])
    =/  name=@ta  i.names
    =/  about-road=road:tarball
      (agent-road (crip "../{(trip name)}/about.txt"))
    ;<  about-seen=seen:nexus  bind:m  (peek:io about-road ~)
    =/  about=tape
      ?.  ?=([%& %file *] about-seen)  ""
      =/  wn=(each wain tang)  (mule |.(!<(wain q.sage.p.about-seen)))
      ?.  ?=(%& -.wn)  ""
      (trip (of-wain:format p.wn))
    ::  case-insensitive match
    ?.  !=(~ (find needle (cass:so about)))
      $(names t.names)
    =/  tag=tape  ?:(=(name self-name) " [self]" "")
    =/  line=tape  "{(trip name)}{tag}: {about}\0a"
    $(names t.names, out [line out])
  --
::
++  cron-add-tool
  ^-  tool:nex-tools
  |%
  ++  name  'cron_add'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Add a scheduled cron job. The job fires a message to a chat on a "
      "recurring schedule. Cron format: 'min hour dom month dow' "
      "(e.g. '0 9 * * *' for daily at 9am, '*/5 * * * *' for every 5 min). "
      "dow: 0=Sun..6=Sat."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['schedule' [%string 'Cron expression (5 fields: min hour dom month dow)']]
        ['chat' [%string 'Target chat name to send the message to']]
        ['message' [%string 'Message content to send when the cron fires']]
        ['id' [%string 'Optional job ID (auto-generated if omitted)']]
    ==
  ++  required  ~['schedule' 'chat' 'message']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  schedule=(get-arg st 'schedule')
      (pure:m [%error 'Missing required argument: schedule'])
    ?~  chat=(get-arg st 'chat')
      (pure:m [%error 'Missing required argument: chat'])
    ?~  message=(get-arg st 'message')
      (pure:m [%error 'Missing required argument: message'])
    ::  validate cron expression
    ;<  now=@da  bind:m  get-time:io
    =/  next=(unit @da)  (next-cron-fire:cron u.schedule now)
    ?~  next
      (pure:m [%error (crip "Invalid cron expression: {(trip u.schedule)}")])
    ::  generate or use provided ID
    =/  job-id=@ta
      =/  raw=(unit @t)  (get-arg st 'id')
      ?^  raw  (crip (cass:so (trip u.raw)))
      (scot %uv (mix now (mug u.schedule)))
    ::  create proc/cron/{id} with state
    =/  cron-state=json
      %-  pairs:enjs:format
      :~  ['schedule' s+u.schedule]
          ['chat' s+u.chat]
          ['message' s+u.message]
      ==
    ;<  cron-road=road:tarball  bind:m
      (ancestor-road:io [/claw %agent] [%& /proc/cron job-id])
    ;<  ~  bind:m  (make:io cron-road |+[%.n [[/ %json] !>(cron-state)] ~])
    =/  msg=@t
      %-  crip
      ;:  weld
        "Cron job '{(trip job-id)}' created.\0a"
        "Schedule: {(trip u.schedule)}\0a"
        "Chat: {(trip u.chat)}\0a"
        "Next fire: {(scow %da u.next)}"
      ==
    (pure:m [%text msg])
  --
::
++  cron-list-tool
  ^-  tool:nex-tools
  |%
  ++  name  'cron_list'
  ++  description  'List all active cron jobs with their schedules, target chats, and messages.'
  ++  parameters  *(map @t parameter-def:nex-tools)
  ++  required  *(list @t)
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ;<  cron-road=road:tarball  bind:m
      (ancestor-road:io [/claw %agent] [%| /proc/cron])
    ;<  =seen:nexus  bind:m  (peek:io cron-road ~)
    ?.  ?=([%& %ball *] seen)
      (pure:m [%text 'No cron jobs.'])
    ?~  fil.ball.p.seen
      (pure:m [%text 'No cron jobs.'])
    =/  jobs=(list [@ta *])  ~(tap by contents.u.fil.ball.p.seen)
    =/  out=(list tape)  ~
    |-
    ?~  jobs
      ?~  out
        (pure:m [%text 'No cron jobs.'])
      (pure:m [%text (crip (zing (flop out)))])
    =/  [job-name=@ta *]  i.jobs
    =/  job-road=road:tarball
      (agent-road (crip "./proc/cron/{(trip job-name)}"))
    ;<  job-seen=seen:nexus  bind:m  (peek:io job-road `[/ %json])
    =/  line=tape
      ?.  ?=([%& %file *] job-seen)
        "{(trip job-name)}: (unreadable)\0a"
      =/  j=json  (fall (mole |.(!<(json q.sage.p.job-seen))) *json)
      ?.  ?=(%o -.j)  "{(trip job-name)}: (invalid state)\0a"
      =/  sched=@t  (fall (bind (~(get by p.j) 'schedule') |=(=json ?>(?=(%s -.json) p.json))) '?')
      =/  chat=@t   (fall (bind (~(get by p.j) 'chat') |=(=json ?>(?=(%s -.json) p.json))) '?')
      =/  msg=@t    (fall (bind (~(get by p.j) 'message') |=(=json ?>(?=(%s -.json) p.json))) '?')
      "{(trip job-name)}: [{(trip sched)}] -> {(trip chat)} \"{(trip (end 3^60 msg))}\"\0a"
    $(jobs t.jobs, out [line out])
  --
::
++  cron-remove-tool
  ^-  tool:nex-tools
  |%
  ++  name  'cron_remove'
  ++  description  'Remove a cron job by its ID. Use cron_list to see active jobs.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['id' [%string 'The cron job ID to remove']]])
  ++  required  ~['id']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  id=(get-arg st 'id')
      (pure:m [%error 'Missing required argument: id'])
    =/  job-id=@ta  (crip (cass:so (trip u.id)))
    ;<  cron-road=road:tarball  bind:m
      (ancestor-road:io [/claw %agent] [%& /proc/cron job-id])
    ;<  exists=?  bind:m  (peek-exists:io cron-road)
    ?.  exists
      (pure:m [%error (crip "Cron job not found: {(trip job-id)}")])
    ;<  ~  bind:m  (cull:io cron-road)
    (pure:m [%text (crip "Cron job '{(trip job-id)}' removed.")])
  --
--
