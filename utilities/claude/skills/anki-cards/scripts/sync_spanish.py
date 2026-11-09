#!/usr/bin/env python3
"""Sync the Spanish Pronunciation Trainer repo into Anki, then verify Anki.

Runs the repo's own create_spanish_decks_via_ankiconnect.main() unchanged except
that its AnkiConnect calls go through ankiconnect.py (works from WSL). Then reads
every note back and checks that each English front in decks_data.py exists exactly
once with the expected Spanish, audio fields, and audio files in Anki's media.

usage: sync_spanish.py <repo dir> [--verify-only]
Needs `requests` and `edge-tts` (the repo's own dependencies), e.g.:
  nix-shell -I nixpkgs=flake:nixpkgs -p 'python3.withPackages (ps: [ ps.requests ps.edge-tts ])' \
    --run "python3 sync_spanish.py /mnt/c/Users/johnp/PyCharmMiscProject"
"""
import argparse
import collections
import os
import sys

sys.dont_write_bytecode = True  # keep __pycache__ out of the skill and repo dirs

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ankiconnect  # noqa: E402


def verify(sync, decks) -> bool:
    want = {}
    for cards in decks.values():
        for en, es in cards:
            want.setdefault(en, es)
    notes = ankiconnect.invoke("notesInfo", notes=ankiconnect.invoke("findNotes", query=f'note:"{sync.MODEL_NAME}"'))
    by_front = collections.defaultdict(list)
    for n in notes:
        by_front[n["fields"]["English"]["value"].strip()].append(n)
    media = set(ankiconnect.invoke("getMediaFilesNames", pattern="spt_*.mp3"))
    problems = collections.defaultdict(list)
    for en, es in want.items():
        found = by_front.get(en, [])
        if len(found) != 1:
            problems["missing from Anki" if not found else "duplicated in Anki"].append(en)
            continue
        fields = {k: v["value"] for k, v in found[0]["fields"].items()}
        if fields.get("Spanish") != es:
            problems["Spanish differs"].append(f"{en!r}: Anki {fields.get('Spanish')!r} vs data {es!r}")
        for field, ref in sync.audio_field_values(es).items():
            if fields.get(field) != ref:
                problems["audio field differs"].append(en)
            elif ref[len("[sound:"):-1] not in media:
                problems["audio file missing from media"].append(en)
    print(f"\nVerified {len(want)} fronts against {len(notes)} notes in Anki.")
    for what, items in problems.items():
        print(f"  FAIL {what}: {len(items)}")
        for item in items[:15]:
            print(f"    - {item}")
    if not problems:
        print("  OK: every card in decks_data.py is in Anki with the right Spanish and audio.")
    return not problems


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("repo")
    ap.add_argument("--verify-only", action="store_true", help="don't sync, just compare Anki with decks_data.py")
    args = ap.parse_args()
    repo = os.path.abspath(args.repo)
    sys.path.insert(0, repo)
    os.chdir(repo)
    import create_spanish_decks_via_ankiconnect as sync
    from decks_data import decks

    sync.invoke = ankiconnect.invoke
    if not args.verify_only:
        sync.main()
    sys.exit(0 if verify(sync, decks) else 1)


if __name__ == "__main__":
    main()
