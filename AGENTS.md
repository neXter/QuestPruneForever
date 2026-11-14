# AGENTS.md

Instructions for AI coding tools working on this WoW add-on. They mirror the author's global rules for all add-on projects under `WoW_AddOns`.

## Project

- **QuestPruneForever** (short: *QuestPrune*, slash `/qp`): a quest-log triage add-on for WoW Forever. Flat one-line-per-quest table with one-click actions. No mass actions; the user decides on every quest.
- Concept (German): `docs/CONCEPT.md`. Technical design: `docs/ENG-DESIGN.md`. UI mock: `docs/assets/mock.svg`.
- Author alias: neXter (git: `20801+neXter@users.noreply.github.com`).
- Target: WoW Forever, `## Interface: 16001`. Install path: `World of Warcraft\_forever_\Interface\AddOns\<Name>`.
- Reference add-ons by the same author, for style and structure: EmoteBar, FriendsListList.

## Repo layout and files

- Each add-on is its own local git repo (`git init -b main`, local author neXter) with: `<Name>.toc`, `<Name>.lua`, `Icons/`, `README.md` (English), `CHANGELOG.md` (Keep a Changelog), `LICENSE`, `.gitignore` (includes `dist/` and `.claude/`), `docs/`.
- `LICENSE`: all rights reserved, same text as EmoteBar (personal, non-commercial use of the unmodified add-on allowed).
- `docs/` holds the concept document (local Markdown, German), mock, icon sources and store assets. It is committed to git. Do not create online docs or artifacts for concepts; the user only wants local Markdown.
- Update the concept document (`docs/CONCEPT.md`, and `docs/ENG-DESIGN.md` where relevant) and the mock whenever a design decision changes, not only the code.

## Release ZIP

- Built into `dist/` (git-ignored) as `dist/<Name>-<version>.zip`.
- Inside: one folder `<Name>/` (exactly matching the `.toc` name) with only `.toc`, `.lua`, `Icons/` and `LICENSE`.
- Never in the ZIP: `docs/`, `README.md`, `CHANGELOG.md`, `.gitignore`.
- After zipping, list the entries to verify.

## Versions and releases

- Every new version: bump `## Version:` in the `.toc` and `VERSION` in the Lua, add a dated section to `CHANGELOG.md`, rebuild the ZIP, commit, create the git tag `vX.Y.Z`, and push the branch and the tags (`git push origin main --tags`), so the tags show up on GitHub and can be used as releases.
- The tag always points at the commit that contains that version's final code. Never tag before the commit.
- Changelog entries describe what the shipped version really did.
- After every version bump, create a commit containing that version. Create tags and push only when the user asks.

## Code conventions

- German and English texts chosen via `GetLocale()` (deDE = German, otherwise English). TOC has `Notes` and `Notes-deDE`.
- SavedVariables `<Name>DB` (here `QuestPruneForeverDB`), short slash alias (here `/qp`), `/<alias> reset`, movable frames locked by default.
- Debug output in chat (`/<alias> debug` toggles) is OFF by default, even in 1.0 (user decision). It logs client info, API availability and what each refresh found; add a `dump` command for bug reports. Gate repeated debug lines by a signature so chat is not spammed.
- Unverified client details (texture paths, API fields) get fallbacks that can be switched with a slash command, and an entry under open questions in the concept.
- Add-on list icon: 64x64 uncompressed TGA in `Icons/`, referenced via `## IconTexture:` without extension. Also keep SVG source and 256/512 PNG in `docs/assets/` for CurseForge/Wago.
- Never use Blizzard logos or crests as shipped files. Reference client textures/atlases at most.

## Verification without the game

No Lua is installed. Syntax-check and smoke-test with `pip install --user lupa`: compile with `load()`, then run the add-on against a small mocked WoW API (frames, C_Timer, quest log APIs) and print the chat output. Render SVG mocks and icons with headless Edge (`msedge.exe --headless=new --screenshot=...`) and Pillow.

## Working style

- Environment is Windows (PowerShell / Git Bash). Use forward-slash-safe paths and quote paths with spaces.
- The user writes German; code, README, CHANGELOG and commit messages are English, the concept document is German.
