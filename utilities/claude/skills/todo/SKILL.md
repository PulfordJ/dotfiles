---
name: todo
description: Add, remove, tick off or list items on John's personal TODO list — the `TODO.md` note in the "Test" Obsidian vault in Google Drive. Use from any repo whenever the user asks to add something to / remove something from / mark done / show their todo list (e.g. "/todo add renew passport", "add 'call dentist' to my todo list", "remove gym from my todos", "what's on my todo list?"). Not for a repo's own TODO files or Claude's internal task list.
argument-hint: "[add|remove|list] <item>"
---

# Personal TODO list (Obsidian "Test" vault)

The list lives in a single Obsidian note synced by Google Drive for Desktop.

## Locate the note

Use the first path that exists:

1. WSL: `/mnt/c/Users/johnp/My Drive/DriveSyncFiles/Test/TODO.md`
2. macOS: `~/Library/CloudStorage/GoogleDrive-*/My Drive/DriveSyncFiles/Test/TODO.md`

If neither exists, stop and tell the user Google Drive isn't mounted — never create the note somewhere else. Only edit `TODO.md`; leave the vault's other notes (`Backlog TODO.md`, game todos, etc.) alone unless the user names them.

## Note format

Plain Markdown, one item per line, **no checkboxes or bullets**. Blank lines separate loose groups, and a line ending in `:` (e.g. `If car dies:`) heads a group of the items under it. The file uses LF line endings and ends with a blank line. Preserve all of this — match the existing style rather than reformatting.

## Operations

Always read the current note first (Drive may have synced edits from another device), then make a minimal edit with the Edit tool.

- **Add** — append the item as a new line after the last item of the first (top, ungrouped) block, unless the user names a group (`under "If car dies"`) or position (`at the top`). Keep the user's wording; don't add bullets, dates or checkboxes. Skip it and say so if an equivalent item is already there. Several items → one line each.
- **Remove / done / tick off** — delete the matching line. Match loosely (case, typos, paraphrase: "remove gym" → `Gym?`). If more than one line could match, or nothing clearly matches, show the candidates and ask rather than guessing. If removing a group's last item leaves an orphaned header, ask whether to remove the header too.
- **List** (or no arguments) — print the note's contents.

After any change, show the resulting list (or a short diff for long lists) so the user can confirm. There's no git here — Google Drive syncs it — so don't commit anything.
