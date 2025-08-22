#!/bin/bash

# Load config
DEST=$(python3 -c "import json; print(json.load(open('config.json'))['dest'])")
SOURCE="desk/"

# Initial sync
echo "Starting sync: $SOURCE -> $DEST"
rsync -av --delete "$SOURCE" "$DEST"

# Watch for changes and sync
fswatch -o "$SOURCE" | while read f; do
    echo "Change detected, syncing..."
    rsync -av --delete "$SOURCE" "$DEST"
    echo "Sync complete at $(date +%H:%M:%S)"
done