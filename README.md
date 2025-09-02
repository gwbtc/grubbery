# Grubbery

A tree-shaped manager for stateful long-running processes.

https://drive.google.com/file/d/1fnvEjsRMLJqIRavDlDalbHzojQVCum5s/view?usp=drive_link

## Setup

### Installation
- Copy desk files to ship's pier
- Run `|commit %grubbery` in dojo
- Agent starts automatically via desk.bill

### Configuration
- Update `config.json` with ship path
- Run `./sync.sh` for live file watching

## Agent Interaction

### 1. Desk Modification

#### File Structure
- `desk/gub/` - Main grub directory
- `desk/gub/base/` - Base grub implementations
- `desk/gub/stem/` - Stem grub implementations
- `desk/gub/stud/` - Type definitions
- Additional libraries and resources throughout `desk/gub/`

#### Bill Configuration
- `desk/gub/bill.hoon` - Defines grub initialization
- Format: `[/path/in/namespace /name/of/base]`
- Example: `[/this/is/a/base /counter]`
- Only specifies bases (not stems)
- Bases start with bunt value of their specified state type

#### Workflow
- Edit files in `desk/gub/`
- Run `|commit %grubbery` to reload
- Changes update the namespace:
  - Code from `gub/` available as text in `lib/`
  - Code from `gub/` available as compiled code in `bin/`
- Import with `/-  name  /path/to/lib` at top of files

### 2. Dojo Interaction

#### Direct Pokes
- `:grubbery &grub-action [[/wire /path/to/grub] %make %base /counter ~]` - Make base grub
- `:grubbery &grub-action [[/wire /path/to/grub] %oust ~]` - Remove grub
- `:grubbery &grub-action [[/wire /path/to/grub] %cull ~]` - Recursively remove grub and descendants
- `:grubbery &grub-action [[/wire /path/to/grub] %sand ~]` - Set sandboxing
- `:grubbery &grub-action [[/wire /path/to/grub] %kill ~]` - Kill all processes
- `:grubbery &grub-action [[/wire /path/to/grub] %kill ~ 'pid']` - Kill specific process

#### Threads
- `-grubbery!poke [~ /path/to/grub /stud/path noun]` - Poke a base grub and await completion
- `-grubbery!bump [~ /path/to/grub 'pid' /stud/path noun]` - Bump a process
- `-grubbery!toss [~ /path/to/grub /stud/path noun]` - Poke a base grub without waiting for completion (returns process id)

### 3. Frontend

- Navigate to connected URL path /grub/main
- Relatively self-explanatory interface
- Deeply inadequate in many ways
- Many opportunities for improvement
