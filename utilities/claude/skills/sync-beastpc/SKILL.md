---
name: sync-beastpc
description: Sync the netwealthanalysius git repos (main / netwealthanalysius, transaction_dataframe_standard, and the nested userdata/john data repo) between this machine and the beastpc box via GitHub. Use whenever the user asks to sync, push, reconcile, or "make in sync" these repos to or from beastpc — e.g. "sync to beastpc", "make sure the dataframe/userdata/main repos are in sync with beastpc", "push the repos to beastpc".
---

# Sync netwealthanalysius repos with beastpc

Sync the three **netwealthanalysius** git repos between this local machine and the **beastpc** box so all three match. Honor any specific direction or scope the user gave (e.g. a particular repo, or which side is the source of truth).

First, read the **`beastpc-sync`** project memory — it has the full topology and the permission/edge-case gotchas.

## Context

- **Local repo**: the current working directory (e.g. `/Users/john/Downloads/netwealthanalysius`).
- **beastpc**: `ssh -p 2222 john@beastpc`; repo at **`/home/john/Projects/netwealthanalysius`** (WSL-native ext4 — canonical since the 2026-07-24 migration off `/mnt/c`; normal git works there, no sudo/pack workarounds needed).
- **The three repos**:
  1. `main` = netwealthanalysius → origin `PulfordJ/netwealthanalysius` (PRIVATE → auto-push allowed).
  2. `transaction_dataframe_standard` = a bare **gitlink** (no `.gitmodules`) → origin `PulfordJ/transaction_dataframe_standard`. Usually just gitlink bumps.
  3. `userdata/john` = a **nested repo** → origin `PulfordJ/netwealth-userdata-john`, branch `main`. Tracks regenerated analysis data (`net_wealth_daily.csv`, `holdings_breakdown.json`, `price_data/*.csv`) that each machine updates independently, so its working tree usually diverges between the two boxes.

## Procedure

1. **Investigate first (read-only).** Confirm SSH works. For each of the three repos on BOTH machines: `git fetch`, then report `HEAD`, ahead/behind vs origin, and dirty/untracked state + stashes. Build a HEAD comparison across **local / origin / beastpc**.
2. **GitHub origin is the source of truth.** For each repo, push from whichever side has the newer commits, then fast-forward / pull the other. **Preserve local WIP and stashes on both sides** — never discard uncommitted work without confirming.
3. **`transaction_dataframe_standard`**: make sure both checkouts sit on the same commit.
4. **`userdata/john` data divergence**: if both sides have uncommitted regenerated data, compare the actual data (last dates/rows in `net_wealth_daily.csv` and the price CSVs) to see which is newer. beastpc is usually ahead (it runs price fetches; the local Mac may have stale carry-forward rows). **Ask which side is the source of truth before committing or overwriting** this financial data, then commit + push the chosen side and reset/pull the other.
5. **Confirm before anything destructive or outward-facing** — pushing shared history, discarding WIP, or resetting. (Pushing the private PulfordJ repos is pre-authorized per the global git workflow.)
6. **Report** a final summary table of HEADs (local / origin / beastpc) for all three repos, and note any WIP intentionally left in place.
