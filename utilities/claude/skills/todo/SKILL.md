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

Obsidian task list: one item per line as `- [ ] item` (`- [x] item` when ticked in Obsidian). The ungrouped items come first; named groups follow as `## Heading` sections (e.g. `## If car dies`) separated by a blank line. LF line endings, trailing newline. Match the existing style rather than reformatting.

## Operations

Always read the current note first (Drive may have synced edits from another device), then make a minimal edit with the Edit tool.

- **Add** — append `- [ ] <item>` after the last item of the top, ungrouped block, unless the user names a group (`under "If car dies"`, creating the `## ` section if new) or position (`at the top`). Keep the user's wording; don't add dates. Skip it and say so if an equivalent item is already there. Several items → one line each.
- **Remove / done / tick off** — delete the matching line (also clear out any `- [x]` lines while you're there). Match loosely (case, typos, paraphrase: "remove gym" → `Gym?`). If more than one line could match, or nothing clearly matches, show the candidates and ask rather than guessing. If removing a group's last item leaves an empty `## ` section, ask whether to remove the heading too.
- **List** (or no arguments) — print the note's contents.

After any change, show the resulting list (or a short diff for long lists) so the user can confirm. There's no git here — Google Drive syncs it — so don't commit anything.
