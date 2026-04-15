#!/bin/bash

# Load config — supports either a single "dest" string or a "dests" list
DESTS=$(python3 -c "
import json, os
cfg = json.load(open('config.json'))
dests = cfg.get('dests') or [cfg['dest']]
for d in dests:
    print(os.path.expanduser(d))
")
SOURCE="desk/"

sync_all() {
    while IFS= read -r dest; do
        rsync -av --delete "$SOURCE" "$dest"
    done <<< "$DESTS"
}

# Initial sync
echo "Starting sync: $SOURCE -> "
echo "$DESTS" | sed 's/^/  /'
sync_all

# Watch for changes and sync
fswatch -o "$SOURCE" | while read f; do
    echo "Change detected, syncing..."
    sync_all
    echo "Sync complete at $(date +%H:%M:%S)"
done
