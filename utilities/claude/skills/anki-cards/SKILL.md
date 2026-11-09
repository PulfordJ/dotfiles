---
name: anki-cards
description: Add (or fix) Anki flashcards in John's Anki collection. Spanish cards go into the Spanish Pronunciation Trainer repo (decks_data.py) and are synced into Anki with audio; other cards (coding, system design, ...) go straight into the matching Anki deck via AnkiConnect. Use from any repo whenever the user asks to add/make/create flashcards or Anki cards ("add anki flashcards for these words", "make cards from my class notes", "add this to anki", "/anki-cards ..."), or to correct an existing card.
argument-hint: "<what to add, e.g. words, sentences, a topic, or a file of class notes>"
---

# Add Anki flashcards

Anki runs on the Windows host (from WSL) or locally (macOS). Everything talks to it
through AnkiConnect with `scripts/ankiconnect.py` in this skill's directory, which finds
a working route on its own (direct HTTP, or a relay through Windows Python when WSL can't
reach Windows' localhost). Anki must be open; if a call says it can't reach AnkiConnect,
ask the user to open Anki and retry.

```bash
S=~/.claude/skills/anki-cards/scripts
python3 $S/ankiconnect.py deckNames                       # any AnkiConnect action
python3 $S/ankiconnect.py findNotes '{"query": "deck:Coding"}'
python3 $S/ankiconnect.py addNotes - < notes.json         # "-" = params as JSON on stdin
```

First decide what the cards are. If the request doesn't say what to add, ask. Split a mixed
request: Spanish-learning cards take the Spanish route, everything else the other route.

## Spanish cards → the Spanish Pronunciation Trainer repo

The repo is the source of truth; never add Spanish cards straight into Anki, and never
into the downloaded shared decks ("Most Common Spanish Phrases", "Ultimate Spanish
Conjugation", "Misc", "ser").

1. **Repo.** WSL: `/mnt/c/Users/johnp/PyCharmMiscProject` (GitHub `PulfordJ/SpanishPronounciationAnki`).
   Elsewhere, find a clone (`decks_data.py` next to `create_spanish_decks_via_ankiconnect.py`) or
   `gh repo clone` it. Run `git status -sb` and `git fetch`; if behind, `git pull --ff-only`
   (other sessions add cards too). Leave unrelated uncommitted changes alone.
2. **Look before writing.** Read the deck list and the cards near the topic
   (`python3 -c "from decks_data import decks; ..."`) so you don't duplicate what exists.
3. **Write the cards** following the card rules below.
4. **Place them.** `decks = {"Deck name": [("English", "Spanish"), ...], ...}` in `decks_data.py`.
   Append to the existing deck that fits; otherwise add a new deck before the closing `}` and
   give it a line in `SUBDECK_TAG_DEFAULTS` in `tag_mapping.py`:
   `aula::unidad_N` for Aula Internacional Plus 1, `aula2::unidad_N` for Plus 2 (deck name
   `"A2 U<n> - <Topic>"`), `aula::extra` otherwise; plus `skill::vocabulary|grammar|phrases|dialogue`
   and `priority::core|extended`.
5. **Check.** In the repo: `python3 check_duplicates.py` must pass (the repo's CLAUDE.md requires
   it). It catches a front used twice in a deck and a front reused across decks with
   different Spanish. Also make sure no new front matches an existing one case-insensitively.
6. **Sync and verify** (Anki open). This runs the repo's own sync: it generates the TTS audio,
   uploads it, applies `card_migrations.py`, adds new cards, updates Spanish/audio/tags on
   existing ones, then reads every note back and checks it against `decks_data.py`:
   ```bash
   nix-shell -I nixpkgs=flake:nixpkgs -p 'python3.withPackages (ps: [ ps.requests ps.edge-tts ])' \
     --run "python3 ~/.claude/skills/anki-cards/scripts/sync_spanish.py <repo>"
   ```
   Only report success if it ends with `OK`. If a note shows "Spanish differs", the user
   may have it open in Anki's Browse window (AnkiConnect can't update an open note): ask
   them to close it and run again. `--verify-only` checks without syncing. If the user asked
   for a draft only, skip this step and say the cards aren't in Anki yet.
7. **Commit** in the repo: stage only the files you changed (usually `decks_data.py`,
   `tag_mapping.py`, `card_migrations.py`), conventional message (`feat: add ... cards`),
   then follow the global push rules (the repo is public, so ask before pushing). Don't run
   `update_export_and_release.py` (it publishes a GitHub release) unless asked.
8. **Report** the new cards as a short table (deck, English → Spanish) and the verify result.

### Card rules (Spanish)

- **English front, Spanish back.** Never store a card the other way round: the template
  always plays audio made from the Spanish field, so a swapped card has a Spanish voice
  reading English. If the user wants Spanish→English recognition practice, that needs a
  separate card template; say so rather than swapping fields.
- **The Spanish field is read aloud** by two voices (Spain, Mexico). Put only Spanish in it:
  no English glosses, pronunciation notes or explanations. Hints go on the English side.
  Alternatives are fine when both are Spanish (`frustrado / frustrada`), as are the existing
  conventions `(formal)` and `(yo)` in conjugation tables.
- **One right answer.** The English front must make the Spanish unambiguous: `(masc.)` /
  `(fem.)` for gendered words and for the speaker (John is male, so first-person sentences
  default to masculine; mark it). "you" = tú, `(formal)` = usted, "you all" = vosotros,
  `(formal, plural)` = ustedes, `(ser)` / `(estar)` when "to be" is ambiguous, and a time word
  when English tense is ambiguous ("I put" → "Where did you put...?").
- **Every English front is unique across the whole deck**, all subdecks, and case matters.
  AnkiConnect silently skips a card whose front already exists anywhere in the collection. If
  the concept is already there, don't add it again; if it's a different meaning, add a hint,
  e.g. `Me too (agreeing with gustar)`.
- **Correct, natural Spanish** at A1–A2 level: accents, `¿…?` and `¡…!`, a capital letter for
  sentences (lowercase for single words and fragments), articles on nouns where gender matters
  (`la barba`). Double-check agreement, ser/estar, por/para, preterite vs perfect, and
  apocope (`un`, `buen`, `primer`). Spain Spanish by default (vosotros, móvil, coger) unless the
  source is Latin American.
- **Sources.** The user's own class notes can be used as they are (fix any errors and say
  which). Textbook PDFs (e.g. Aula Internacional) are copyrighted: use them for the topics,
  grammar and vocabulary, and write original sentences instead of copying their dialogues
  or exercises.
- **Personal sentences** can use what the deck already knows about John (lives in Cambridge,
  from Colchester, systems engineer, worked in Thailand, salsa, PureGym); don't invent facts.

### Fixing existing Spanish cards

- **Spanish-only change:** edit the tuple. The sync updates the note in place.
- **English front change:** also add `"old front": "new front"` to `RENAMED_FRONTS` in
  `card_migrations.py`, so the sync renames the note and keeps its review history (otherwise it
  adds a second note and orphans the old one). If the old front is a key in `tag_mapping.py`
  (`PHRASE_TAG_OVERRIDES`, `CORE_*` sets), rename it there too.
- **Removing a card:** deleting the tuple does not delete the note in Anki. Add the front to
  `RETIRED_FRONTS` only if the user wants it deleted from Anki (this loses its review history),
  and confirm first.

## Other cards → straight into Anki

These decks have no source repo; the cards live in Anki (and AnkiWeb after the user syncs).

1. `deckNames` and pick the deck that fits the topic (currently `Coding`, `System Design Primer`,
   `System Design Exercises`, `OO Design`, `Latency & Throughput`). If none fits or it's unclear,
   ask; create a new deck (`createDeck`) only when the user agrees.
2. Use the note type that deck already uses (check with `findNotes` + `notesInfo`; mostly `Basic`
   with fields `Front` / `Back`). Never use the Spanish model: it plays Spanish TTS of the back.
3. Write cards that test one thing each, with a short, specific front and a concise back
   (simple HTML such as `<br>`, `<b>`, `<code>` is fine).
4. Check for duplicates with `canAddNotesWithErrorDetail`, then `addNotes` with
   `"options": {"allowDuplicate": false, "duplicateScope": "deck"}`. A `null` in the result means
   that note wasn't added: report it.
5. Read the new notes back (`findNotes` on `added:1` plus the deck, then `notesInfo`) and report
   them as a short table.
