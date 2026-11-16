# Changelog

## [1.1.1] - 2026-11-16

- Show the version and build time in small text at the bottom right of the window, and include the build time in `/qp dump`.

## [1.1.0] - 2026-11-16

- Record quests abandoned through the standard quest log in the Abandoned tab, by following the game's abandon calls.
- Add `/qp compat abandon hook|infer|off`. `infer` records any quest removal that was not a turn-in and is used automatically when the abandon calls cannot be hooked; `off` disables tracking of standard-log abandons.
- Show the abandon-tracking state in `/qp dump` and log detected standard-log abandons when debug output is on.

## [1.0.0] - 2026-11-14

- Show item rewards, money and XP alongside each quest, with tooltips and a compact, aligned reward column.
- Require two clicks for every quest abandonment and retain per-character quest protection.
- Add class and profession quest markers, filters and groups inferred from quest-log headings.
- Improve list scrolling and layout, fitting more entries while keeping icons aligned.
- Add an abandoned-quest history with saved acceptance locations and waypoint support where coordinates are available.
- Add quest type filters, current-zone highlighting, and a shortcut from the standard map and quest log.
- Mark post-Classic quest IDs with an approximate filter and icon.
- Add classic-style window artwork and an add-on icon.
- Add an English and German store listing.

## [0.2.0] - 2026-11-14

- Add a scrollable quest list with sorting, filters, capacity and a movable window.
- Add an experimental per-quest abandonment action requiring two clicks within three seconds.
- Place the quest window above standard UI elements and make its background opaque.
- Open quest details by clicking a row and show objectives on hover.
- Add per-character quest protection and immediate abandonment for known untouched or failed quests, with confirmation for other quests.
- Restyle the quest list with difficulty badges, separate title and zone, objective text, compact controls, and individual filter buttons.

## [0.1.0] - 2026-11-14

- Add diagnostic quest snapshots, API availability reporting and debug output.
- Add saved settings and slash command scaffolding for the upcoming interface.
