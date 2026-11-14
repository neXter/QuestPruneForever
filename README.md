# QuestPruneForever

Diagnostic preview for World of Warcraft Forever. Copy the `QuestPruneForever` folder to `_forever_/Interface/AddOns/` and reload the UI.

Use `/qp` to open the quest list. Protect keeps an individual quest from being abandoned. Untouched or failed quests can be abandoned immediately; quests with progress or unknown objectives require two clicks within three seconds. Shift-click abandons an unprotected quest immediately. Use `/qp dump` to print client API availability and quest data, `/qp debug` to toggle diagnostic output, and `/qp help` for commands. Further quest actions and rewards are planned for later versions.

For development, run the VS Code task **Install QuestPruneForever for testing** and enter the path to the game's `_forever_/Interface/AddOns` folder. Alternatively, run `python tools/install.py "<path to AddOns>"` in the terminal. Use `/reload` in game after installing.

Run `python tools/smoke.py` for the mocked smoke test (requires `python -m pip install --user lupa`). Run `python tools/build.py` to build and list the release ZIP in `dist/`.

Copyright (c) 2026 neXter. See [LICENSE](LICENSE).
