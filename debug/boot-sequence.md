# Boot Sequence Debugging

## Problem Summary
After refactoring the grubbery process system from a sequential queue-based model to a concurrent multi-threaded model with PIDs, the boot sequence broke. Specifically, the GUI endpoints `/grub/main` and `/grub/gui` are no longer accessible.

## Key Changes in Refactor
- **Old**: Sequential queue-based process model
- **New**: Concurrent multi-process with PIDs
- **Old**: Stems could emit effects `$-(bowl (quip dart vase))`  
- **New**: Stems are pure computations `$-(bowl vase)`

## Expected Boot Sequence
When grubbery app starts, it should:
1. Create `/boot` grub at line 263-269 in app/grubbery.hoon
2. Poke `/boot` with `/sig` 
3. Boot executes (lib/grubbery.hoon:188-254):
   - Creates type libraries (/noun, /ud, etc.)
   - Creates counter infrastructure
   - **Line 251**: Creates `/gui` grub AND pokes it with `/gui/init`
4. GUI receives `/gui/init` poke and calls `(eyre-connect /grub here.bowl)`
5. Eyre-connect sends a `%connect` poke back to grubbery to register HTTP endpoint

## Hypothesis
The concurrent process model may be preventing the GUI initialization from completing properly. The `eyre-connect` call might be failing or not completing in the new async model.

## Debugging Steps

### Step 1: Verify Boot Completed

**WARNING**: `:grubbery +dbug` produces too much output and crashes the dojo. Use `:grubbery +dbug [%state 'some-hoon']` to get specific data instead.

### Step 1: Check State Structure

Using `+dbug` to inspect grubbery state (app state contains: cone, trac, takes, sand, bindings, history)

```
:grubbery +dbug [%state 'fil.cone']          => ~  (no grub at root)
:grubbery +dbug [%state '~(key by dir.cone)'] => {~.lib ~.boot ~.bin}
```

Found grubs at:
- `/boot` - The boot grub exists
- `/bin` - Contains: {~.grubbery ~.add ~.zuse}
- `/lib` - Contains: {~.add}

**FINDING: NO `/gui` GRUB EXISTS!**

The boot sequence created `/boot` but the GUI grub is missing. This means either:
1. Boot never ran the GUI initialization 
2. The GUI initialization failed silently
3. The poke to boot failed to complete

### Step 2: Test if we can manually poke GUI

```
:grubbery &poke-base [~ /gui [/sig !>(~)]]
```
Result: Error at line 962 - "poking base /gui" but grub doesn't exist

This confirms `/gui` was never created during boot.

### Step 3: Check if boot process ran

Let's check if the boot grub received its initial poke. The boot sequence (app/grubbery.hoon:263-269) should:
1. Create `/boot` grub 
2. Poke it with `/sig`

The presence of `/boot` grub confirms step 1 happened, but we need to check if step 2 (the poke) completed.

- Ship restarted, continuing debug...