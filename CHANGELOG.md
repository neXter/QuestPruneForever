# Changelog

## [Unreleased]

- Show quest item rewards, money and XP in the quest list, with item tooltips and asynchronous quest-data loading.
- Require two clicks to abandon every unprotected quest, including when Shift is held.
- Add class and profession quest markers, filters, and type groups inferred from localized quest-log headings.
- Use the full list area when short section headings leave room for more than 20 entries.

- Replace quest type letters with group, dungeon and PvP icons and use icon buttons for quest protection and abandonment.
- Keep the quest row highlighted while hovering over its action buttons.
- Group sorted quests under zone, difficulty-color, or progress-status headings.
- Give the window warm, classic-style borders and controls.
- Show each open objective on its own line and expand quest rows to prevent text overlap.
- Use smaller, understated section headings.
- Center quest names vertically, including when the zone is hidden by grouping.
- Use a window lock icon and show labels beside the quest action icons.
- Use a reject icon for abandoning quests.
- Size quest action buttons for their translated labels, add filter and sort icons, and center objectives vertically.
- Place quest type icons before the level and add a raid icon when the client provides its raid tag.
- Mark quests and zone headings in the current area with a subtle accent.
- Size filter buttons to their translated labels so text is not truncated.
- Record available quest giver and map position on acceptance and list quests abandoned through QuestPrune in a separate tab.
- Put the current zone first when sorting by zone and add breathing room around quest type icons.
- Add waypoint buttons for saved acceptance positions in the abandoned quests tab, with TomTom fallback.
- Add icons to the active and abandoned tabs and size them to their translated labels.
- Label the current zone in its section heading.
- Add sorting and section headings by quest type.
- Separate the group and dungeon quick filters.
- Replace the wide filter buttons with compact icon tabs and tooltips.
- Add PvP and raid filters and dim filters with no matching quests.
- Stop scrolling at the last full page, accounting for variable quest row heights.
- Add a QuestPrune button to the standard quest log for switching between the two views.
- Keep the QuestPrune button inside the map title bar so it stays on screen.
- Keep the map shortcut above the native UI and update it when the map opens or closes.
- Use a compact QuestPrune icon in the map title bar instead of a wide text button.
- Align the map shortcut higher and add a classic client-texture border, with a simple fallback.
- Adjust the classic client border to align with the map shortcut icon.
- Use classic dialog textures and beveled controls for the QuestPrune window, with a plain fallback.
- Make the window background opaque and add a warm textured brown title bar.
- Mark and filter quests with IDs above the original Classic maximum as post-Classic; this is an approximation, not proof that they are new to Forever.
- Clicking the active quick filter again returns to All; quick filters remain mutually exclusive.
- Align the active, abandoned, and window-lock controls with the title bar center.
- Add an original scroll-and-shears add-on icon and store artwork.
- Show the add-on icon in a circular ornament on the QuestPrune window.
- Use separate circular artwork for the window ornament without the square icon frame.

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
