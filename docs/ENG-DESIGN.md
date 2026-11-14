# QuestPruneForever – Engineering Design (Entwurf)

Stand: 2026-11-14 · Basis: [CONCEPT.md](CONCEPT.md) · Ziel-Client: WoW Forever (`## Interface: 16001`)

Dieses Dokument beschreibt, *wie* das Konzept umgesetzt wird: Dateien, Datenmodell, Refresh-Pipeline, UI-Aufbau, Aktionen und Test ohne Spiel. Unbestätigte Client-Details stehen mit Fallback unter [Offene Fragen](#9-offene-fragen--risiken).

---

## 1. Scope

**In 1.0:** Fenster mit flacher Questliste, Header (Kapazität, Sortierung, Filter), per Klick ins Standard-Log, pro Zeile Badge/Titel/Zone/Status/Rewards und Aktionen (Schützen, Tracking, Teilen, Abbrechen), Shift-Klick-Chatlink, Reward-Caching, Debug/Dump.

**Bewusst nie:** Massenaktionen (mehrere Quests auf einmal abbrechen). Jede Quest wird einzeln abgebrochen (Konzept, Grundsatz „volle Kontrolle“).

**Nicht in 1.0:** Questtext lesen im Add-on (nur Tooltip), Optionen-Panel, Account-weite Statistiken, Wiederannehmen abgebrochener Quests.

Ein separater Reiter dokumentiert über QuestPrune abgebrochene Quests. Questgeber und Spielerposition werden, soweit verfügbar, bei `QUEST_DETAIL` erfasst und bei `QUEST_ACCEPTED` pro Charakter gespeichert. Erst ein bestätigtes `QUEST_REMOVED` nach einem QuestPrune-Abbruch legt den Eintrag im Reiter ab; Wiederannahme entfernt ihn. Unbekannte Questgeber oder Positionen werden als solche angezeigt; die gespeicherte Position ist die Spielerposition bei der Annahme.

Bei vorhandenen Kartenkoordinaten setzen ein Wegpunkt-Button und ein Klick auf den Eintrag den Client-Wegpunkt und aktivieren, falls verfügbar, dessen Tracking. Falls die Client-API fehlt oder die Karte ablehnt, dient TomTom als Fallback. Ein fehlgeschlagener Aufruf meldet einen Fehler statt Erfolg.

Mock: [assets/mock.svg](assets/mock.svg)

---

## 2. Dateien & Grundgerüst

```
QuestPruneForever/
  QuestPruneForever.toc
  QuestPruneForever.lua      -- eine Datei, in Abschnitte gegliedert (s. u.)
  Icons/icon.tga             -- 64×64, unkomprimiert
```

TOC:

```
## Interface: 16001
## Title: QuestPruneForever
## Notes: Flat quest log triage: see and abandon low-value quests in one click
## Notes-deDE: Flache Questlog-Übersicht: wertlose Quests erkennen und per Klick abbrechen
## Author: neXter
## Version: 0.1.0
## SavedVariables: QuestPruneForeverDB
## IconTexture: Interface\AddOns\QuestPruneForever\Icons\icon
```

Eine Lua-Datei (wie FriendsListList), geschätzt 1.000–1.300 Zeilen. Abschnitte in dieser Reihenfolge, jeweils `local`:

| Abschnitt | Inhalt |
| --- | --- |
| Locale | `L`-Tabelle, `GetLocale() == "deDE"` → Deutsch, sonst Englisch |
| Util | `Print`, `Dbg` (signaturgesteuert), `Has`, Formatierung Gold/XP (`45s`, `1.4k XP`) |
| Compat | Kapselt alle unsicheren APIs hinter je einer Funktion mit Fallback (§ 8) |
| Model | `Snapshot()` → Liste von Quest-Records (§ 3) |
| Query | Filter + Sortierung → sichtbare Liste |
| Actions | Abandon, Lock, Watch, Share, Link, OpenInLog |
| UI | Hauptfenster, Header, Zeilen-Pool, Tooltips |
| Refresh | Debounce, Dirty-Flag, Event-Handler |
| Slash | `/qp`, `/questprune` |

---

## 3. Datenmodell

### 3.1 Quest-Record (pro Refresh neu gebaut, nie persistiert)

```lua
{
  questID      = 1234,
  logIndex     = 7,              -- nur für APIs, die noch Index brauchen
  title        = "Bandit Trouble",
  level        = 18,
  zone         = "Redridge Mountains", -- letzter Header über der Quest
  tag          = { elite = true, dungeon = false, pvp = false, raid = false, group = 0 },
  difficulty   = "trivial",      -- trivial|standard|difficult|verydifficult|impossible
  state        = "active",       -- active|complete|failed
  objectives   = { { text = "Bandits", have = 4, need = 10, done = false }, ... },
  progress     = 0.4,            -- 0..1, Mittel über Objectives
  untouched    = false,          -- progress == 0 und state == "active"
  rewards      = {
    items   = { { itemID, texture, quality, count, choice = true|false, slot = i } },
    money   = 4500,              -- Kupfer
    xp      = 1400,
    pending = false,             -- true solange Item-Daten fehlen
  },
  watched      = true,
  pushable     = true,
  locked       = false,          -- aus DB
}
```

**Regeln:**

* **Fortschritt:** Je Objective `min(have/need, 1)`; erledigte Objectives zählen als 1. `progress` = Mittelwert. Bei fehlenden Objectives oder unbekanntem Fortschritt ist der Wert unbekannt und der Abbruch bestätigungspflichtig.
* **`untouched`** steuert das Dimmen der Zeile und den Filter „0 %“. Abgabebereite und fehlgeschlagene Quests sind nie `untouched`.
* **Abbruch:** Jede ungeschützte Quest benötigt zwei Klicks innerhalb von drei Sekunden, unabhängig von Fortschritt oder Shift-Taste.
* **Zone:** Beim Durchlauf über `C_QuestLog.GetNumQuestLogEntries()` merkt sich der Snapshot den letzten Eintrag mit `isHeader` als Zone. Versteckte Einträge (`isHidden`, `isTask`, `isBounty`) werden übersprungen.
* **Schwierigkeit:** `GetQuestDifficultyColor(level)` liefert eine Farbtabelle; die Kategorie wird über Identität mit `QuestDifficultyColors[key]` bestimmt. Fallback: eigene Rechnung aus `UnitLevel("player")` und `GetQuestGreenRange()` (§ 8).

### 3.2 SavedVariables `QuestPruneForeverDB`

```lua
QuestPruneForeverDB = {
  version = 1,
  pos     = { point, relPoint, x, y },
  locked  = true,               -- Fenster fixiert (Konvention: standardmäßig gesperrt)
  sort    = "level",            -- level|zone|progress
  filter  = "all",              -- all|lowvalue|untouched|group|complete
  debug   = false,
  compat  = { },                -- per Slash gesetzte Fallback-Schalter (§ 8)
  chars   = {
    ["Realm-Name"] = { protected = { [questID] = true } },
  },
}
```

* Geschützte Quests sind **pro Charakter** gespeichert, da Quest-IDs charakterbezogen sind.
* Aufräumen: Bei `QUEST_REMOVED`/`QUEST_TURNED_IN` wird die `questID` aus `protected` entfernt. Zusätzlich beim Login: Einträge, die nicht mehr im Log stehen, löschen.
* Name nach Add-on-Konvention `<Name>DB` (frühere Konzeptfassung: `QuestPruneDB`).

---

## 4. Refresh-Pipeline

```
Event ──► MarkDirty() ──► (Fenster sichtbar?) ──► C_Timer.After(0.1) ──► Refresh()
                                  │ nein                                   │
                                  └─► dirty = true, nichts tun             ├─ Snapshot()
                                                                           ├─ Query(filter, sort)
OnShow ──► dirty? ──► Refresh() sofort                                     └─ Render()
```

* **Debounce:** Ein `pending`-Flag; das erste Event plant `C_Timer.After(0.1)`, weitere Events bis dahin werden verworfen. Kein Ticker, kein `OnUpdate`.
* **Geschlossenes Fenster** verursacht keine Arbeit außer dem Setzen von `dirty`.
* **Events** (registriert per `pcall`, wie in FriendsListList, fehlende Events werden im Debug gemeldet):

| Event | Wirkung |
| --- | --- |
| `PLAYER_LOGIN` | DB initialisieren, Locks aufräumen, Log-Button einhängen |
| `QUEST_LOG_UPDATE`, `QUEST_ACCEPTED`, `QUEST_WATCH_LIST_CHANGED`, `UNIT_QUEST_LOG_CHANGED` (player) | `MarkDirty()` |
| `QUEST_REMOVED`, `QUEST_TURNED_IN` | Lock entfernen, Arm-State entfernen, `MarkDirty()` |
| `QUEST_DATA_LOAD_RESULT (questID, ok)` | `pendingLoads[questID] = nil`, `MarkDirty()` |
| `GET_ITEM_INFO_RECEIVED` | nur wenn `next(pendingLoads)`: `MarkDirty()` |
| `PLAYER_LEVEL_UP` | Schwierigkeitsfarben ändern sich → `MarkDirty()` |
| `GROUP_ROSTER_UPDATE` | Share-Buttons aktivieren/deaktivieren → `MarkDirty()` |

* **Reward-Caching:** Liefert `GetQuestLogRewardInfo`/`GetQuestLogChoiceInfo` keinen Namen bzw. keine Textur, setzt der Snapshot `rewards.pending = true` und ruft einmal pro `questID` `C_QuestLog.RequestLoadQuestByID(questID)` auf (`pendingLoads` verhindert Wiederholungen). Die Zeile zeigt im Reward-Slot einen Platzhalter (Fragezeichen-Icon, leicht pulsierend per `AnimationGroup`). Nach 5 s ohne Antwort gibt der Slot auf und zeigt das Fragezeichen statisch.

---

## 5. UI-Aufbau

### 5.1 Hauptfenster

* `QuestPruneForeverFrame`, `BackdropTemplate`, `ESC` schließt (Eintrag in `UISpecialFrames`).
* Klassisch inspirierte Gestaltung mit deckendem dunklem Hintergrund, eigener brauner Titeltextur, Client-Dialograhmen, eingefassten Buttons und Blizzard-Schriften. `/qp compat skin plain` schaltet auf den bisherigen Tooltip-Rahmen zurück; `classic` aktiviert den Client-Dialograhmen.
* Oben links sitzt ein rundes Medaillon aus dem eigenen Add-on-Icon; Titel und Sortierbutton beginnen rechts davon.
* Fixiert per Default (Konvention). Entsperren über das Schloss-Symbol im Fenstertitel oder `/qp unlock`; dann per Titel-Drag verschiebbar, Position in `db.pos`.
* **Größe: 720 × 660 px.** Die Liste nutzt einen 560 px hohen sichtbaren Bereich. Questzeilen sind mindestens 28 px hoch und wachsen mit dem umgebrochenen Zieltext; dezente Überschriften belegen 20 px. Das Mausrad scrollt über Einträge, die nicht mehr vollständig hineinpassen. Extrem hohe Einträge werden auf den sichtbaren Bereich begrenzt; der Tooltip zeigt weiterhin alle Ziele.

### 5.2 Titel- und Werkzeugleiste

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ QuestPrune   19 / 20 Quests                                              🔒 ✕ │
│ [Sortierung: Level ▲]  Filter: [Alle][Grau/Grün][0 %][Gruppe/Dungeon][✓ Abgabebereit] │
└──────────────────────────────────────────────────────────────────────────────┘
```

* **Kapazität:** `numQuests / max`; Farbe weiß < max − 2, gelb ab max − 2, rot ab max. `max` aus `C_QuestLog.GetMaxNumQuestsCanAccept()`, Fallback 20.
* **Sortierung:** Klick-Zyklus; die gefilterten Quests werden in Abschnitten mit eigenen, mitscrollenden Überschriften angezeigt. Überschriften belegen Listenzeilen.
  * `level`: Schwierigkeitsfarbe des Clients (Grau bis Rot, sonst unbekannt), innerhalb der Gruppe Level und Titel
  * `zone`: aktuelles Gebiet zuerst, danach alphabetisch; innerhalb jedes Gebiets Level und Titel. Das Gebiet entfällt in den einzelnen Zeilen.
  * `progress`: unberührt, in Arbeit, unbekannt, abgabebereit, fehlgeschlagen; innerhalb der Gruppe Fortschritt und Titel
  * `type`: Solo, Klasse, Beruf, Gruppe/Elite, Dungeon, Schlachtzug, PvP und unbekannte Typen; innerhalb der Gruppe Level und Titel. Klasse und Beruf werden anhand der lokalisierten Questlog-Überschrift erkannt und können zusätzlich zum Dungeon- oder Gruppentyp vorliegen.
* **Filter:** Einzelauswahl über kompakte Symbol-Buttons mit Tooltips, Zustand in `db.filter`. Erneutes Anklicken des aktiven Filters setzt ihn auf `all`; `all` bleibt bei erneutem Klick aktiv.
  * `lowvalue`: Schwierigkeit `trivial` oder grün (siehe § 3.1)
  * `untouched`: `untouched == true`
  * `group`: Gruppen- und Elitequests
  * `dungeon`: Dungeonquests
  * `raid`: Schlachtzugsquests
  * `pvp`: PvP-Quests
  * `class`: Questlog-Überschrift entspricht einem lokalisierten Klassennamen
  * `profession`: Questlog-Überschrift entspricht einem lokalisierten Berufsnamen
  * `postclassic`: Quest-ID über 9665; heuristische Kennzeichnung nach ursprünglichem Classic, keine verifizierte Forever-Herkunft
  * `complete`: `state == "complete"`
* Kein Bulk-Button (siehe § 1).

### 5.3 Zeile (Pool, mindestens 28 px)

Zeilen werden einmalig erzeugt (Pool von 28, genug für den 560 px hohen Bereich mit 20 px hohen Abschnittsüberschriften) und nur neu befüllt. Spaltenraster bei 720 px:

| # | Block | Breite | Element |
| --- | --- | --- | --- |
| 1 | Level-Badge | 60 | Symbol für Gruppen-/Elite-, Dungeon-, Raid- oder PvP-Quest vor dem Level in Schwierigkeitsfarbe |
| 2 | Titel / Zone | 210 | zwei FontStrings (12 px / 10 px grau) |
| 3 | Status | 220 | Badge `Fertig` / `Fehlgeschlagen` oder offene Ziele untereinander; lange Ziele werden umgebrochen |
| 4 | Rewards | 128 | bis zu 3 Item-Buttons mit Qualitätsrahmen + `+N`, rechts davon Geld (oben) und XP (unten); fehlende Daten als Fragezeichen |
| A | Aktionen | 100 | Schützen, Auge, Teilen, Papierkorb (je 20×20) |

* Das Schloss ist ein Element der Aktionsspalte, kein eigener Informationsblock.
* Unberührte Quests (`untouched`): Blöcke 1–4 mit Alpha 0.55, Aktionen bleiben voll sichtbar.
* Geschützte Quests: Papierkorb ausgeblendet, Schloss-Icon aktiv (goldfarben). Schützen und Abbrechen zeigen Symbol und Text; die Fenstersperre im Titel ist ein Schloss-Symbol mit Tooltip.
* Scharfgeschalteter Papierkorb: wird zu einem roten Button `Sicher?`, der nach links über Auge und Teilen wächst; Zeile leicht rot hinterlegt.
* Gerade Zeilen leicht hinterlegt für Lesbarkeit.
* Questzeilen im aktuellen Gebiet und deren Gebietsüberschrift erhalten einen dezenten Akzent links. `GetRealZoneText()` und `GetZoneText()` liefern die Vergleichsnamen; bei fehlenden oder nicht übereinstimmenden Namen bleibt die Markierung aus. Gebietswechsel lösen eine Aktualisierung aus.

### 5.4 Tooltips

| Ziel | Inhalt |
| --- | --- |
| Titel | Titel, Level, Zone, Questbeschreibung (gekürzt auf ~400 Zeichen), alle Objectives untereinander |
| Status | alle Objectives mit `have/need`, erledigte grün |
| Reward-Icon | `GameTooltip:SetQuestLogItem(type, slot, questID)`; Vergleich über `GameTooltip_ShowCompareItem` bei `IsModifiedClick("COMPAREITEMS")` |
| Abbrechen | Hinweis auf die Bestätigung, gelb `Zerstört: [Item]` aus `GetAbandonQuestItems()` |
| Teilen | „Nicht teilbar“ bzw. „Nicht in Gruppe“, falls deaktiviert |

`GetAbandonQuestItems()` braucht die per `SetAbandonQuest()` markierte Quest. Das passiert **lazy beim Hover** über den Papierkorb, das Ergebnis wird pro `questID` bis zum nächsten Refresh gecacht. Die vorherige Questlog-Auswahl wird danach wiederhergestellt.

---

## 6. Aktionen

### 6.1 Abbrechen (Papierkorb)

Zustandsautomat pro `questID`:

```
idle ──Klick────────────────────────► armed (rot, "Sicher?", Token t)
armed ──Klick innerhalb 3 s──────────► Abandon()
armed ──C_Timer.After(3), Token == t─► idle
```

* `armed[questID] = token`; der Timer prüft das Token, damit ein späteres neues Scharfschalten nicht vom alten Timer zurückgesetzt wird.
* `Abandon(questID)`:
  1. abbrechen, wenn `locked` (Sicherheitsnetz, auch wenn der Button versteckt ist),
  2. vorherige Auswahl merken (`C_QuestLog.GetSelectedQuest()`),
  3. `C_QuestLog.SetSelectedQuest(questID)` → `C_QuestLog.SetAbandonQuest()` → `C_QuestLog.AbandonQuest()`,
  4. Auswahl wiederherstellen, Chatmeldung „Abgebrochen: [Questlink]“,
  5. Zeile sofort lokal entfernen (optimistisch); der folgende `QUEST_LOG_UPDATE` bestätigt.

### 6.2 Weitere Aktionen

| Aktion | Umsetzung |
| --- | --- |
| Schützen | Toggle `db.chars[key].protected[questID]`, danach `MarkDirty()` |
| Tracking | `C_QuestLog.GetQuestWatchType(questID)` → `AddQuestWatch(questID)` / `RemoveQuestWatch(questID)`; Fallback `IsQuestWatched(index)` + `AddQuestWatch(index)` |
| Teilen | aktiv bei `C_QuestLog.IsPushableQuest(questID) and IsInGroup()`; Auswahl setzen → `QuestLogPushQuest()` → Auswahl zurück |
| Chat-Link | Shift-Klick auf Zeile: `ChatEdit_InsertLink(GetQuestLink(questID))` |
| Im Log öffnen | Linksklick auf Zeile: Retail-Weg `QuestMapFrame_OpenToQuestDetails(questID)`, sonst klassisch `ShowUIPanel(QuestLogFrame)` + `QuestLog_SetSelection(index)` (Schalter § 8) |

### 6.3 Einstieg

* `/qp` toggelt das Fenster.
* Kompaktes QuestPrune-Symbol in der Titelleiste der Karte (`WorldMapFrame`, alternativ `QuestMapFrame`): wird beim Login oder nach dem späteren Laden des Questlog-Add-ons eingehängt. Ein Klick schließt das Karten-/Questlogfenster und öffnet QuestPrune; der Zeilenklick wechselt zurück. Ist keiner der Frames verfügbar, bleibt der Slash-Befehl nutzbar.
* Der Kartenbutton verwendet standardmäßig die Client-Textur `MiniMap-TrackingBorder`, mit einem anhand des Forever-Screenshots korrigierten Versatz. `/qp compat mapbutton simple` blendet den Rahmen aus; `classic` aktiviert ihn wieder.

---

## 7. Slash-Befehle

| Befehl | Wirkung |
| --- | --- |
| `/qp` | Fenster ein/aus |
| `/qp lock` / `/qp unlock` | Fenster fixieren / verschiebbar |
| `/qp reset` | Position, Sortierung, Filter zurücksetzen (Schutzliste bleibt) |
| `/qp debug` | Debug-Ausgabe an/aus (Default aus) |
| `/qp dump` | Rohdaten aller Quests + API-Verfügbarkeit in den Chat (für Fehlerberichte) |
| `/qp compat <key> <value>` | Fallback-Schalter setzen, ohne Argument: alle anzeigen |
| `/qp help` | Hilfe |

Debug-Banner beim Einschalten: Client-Version (`GetBuildInfo`), `WOW_PROJECT_ID`, Verfügbarkeit jeder Compat-API (`ok`/`MISSING`). Pro Refresh eine Zeile `n quests, k pending, filter, sort`, nur ausgegeben, wenn sich die Signatur geändert hat.

---

## 8. Compat-Schicht (Fallbacks)

Jede unsichere API sitzt hinter einer Funktion; der aktive Weg ist per `/qp compat` umschaltbar und wird im Debug-Banner angezeigt.

| Schlüssel | Standard | Fallback |
| --- | --- | --- |
| `difficulty` | `GetQuestDifficultyColor` + Identitätsvergleich | eigene Rechnung über `GetQuestGreenRange()` |
| `max` | `C_QuestLog.GetMaxNumQuestsCanAccept()` | fester Wert (Default 20) |
| `tags` | `C_QuestLog.GetQuestTagInfo(questID)` + `Enum.QuestTag` | `info.suggestedGroup`, Titelsuffix `(Dungeon)` |
| `rewards` | `GetQuestLogRewardInfo(i, questID)` | Auswahl setzen + Index-Variante ohne `questID` |
| `qtext` | `GetQuestLogQuestText(index)` | Auswahl setzen, Text lesen, Auswahl zurück |
| `openlog` | `QuestMapFrame_OpenToQuestDetails` | `QuestLogFrame` + `QuestLog_SetSelection` |
| `statusicons` | Texturen `Interface\RaidFrame\ReadyCheck-Ready` / `-NotReady` | reiner Text ohne Symbol |

---

## 9. Offene Fragen & Risiken

Gleiche Liste wie in [CONCEPT.md § 5](CONCEPT.md#5-offene-fragen); dort wird sie gepflegt.

- [ ] **Quest-Limit in Forever:** Liefert `GetMaxNumQuestsCanAccept()` dort 20? Zählt `GetNumQuestLogEntries()` versteckte/Task-Quests mit? Im Spiel mit `/qp dump` prüfen.
- [ ] **Abbrechen per Add-on:** Ist `C_QuestLog.AbandonQuest()` in Forever (Midnight-ähnliche Einschränkungen) geschützt? Wenn ja, trägt das Konzept nicht; früh in 0.1.0 prüfen.
- [ ] **Questlog-UI in Forever:** Klassisches `QuestLogFrame` oder Retail-`QuestMapFrame`? Bestimmt Log-Button und `openlog`.
- [ ] **Tags:** Liefert `GetQuestTagInfo` in Forever Elite/Dungeon/Raid/PvP verlässlich, oder nur `suggestedGroup`?
- [ ] **Status-Icons:** Passen die Ready-Check-Texturen in 12 px? Sonst `statusicons`-Fallback.
- [ ] **Secret Values:** Bisher kein Hinweis, dass Quest-APIs betroffen sind; beim ersten Test im Debug-Banner prüfen.

---

## 10. Test ohne Spiel

Mit `lupa` (siehe globale Konvention):

1. **Syntax:** Datei per `load()` kompilieren.
2. **Mock-API:** `CreateFrame` (Frames, FontStrings, Textures als No-Op-Tabellen mit Recording), manuell getakteter `C_Timer`, `C_QuestLog` mit Fixture-Log:
   * graue 0 %-Quest, graue Quest mit 3/10, abgabebereite Quest, fehlgeschlagene Quest, geschützte graue 0 %-Quest, Dungeon-Elite, Quest mit ungecachten Rewards, Quest ohne Objectives.
3. **Szenarien** (Chat-Ausgabe und aufgerufene APIs werden mitgeschrieben):
   * 1 Klick auf 0 %-Quest oder fehlgeschlagene Quest → kein Abbruch; zweiter Klick → `AbandonQuest` genau einmal.
   * 1 Klick auf 3/10 → kein Abbruch, armed; Timer +3 s → idle; Klick, Klick → Abbruch.
   * 1 Klick auf abgabebereite Quest ohne Objectives → armed (nicht sofort, obwohl `progress == 0`).
   * Shift-Klick auf abgabebereite Quest → ebenfalls zuerst Bestätigung.
   * `Abandon()` auf geschützte Quest (direkt aufgerufen) → kein `AbandonQuest`.
   * Kein Code-Pfad ruft `AbandonQuest` mehr als einmal pro Klick auf.
   * 20× `QUEST_LOG_UPDATE` in einem Frame → genau ein `Refresh()`.
   * `QUEST_DATA_LOAD_RESULT` → `pending` verschwindet.
   * `QUEST_REMOVED` einer geschützten Quest → Lock entfernt.
   * Fehlende APIs (`GetQuestTagInfo = nil` usw.) → Fallback greift, kein Lua-Fehler.
4. **Mock-Bild:** [assets/mock.svg](assets/mock.svg), bei Designänderungen nachziehen und per Headless-Edge prüfen.

---

## 11. Meilensteine

| Version | Inhalt |
| --- | --- |
| 0.1.0 | Gerüst, DB, Slash, Snapshot + `/qp dump`, Debug-Banner (klärt die offenen API-Fragen im Spiel) |
| 0.2.0 | Fenster, Header, Questzeilen, Sortierung, Filter; experimenteller Einzelabbruch mit zwei Klicks zum frühen API-Test |
| 0.3.0 | Abbrechen (inkl. Scharfschalten), Schützen, Tracking, Teilen, Link, Log öffnen |
| 0.4.0 | Rewards inkl. Caching, Tooltips, Abandon-Item-Warnung |
| 1.0.0 | Icon, README, Store-Assets, Release-ZIP |
