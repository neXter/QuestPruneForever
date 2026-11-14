local ADDON = ...
local VERSION = "1.0.0"
local de = GetLocale() == "deDE"
local db
local function out(s) print("|cff66ccffQuestPrune|r: " .. s) end
local function say(en, german) out(de and german or en) end
local function available(t, k) return type(t) == "table" and type(t[k]) == "function" end
local function call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
  return nil
end
local rewardLoads={}
local function readRewards(questID)
  local data={items={}}
  if type(questID)~="number" or questID<=0 then data.unknown=true; return data end
  local selected=db and db.compat and db.compat.rewards=="selected"
  local previous
  if selected then
    if not (available(C_QuestLog,"GetSelectedQuest") and available(C_QuestLog,"SetSelectedQuest")) then return data end
    local ok; ok,previous=pcall(C_QuestLog.GetSelectedQuest)
    if not ok or not pcall(C_QuestLog.SetSelectedQuest,questID) then return data end
  end
  local function count(fn)
    if type(fn)~="function" then return nil end
    local ok,v
    if selected then ok,v=pcall(fn) else ok,v=pcall(fn,questID) end
    return ok and type(v)=="number" and math.max(0,math.floor(v)) or nil
  end
  local function amount(fn)
    if type(fn)~="function" then return nil end
    local ok,v
    if selected then ok,v=pcall(fn) else ok,v=pcall(fn,questID) end
    return ok and type(v)=="number" and v or nil
  end
  local function collect(kind, total, fn)
    if total==nil then data.unknown=true; return end
    for i=1,total do
      local ok,name,texture,countValue,quality,usable,itemID
      if type(fn)=="function" then
        if selected then ok,name,texture,countValue,quality,usable,itemID=pcall(fn,i)
        else ok,name,texture,countValue,quality,usable,itemID=pcall(fn,i,questID) end
      end
      if not ok or not texture then data.pending=true end
      data.items[#data.items+1]={kind=kind,slot=i,texture=texture,count=countValue,quality=quality,itemID=itemID,questID=questID}
    end
  end
  collect("choice",count(GetNumQuestLogChoices),GetQuestLogChoiceInfo)
  collect("reward",count(GetNumQuestLogRewards),GetQuestLogRewardInfo)
  data.money=amount(GetQuestLogRewardMoney); data.xp=amount(GetQuestLogRewardXP)
  if selected and previous then pcall(C_QuestLog.SetSelectedQuest,previous) end
  -- A zero reward count may also mean the quest has not been cached yet.
  -- Request each displayed quest at most once and refresh on the load event.
  if not rewardLoads[questID] and available(C_QuestLog,"RequestLoadQuestByID") and (type(GetNumQuestLogChoices)=="function" or type(GetNumQuestLogRewards)=="function") then
    rewardLoads[questID]=true; pcall(C_QuestLog.RequestLoadQuestByID,questID)
  end
  return data
end
local function formatMoney(copper)
  if type(copper)~="number" then return "?" end
  if copper<=0 then return "-" end
  if not (db and db.compat and db.compat.coins=="text") and available(C_CurrencyInfo,"GetCoinTextureString") then
    local ok, text=pcall(C_CurrencyInfo.GetCoinTextureString,copper,10)
    if ok and type(text)=="string" and text~="" then return text end
  end
  local gold=math.floor(copper/10000); local silver=math.floor(copper/100)%100; local bronze=math.floor(copper)%100
  local parts={}
  if gold>0 then parts[#parts+1]=gold.."g" end
  if silver>0 then parts[#parts+1]=silver.."s" end
  if bronze>0 then parts[#parts+1]=bronze..(de and "k" or "c") end
  return table.concat(parts," ")
end
local function formatXP(xp)
  if type(xp)~="number" then return "? XP" end
  if xp<=0 then return "-" end
  if xp>=1000 then return (("%.1fk XP"):format(xp/1000):gsub("%.0k","k")) end
  return math.floor(xp).." XP"
end
local function banner()
  local version, build = call(GetBuildInfo)
  out("v" .. VERSION .. " client=" .. tostring(version) .. " build=" .. tostring(build) .. " project=" .. tostring(WOW_PROJECT_ID))
  for _, name in ipairs({"GetNumQuestLogEntries", "GetInfo", "GetMaxNumQuestsCanAccept", "GetQuestTagInfo", "GetQuestObjectives", "RequestLoadQuestByID", "SetSelectedQuest", "SetAbandonQuest", "AbandonQuest", "GetQuestWatchType", "IsPushableQuest"}) do
    out("C_QuestLog." .. name .. "=" .. (available(C_QuestLog, name) and "ok" or "MISSING"))
  end
  out("QuestMapFrame=" .. tostring(QuestMapFrame ~= nil) .. " QuestLogFrame=" .. tostring(QuestLogFrame ~= nil))
end
local function snapshot()
  local result, zone = {}, ""
  local count, quests = call(C_QuestLog and C_QuestLog.GetNumQuestLogEntries)
  if not count then count, quests = call(GetNumQuestLogEntries) end
  count = type(count) == "number" and count or 0
  for i = 1, count do
    local info = call(C_QuestLog and C_QuestLog.GetInfo, i)
    if type(info) == "table" then
      if info.isHeader then zone = info.title or ""
      elseif not info.isHidden and not info.isTask and not info.isBounty then
        local objectives = call(C_QuestLog and C_QuestLog.GetQuestObjectives, info.questID)
        result[#result + 1] = { info = info, zone = zone, objectives = type(objectives) == "table" and objectives or {} }
      end
    end
  end
  return result, count, quests
end
local signature
local function refresh()
  local rows, entries, total = snapshot()
  local sig = #rows .. ":" .. entries .. ":" .. tostring(total)
  if db and db.debug and sig ~= signature then out("refresh: " .. #rows .. " visible quests, " .. entries .. " entries, total=" .. tostring(total)); signature = sig end
  return rows, entries, total
end
local function dump()
  banner()
  local rows, entries, total = refresh()
  local max = call(C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept)
  out("entries=" .. entries .. " total=" .. tostring(total) .. " visible=" .. #rows .. " max=" .. tostring(max or 20) .. (max and "" or " (fallback)"))
  for _, row in ipairs(rows) do
    local q = row.info
    out("id=" .. tostring(q.questID) .. " level=" .. tostring(q.level) .. " title=" .. tostring(q.title) .. " zone=" .. tostring(row.zone) .. " complete=" .. tostring(q.isComplete) .. " failed=" .. tostring(q.isFailed) .. " group=" .. tostring(q.suggestedGroup))
    for _, objective in ipairs(row.objectives) do
      out("  objective: " .. tostring(objective.text) .. " " .. tostring(objective.numFulfilled) .. "/" .. tostring(objective.numRequired) .. " finished=" .. tostring(objective.finished))
    end
    local tag = call(C_QuestLog and C_QuestLog.GetQuestTagInfo, q.questID)
    if type(tag) == "table" then out("  tagID=" .. tostring(tag.tagID) .. " tagName=" .. tostring(tag.tagName)) end
  end
end

local window, render, offset = nil, nil, 0
local LIST_HEIGHT, HEADER_HEIGHT, ROW_HEIGHT = 560, 20, 28
local ROW_POOL_SIZE = math.ceil(LIST_HEIGHT / HEADER_HEIGHT)
local HISTORY_ROWS = math.floor(LIST_HEIGHT / ROW_HEIGHT)
local armed, armToken = nil, 0
local protected
local character, pendingAbandon, offeredQuest
local activeTab = "active"
local function recordOffer()
  local id = call(GetQuestID)
  if type(id) ~= "number" or id <= 0 then offeredQuest=nil; return end
  local mapID = call(C_Map and C_Map.GetBestMapForUnit, "player")
  local position = mapID and call(C_Map and C_Map.GetPlayerMapPosition, mapID, "player")
  local x,y
  if position and type(position.GetXY)=="function" then x,y=call(position.GetXY,position) end
  local mapInfo = mapID and call(C_Map and C_Map.GetMapInfo, mapID)
  offeredQuest={id=id, title=call(GetTitleText), giver=call(UnitName,"npc"), mapID=mapID,
    map=type(mapInfo)=="table" and mapInfo.name or nil, x=x, y=y}
end
local sorts = {"level", "zone", "progress", "type"}
local filters = {"all", "lowvalue", "untouched", "group", "dungeon", "raid", "pvp", "complete", "postclassic", "class", "profession"}
-- The largest original Classic quest ID in Questie's Classic data is 9665.
-- Higher IDs are post-Classic, but may come from later Classic content rather than Forever.
local function isPostClassic(id) return type(id)=="number" and id>9665 end
local function progress(row)
  if #row.objectives == 0 then return nil end
  local total = 0
  for _, objective in ipairs(row.objectives) do
    local have, need = tonumber(objective.numFulfilled), tonumber(objective.numRequired)
    if have and need and need > 0 then total = total + math.min(have / need, 1)
    elseif objective.finished then total = total + 1
    else return nil end
  end
  return total / #row.objectives
end
local function label(en, german) return de and german or en end
local function hasPosition(record)
  return record and type(record.mapID)=="number" and record.mapID>0 and type(record.x)=="number" and type(record.y)=="number" and record.x>=0 and record.x<=1 and record.y>=0 and record.y<=1
end
local function setWaypoint(record)
  if not hasPosition(record) then say("No saved map coordinates for this quest.", "Für diese Quest sind keine Kartenkoordinaten gespeichert."); return end
  if available(C_Map,"SetUserWaypoint") and available(UiMapPoint,"CreateFromCoordinates") then
    local ok, result=pcall(function()
      if available(C_Map,"CanSetUserWaypointOnMap") and not C_Map.CanSetUserWaypointOnMap(record.mapID) then return false end
      local point=UiMapPoint.CreateFromCoordinates(record.mapID,record.x,record.y)
      if not point then return false end
      return C_Map.SetUserWaypoint(point) ~= false
    end)
    if ok and result then
      if available(C_SuperTrack,"SetSuperTrackedUserWaypoint") then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint,true) end
      say("Waypoint set to the saved acceptance position.", "Wegpunkt zur gespeicherten Annahmeposition gesetzt.")
      return
    end
  end
  if type(TomTom)=="table" and type(TomTom.AddWaypoint)=="function" then
    local ok, result=pcall(TomTom.AddWaypoint,TomTom,record.mapID,record.x,record.y,{title=record.title or "QuestPrune"})
    if ok and result then say("TomTom waypoint set to the saved acceptance position.", "TomTom-Wegpunkt zur gespeicherten Annahmeposition gesetzt."); return end
  end
  say("Could not set a waypoint on this map.", "Auf dieser Karte konnte kein Wegpunkt gesetzt werden.")
end
local function abandon(row)
  local q = row.info
  if not q.questID or not protected or protected[q.questID] then return end
  -- Re-read the quest before deciding whether it can be abandoned immediately.
  local current = snapshot()
  local found
  for _, entry in ipairs(current) do if entry.info.questID == q.questID then found = entry; break end end
  if not found then say("Quest no longer in log.", "Quest nicht mehr im Log."); render(); return end
  if armed ~= q.questID then
    armed = q.questID; armToken = armToken + 1
    local token = armToken
    C_Timer.After(3, function() if token == armToken then armed = nil; if window and window:IsShown() then render() end end end)
    render(); return
  end
  armed = nil; armToken = armToken + 1
  local api = C_QuestLog
  if not (available(api, "GetSelectedQuest") and available(api, "SetSelectedQuest") and available(api, "SetAbandonQuest") and available(api, "AbandonQuest")) then
    say("Abandon API unavailable; no action taken.", "Abbruch-API nicht verfügbar; keine Aktion ausgeführt."); render(); return
  end
  local ok, previous = pcall(api.GetSelectedQuest)
  if not ok then say("Could not read quest selection.", "Quest-Auswahl konnte nicht gelesen werden."); render(); return end
  pendingAbandon={id=q.questID, title=q.title, zone=found.zone}
  local attempt=pendingAbandon
  local success, err = pcall(function() api.SetSelectedQuest(q.questID); api.SetAbandonQuest(); api.AbandonQuest() end)
  if not success then pendingAbandon=nil end
  if success then C_Timer.After(5, function() if pendingAbandon==attempt then pendingAbandon=nil end end) end
  if previous then pcall(api.SetSelectedQuest, previous) end
  if not success then out(label("Abandon call failed: ", "Abbruch fehlgeschlagen: ") .. tostring(err))
  else out(label("Abandon requested for: ", "Abbruch angefordert für: ") .. tostring(q.title) .. label(". Check the quest log.", ". Bitte Questlog prüfen.")) end
  render()
end
local function cycle(values, current)
  for i, v in ipairs(values) do if v == current then return values[i % #values + 1] end end
  return values[1]
end
local function flatButton(parent, width, height)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width, height)
  b:SetNormalFontObject("GameFontHighlightSmall")
  local border = b:CreateTexture(nil, "BACKGROUND", nil, -1)
  border:SetAllPoints(); border:SetColorTexture(0.48, 0.37, 0.22, 1)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT", 1, -1); bg:SetPoint("BOTTOMRIGHT", -1, 1); bg:SetColorTexture(0.16, 0.12, 0.08, 1)
  b.bg = bg
  local bevel = b:CreateTexture(nil, "BORDER")
  bevel:SetPoint("TOPLEFT", 2, -2); bevel:SetPoint("TOPRIGHT", -2, -2); bevel:SetHeight(1); bevel:SetColorTexture(0.85, 0.68, 0.39, 0.4)
  local shadow = b:CreateTexture(nil, "BORDER")
  shadow:SetPoint("BOTTOMLEFT", 2, 2); shadow:SetPoint("BOTTOMRIGHT", -2, 2); shadow:SetHeight(1); shadow:SetColorTexture(0, 0, 0, 0.65)
  local highlight = b:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints(); highlight:SetColorTexture(1, 0.75, 0.32, 0.18)
  return b
end
local ICONS = "Interface\\AddOns\\QuestPruneForever\\Icons\\"
local function iconButton(parent, icon)
  local button = flatButton(parent, 24, 22)
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetSize(18, 18); button.icon:SetPoint("CENTER")
  button.icon:SetTexture(ICONS .. icon)
  return button
end
local function decorateControl(button, icon)
  button.icon=button:CreateTexture(nil,"ARTWORK"); button.icon:SetSize(14,14); button.icon:SetPoint("LEFT",4,0); button.icon:SetTexture(ICONS .. icon)
  button.caption=button:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  button.caption:SetPoint("LEFT",button.icon,"RIGHT",2,0); button.caption:SetPoint("RIGHT",-3,0); button.caption:SetJustifyH("CENTER"); button.caption:SetWordWrap(false)
end
local function captionWidth(caption, ...)
  local width=0
  for i=1,select("#",...) do caption:SetText(select(i,...)); width=math.max(width,caption:GetStringWidth() or 0) end
  return math.ceil(width)+26
end
local function filterLabels()
  return {all=label("All", "Alle"), lowvalue=label("Grey / Green", "Grau / Grün"), untouched="0 %", group=label("Group", "Gruppe"), dungeon="Dungeon", raid=label("Raid", "Schlachtzug"), pvp="PvP", complete=label("Ready", "Fertig"), postclassic=label("Post-Classic (quest ID > 9665)", "Nach Classic (Quest-ID > 9665)"), class=label("Class quests", "Klassenquests"), profession=label("Profession quests", "Berufsquests")}
end
local function categoryHeaders()
  local classes, professions = {}, {}
  local function add(set, name) if type(name)=="string" and name~="" then set[name:lower()]=true end end
  for _, names in ipairs({LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {}}) do
    for _, name in pairs(names) do add(classes,name) end
  end
  for i=1,20 do add(classes,call(GetClassInfo,i)) end
  for _, name in ipairs(de and {"Krieger","Paladin","Jäger","Schurke","Priester","Schamane","Magier","Hexenmeister","Druide","Todesritter","Mönch","Dämonenjäger","Rufer"} or {"Warrior","Paladin","Hunter","Rogue","Priest","Shaman","Mage","Warlock","Druid","Death Knight","Monk","Demon Hunter","Evoker"}) do add(classes,name) end
  for _, name in ipairs(de and {"Alchemie","Schmiedekunst","Verzauberkunst","Ingenieurskunst","Kräuterkunde","Lederverarbeitung","Bergbau","Kürschnerei","Schneiderei","Kochen","Erste Hilfe","Angeln","Juwelenschleifen","Inschriftenkunde","Archäologie","Reiten"} or {"Alchemy","Blacksmithing","Enchanting","Engineering","Herbalism","Leatherworking","Mining","Skinning","Tailoring","Cooking","First Aid","Fishing","Jewelcrafting","Inscription","Archaeology","Riding"}) do add(professions,name) end
  for _, id in ipairs({2259,2018,7411,4036,2366,2108,2575,8613,3908,2550,3273,7620,25229,45357,78670,33388}) do
    local spell=call(C_Spell and C_Spell.GetSpellInfo,id)
    add(professions,type(spell)=="table" and spell.name or call(GetSpellInfo,id))
  end
  return classes,professions
end
local function buttonTip(button, row, text)
  button:SetScript("OnEnter", function(self)
    row:LockHighlight()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(text()); GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() row:UnlockHighlight(); GameTooltip:Hide() end)
end
local function difficultyGroup(level)
  local c = call(GetQuestDifficultyColor, level)
  if type(c) ~= "table" or type(c.r) ~= "number" or type(c.g) ~= "number" or type(c.b) ~= "number" then return 6 end
  local r,g,b=c.r,c.g,c.b
  if math.abs(r-g)<0.08 and math.abs(g-b)<0.08 then return 1 end
  if g>r then return 2 end
  if g>=0.8 then return 3 end
  if g>=0.35 then return 4 end
  return 5
end
local function statusGroup(row)
  if row.info.isFailed then return 5 end
  if row.info.isComplete then return 4 end
  if row.progress == nil then return 3 end
  if row.progress == 0 then return 1 end
  return 2
end
local function statusText(row)
  local q=row.info
  if q.isFailed then return label("Failed", "Fehlgeschlagen") end
  if q.isComplete then return label("Complete", "Fertig") end
  local open={}
  for _, objective in ipairs(row.objectives) do
    if not objective.finished and objective.text then open[#open+1]=objective.text end
  end
  if #open>0 then return table.concat(open,"\n") end
  return row.progress and math.floor(row.progress*100).."%" or "?"
end
local function questType(q, tag)
  local tagID=type(tag)=="table" and tag.tagID or nil
  local raidTag=Enum and Enum.QuestTag and Enum.QuestTag.Raid
  if tagID==81 then return "dungeon" end
  if tagID==41 then return "pvp" end
  if raidTag and tagID==raidTag then return "raid" end
  if tagID==1 or (q.suggestedGroup or 0)>0 then return "group" end
  if tagID~=nil or not available(C_QuestLog,"GetQuestTagInfo") then return "unknown" end
  return "solo"
end
local function applyWindowSkin()
  if not window then return end
  if db and db.compat and db.compat.skin=="plain" then
    window:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=14, insets={left=3,right=3,top=3,bottom=3}})
    window:SetBackdropColor(0.075,0.055,0.04,1); window:SetBackdropBorderColor(0.72,0.60,0.40,1)
  else
    window:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=8,right=8,top=8,bottom=8}})
    window:SetBackdropColor(0.55,0.48,0.39,1); window:SetBackdropBorderColor(1,1,1,1)
  end
end
local function createWindow()
  window = CreateFrame("Frame", "QuestPruneForeverFrame", UIParent, "BackdropTemplate")
  window:Hide()
  window:SetFrameStrata("DIALOG")
  window:SetSize(720, 660); window:SetPoint("CENTER"); window:SetClampedToScreen(true); window:SetMovable(true)
  window:EnableMouse(true); window:RegisterForDrag("LeftButton")
  if window.SetDontSavePosition then window:SetDontSavePosition(true) end
  local emblem = window:CreateTexture(nil, "OVERLAY", nil, 7)
  emblem:SetSize(54,54); emblem:SetPoint("TOPLEFT", -12, 12); emblem:SetTexture(ICONS .. "medallion")
  -- Cover any translucent client backdrop before drawing rows or controls.
  local opaque = window:CreateTexture(nil, "BACKGROUND", nil, -7)
  opaque:SetPoint("TOPLEFT", 7, -7); opaque:SetPoint("BOTTOMRIGHT", -7, 7)
  opaque:SetColorTexture(0.075,0.055,0.04,1); window.opaque=opaque
  local bar = window:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT", 10, -7); bar:SetPoint("TOPRIGHT", -10, -7); bar:SetHeight(25); bar:SetTexture(ICONS.."titlebar"); window.titleBar=bar
  applyWindowSkin()
  local titleRule = window:CreateTexture(nil, "OVERLAY")
  titleRule:SetPoint("TOPLEFT", 44, -32); titleRule:SetPoint("TOPRIGHT", -14, -32); titleRule:SetHeight(1); titleRule:SetColorTexture(0.77,0.58,0.31,0.65)
  local rule = window:CreateTexture(nil, "ARTWORK")
  rule:SetPoint("TOPLEFT", 12, -64); rule:SetPoint("TOPRIGHT", -12, -64); rule:SetHeight(1); rule:SetColorTexture(0.49, 0.37, 0.20, 0.8)
  if db.pos then window:ClearAllPoints(); window:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4]) end
  window:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
  window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, r, x, y = self:GetPoint(); db.pos={p,r,x,y} end)
  tinsert(UISpecialFrames, "QuestPruneForeverFrame")
  local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 48, -12); title:SetText("QuestPrune")
  window.count = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  window.count:SetPoint("LEFT", title, "RIGHT", 20, 0)
  local close = CreateFrame("Button", nil, window, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -2, -2)
  local lock = iconButton(window, "protect"); lock:SetPoint("RIGHT", bar, "RIGHT", -26, 0)
  lock:SetScript("OnClick", function() db.locked = not db.locked; render() end); window.lock = lock
  lock:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(db.locked and label("Unlock window", "Fenster entsperren") or label("Lock window", "Fenster sperren")); GameTooltip:Show() end)
  lock:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local sort = flatButton(window, 160, 22); sort:SetPoint("TOPLEFT", 48, -38); decorateControl(sort,"sort")
  sort:SetScript("OnClick", function() db.sort=cycle(sorts, db.sort); offset=0; render() end); window.sort=sort
  local filter = flatButton(window, 50, 22); filter:SetPoint("LEFT", sort, "RIGHT", 8, 0); decorateControl(filter,"all")
  filter:SetScript("OnClick", function() db.filter="all"; offset=0; render() end); window.filterButtons={all=filter}
  window.rows={}
  for i=1,ROW_POOL_SIZE do
    local row=CreateFrame("Button", nil, window); row:SetSize(690, 28); row:SetPoint("TOPLEFT", 15, -67-(i-1)*28)
    row.currentZone=row:CreateTexture(nil,"BACKGROUND"); row.currentZone:SetPoint("TOPLEFT",0,0); row.currentZone:SetPoint("BOTTOMLEFT",0,0); row.currentZone:SetWidth(2); row.currentZone:SetColorTexture(0.85,0.68,0.34,0.65)
    row.headerBg=row:CreateTexture(nil,"BACKGROUND"); row.headerBg:SetPoint("BOTTOMLEFT", 4, 0); row.headerBg:SetPoint("BOTTOMRIGHT", -4, 0); row.headerBg:SetHeight(1); row.headerBg:SetColorTexture(0.55,0.42,0.25,0.35)
    row.header=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); row.header:SetPoint("LEFT", 8, 0); row.header:SetTextColor(0.72,0.62,0.44)
    if i % 2 == 0 then local stripe=row:CreateTexture(nil,"BACKGROUND"); stripe:SetAllPoints(); stripe:SetColorTexture(0.8,0.57,0.27,0.045) end
    row.level=row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.level:SetPoint("LEFT", 26, 0); row.level:SetWidth(40); row.level:SetJustifyH("LEFT")
    row.kind=row:CreateTexture(nil, "ARTWORK"); row.kind:SetSize(16,16); row.kind:SetPoint("LEFT", 6, 0)
    row.text=row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.text:SetPoint("LEFT", 70, 6); row.text:SetWidth(150); row.text:SetJustifyH("LEFT"); row.text:SetWordWrap(false)
    row.category=row:CreateTexture(nil,"ARTWORK"); row.category:SetSize(16,16); row.category:SetPoint("LEFT",222,0)
    row.forever=row:CreateTexture(nil,"ARTWORK"); row.forever:SetSize(16,16); row.forever:SetPoint("LEFT",241,0); row.forever:SetTexture(ICONS.."forever")
    row.zone=row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); row.zone:SetPoint("LEFT", 70, -7); row.zone:SetWidth(150); row.zone:SetJustifyH("LEFT"); row.zone:SetWordWrap(false)
    row.status=row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.status:SetPoint("LEFT", 260, 0); row.status:SetWidth(170); row.status:SetJustifyH("LEFT"); row.status:SetJustifyV("MIDDLE"); row.status:SetWordWrap(true)
    row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row:SetScript("OnClick", function(self)
      if activeTab=="abandoned" then if self.data then setWaypoint(self.data.record) end; return end
      if not self.data or not self.data.info.questID then return end
      if type(QuestMapFrame_OpenToQuestDetails) ~= "function" then
        say("Opening quest details is unavailable on this client.", "Questdetails können auf diesem Client nicht geöffnet werden.")
        return
      end
      local ok, err = pcall(QuestMapFrame_OpenToQuestDetails, self.data.info.questID)
      if ok then window:Hide() else out(label("Could not open quest: ", "Quest konnte nicht geöffnet werden: ") .. tostring(err)) end
    end)
    row:SetScript("OnEnter", function(self)
      if not self.data then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.data.info.title or "?")
      if isPostClassic(self.data.info.questID) then GameTooltip:AddLine(label("Post-Classic ID; not necessarily new to Forever", "ID nach Classic; nicht zwingend neu in Forever"),0.45,0.85,0.9,true) end
      if activeTab=="abandoned" then
        GameTooltip:AddLine(self.data.zone or "", 1, 1, 1, true)
        GameTooltip:AddLine(self.data.location or label("Location unknown", "Fundort unbekannt"), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(label("Position recorded when accepted; it may differ from the quest giver's position.", "Position bei Annahme gespeichert; sie kann vom Questgeber abweichen."), 0.7,0.7,0.7,true)
        if hasPosition(self.data.record) then GameTooltip:AddLine(label("Click to set a waypoint", "Klicken, um einen Wegpunkt zu setzen"),0.5,0.8,1,true) end
        GameTooltip:Show(); return
      end
      GameTooltip:AddLine(self.data.zone or "", 0.7, 0.7, 0.7)
      if self.data.category then GameTooltip:AddLine(self.data.category=="class" and label("Class quest (quest log heading)", "Klassenquest (Questlog-Überschrift)") or label("Profession quest (quest log heading)", "Berufsquest (Questlog-Überschrift)"),1,0.82,0,true) end
      if self.kindLabel then GameTooltip:AddLine(self.kindLabel, 1, 0.82, 0) end
      for _, objective in ipairs(self.data.objectives) do
        GameTooltip:AddLine(objective.text or "?", objective.finished and 0.3 or 1, 1, objective.finished and 0.3 or 1, true)
      end
      GameTooltip:AddLine(label("Click to open quest details", "Klicken für Questdetails"), 0.5, 0.8, 1, true)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.button=iconButton(row, "abandon"); row.button:SetPoint("RIGHT", -2, 0)
    row.button.icon:ClearAllPoints(); row.button.icon:SetPoint("LEFT", 4, 0)
    row.button.caption=row.button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.button:SetWidth(captionWidth(row.button.caption, label("Abandon", "Abbrechen"), label("Sure?", "Sicher?"), label("Waypoint", "Wegpunkt")))
    row.button.caption:SetPoint("LEFT", row.button.icon, "RIGHT", 2, 0); row.button.caption:SetPoint("RIGHT", -3, 0); row.button.caption:SetJustifyH("CENTER")
    row.button:SetScript("OnClick", function() if row.data then if activeTab=="abandoned" then setWaypoint(row.data.record) else abandon(row.data) end end end)
    buttonTip(row.button, row, function() if activeTab=="abandoned" then return label("Waypoint to saved acceptance position", "Wegpunkt zur gespeicherten Annahmeposition") end return armed == (row.data and row.data.info.questID) and label("Click again to confirm", "Zum Bestätigen erneut klicken") or label("Abandon quest: click twice to confirm", "Quest abbrechen: zweimal klicken") end)
    row.protect=iconButton(row, "protect"); row.protect:SetPoint("RIGHT", row.button, "LEFT", -3, 0)
    row.protect.icon:ClearAllPoints(); row.protect.icon:SetPoint("LEFT", 4, 0)
    row.protect.caption=row.protect:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.protect:SetWidth(captionWidth(row.protect.caption, label("Protect", "Schützen"), label("Protected", "Geschützt")))
    row.protect.caption:SetPoint("LEFT", row.protect.icon, "RIGHT", 2, 0); row.protect.caption:SetPoint("RIGHT", -3, 0); row.protect.caption:SetJustifyH("CENTER")
    buttonTip(row.protect, row, function() return protected and row.data and protected[row.data.info.questID] and label("Remove quest protection", "Questschutz aufheben") or label("Protect quest", "Quest schützen") end)
    row.protect:SetScript("OnClick", function()
      local id = row.data and row.data.info.questID
      if not id or not protected then return end
      protected[id] = not protected[id] or nil
      armed=nil; armToken=armToken+1; render()
    end)
    window.rows[i]=row
  end
  local previous=filter
  local widths={lowvalue=88, untouched=44, group=75, dungeon=85, raid=75, pvp=65, complete=70, postclassic=70, class=70, profession=70}
  for _, key in ipairs({"lowvalue", "untouched", "group", "dungeon", "raid", "pvp", "complete", "postclassic", "class", "profession"}) do
    local selected=key
    local button=flatButton(window,widths[key],22); button:SetPoint("LEFT",previous,"RIGHT",3,0)
    local icons={lowvalue="low", untouched="zero", group="group", dungeon="dungeon", raid="raid", pvp="pvp", complete="complete", postclassic="forever", class="class", profession="profession"}; decorateControl(button,icons[key])
    button:SetScript("OnClick",function() db.filter=db.filter==selected and "all" or selected; offset=0; render() end)
    window.filterButtons[key]=button; previous=button
  end
  -- Compact icon tabs leave space for the localized sort label.
  local measure=window:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  window.rewardWidthMeasure=measure
  for _, key in ipairs(filters) do
    local button=window.filterButtons[key]
    local filterName=filterLabels()[key]
    button:SetWidth(28); button.caption:Hide()
    button.icon:ClearAllPoints(); button.icon:SetPoint("CENTER")
    button:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:SetText(filterName); if self.filterCount==0 then GameTooltip:AddLine(label("No matching quests", "Keine passenden Quests"),0.65,0.65,0.65) end; GameTooltip:Show() end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
  end
  sort:SetWidth(160)
  local activeButton=flatButton(window,24,22); decorateControl(activeButton,"active")
  local abandonedButton=flatButton(window,24,22); decorateControl(abandonedButton,"abandon")
  local activeLabel=label("Active", "Aktiv"); local abandonedLabel=label("Abandoned", "Abgebrochen")
  activeButton:SetWidth(captionWidth(measure,activeLabel)+4); activeButton.caption:SetText(activeLabel)
  abandonedButton:SetWidth(captionWidth(measure,abandonedLabel)+4); abandonedButton.caption:SetText(abandonedLabel)
  abandonedButton:SetPoint("RIGHT",lock,"LEFT",-8,0); activeButton:SetPoint("RIGHT",abandonedButton,"LEFT",-3,0)
  local function selectTab(tab) activeTab=tab; offset=0; armed=nil; armToken=armToken+1; render() end
  activeButton:SetScript("OnClick",function() selectTab("active") end)
  abandonedButton:SetScript("OnClick",function() selectTab("abandoned") end)
  window.activeTab=activeButton; window.abandonedTab=abandonedButton
  for _, row in ipairs(window.rows) do
    local group=CreateFrame("Frame",nil,row); group:SetSize(138,26); group:SetPoint("RIGHT",row.protect,"LEFT",-5,0); row.rewards=group
    group.money=group:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); group.money:SetPoint("TOPRIGHT",-1,-1); group.money:SetWidth(68); group.money:SetJustifyH("RIGHT"); group.money:SetWordWrap(false); group.money:SetTextColor(1,0.82,0)
    group.xp=group:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); group.xp:SetPoint("BOTTOMRIGHT",-1,1); group.xp:SetWidth(68); group.xp:SetJustifyH("RIGHT"); group.xp:SetWordWrap(false); group.xp:SetTextColor(0.6,0.75,1)
    group.more=group:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); group.more:SetPoint("RIGHT",group.money,"LEFT",-1,0); group.more:SetWidth(14); group.more:SetJustifyH("RIGHT")
    group.items={}
    for i=1,2 do
      local item=CreateFrame("Button",nil,group); item:SetSize(16,16); item:SetPoint("LEFT",(i-1)*18,0)
      item.border=item:CreateTexture(nil,"BACKGROUND"); item.border:SetAllPoints(); item.border:SetColorTexture(0.6,0.6,0.6,1)
      item.icon=item:CreateTexture(nil,"ARTWORK"); item.icon:SetPoint("TOPLEFT",1,-1); item.icon:SetPoint("BOTTOMRIGHT",-1,1)
      item.count=item:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); item.count:SetPoint("BOTTOMRIGHT",0,0)
      item:SetScript("OnEnter",function(self)
        local reward=self.reward; if not reward then return end
        row:LockHighlight(); GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        local shown=false
        if reward.texture and type(GameTooltip.SetQuestLogItem)=="function" then
          local selected=db.compat.rewards=="selected"; local old, selectedOK
          if selected and available(C_QuestLog,"GetSelectedQuest") and available(C_QuestLog,"SetSelectedQuest") then
            local ok; ok,old=pcall(C_QuestLog.GetSelectedQuest)
            if ok then selectedOK=pcall(C_QuestLog.SetSelectedQuest,reward.questID) end
          end
          if not selected or selectedOK then
            local ok
            if selected then ok=pcall(GameTooltip.SetQuestLogItem,GameTooltip,reward.kind,reward.slot)
            else ok=pcall(GameTooltip.SetQuestLogItem,GameTooltip,reward.kind,reward.slot,reward.questID) end
            shown=ok
          end
          if selectedOK and old then pcall(C_QuestLog.SetSelectedQuest,old) end
        end
        if not shown and reward.itemID and type(GameTooltip.SetItemByID)=="function" then shown=pcall(GameTooltip.SetItemByID,GameTooltip,reward.itemID) end
        if not shown then GameTooltip:SetText(label("Reward data unavailable", "Belohnungsdaten nicht verfügbar")) end
        if shown and type(IsModifiedClick)=="function" and IsModifiedClick("COMPAREITEMS") and type(GameTooltip_ShowCompareItem)=="function" then GameTooltip_ShowCompareItem(GameTooltip) end
        GameTooltip:Show()
      end)
      item:SetScript("OnLeave",function() row:UnlockHighlight(); GameTooltip:Hide() end)
      group.items[i]=item
    end
  end
  local hint=window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); hint:SetPoint("BOTTOMLEFT", 16, 10); hint:SetText(label("Click: details. Wheel: scroll. Abandon: click twice.", "Klick: Details. Mausrad: scrollen. Abbrechen: zweimal klicken."))
  window:EnableMouseWheel(true); window:SetScript("OnMouseWheel", function(_, delta) offset=math.max(0, math.min(window.maxOffset or 0, offset-delta)); render() end)
  window:SetScript("OnHide", function() armed=nil; armToken=armToken+1 end)
end
render = function()
  if not window then return end
  local isHistory=activeTab=="abandoned"
  window.activeTab.bg:SetColorTexture(isHistory and 0.16 or 0.39, isHistory and 0.12 or 0.27, 0.08, 1)
  window.abandonedTab.bg:SetColorTexture(isHistory and 0.39 or 0.16, isHistory and 0.27 or 0.12, 0.08, 1)
  window.sort:SetShown(not isHistory)
  for _, button in pairs(window.filterButtons) do button:SetShown(not isHistory) end
  if isHistory then
    local entries={}
    for id, record in pairs(character and character.abandoned or {}) do entries[#entries+1]={id=id,record=record} end
    table.sort(entries,function(a,b) return (a.record.title or "") < (b.record.title or "") end)
    window.count:SetText(tostring(#entries)..label(" saved", " gespeichert")); window.count:SetTextColor(1,1,1)
    window.maxOffset=math.max(0,#entries-HISTORY_ROWS); offset=math.min(offset,window.maxOffset)
    for i, widget in ipairs(window.rows) do
      local entry=i<=HISTORY_ROWS and entries[offset+i] or nil
      if entry then
        local r=entry.record
        local giver=r.giver or label("Quest giver unknown", "Questgeber unbekannt")
        local location=r.map or r.zone or label("Location unknown", "Fundort unbekannt")
        if type(r.x)=="number" and type(r.y)=="number" then location=location..("  %.1f, %.1f"):format(r.x*100,r.y*100) end
        widget.data={info={title=r.title or ("#"..tostring(entry.id))},zone=giver,location=location,objectives={},record=r}
        widget.header:Hide(); widget.headerBg:Hide(); widget.currentZone:Hide(); widget.kind:Hide(); widget.category:Hide(); widget.forever:Hide(); widget.level:Hide(); widget.protect:Hide(); widget.rewards:Hide()
        widget.button.icon:SetTexture(ICONS.."waypoint"); widget.button.caption:SetText(label("Waypoint", "Wegpunkt")); widget.button.bg:SetColorTexture(0.16,0.12,0.08,1)
        widget.button:SetShown(hasPosition(r))
        widget.text:Show(); widget.zone:Show(); widget.status:Show(); widget:EnableMouse(true)
        widget.text:ClearAllPoints(); widget.text:SetPoint("LEFT",64,6); widget.text:SetText(widget.data.info.title); widget.zone:SetText(giver)
        widget.status:SetText(location); widget.status:SetHeight(22); widget.status:SetTextColor(0.82,0.82,0.82)
        widget.text:SetAlpha(1); widget.zone:SetAlpha(1); widget.status:SetAlpha(1)
        widget:SetHeight(28); widget:ClearAllPoints(); widget:SetPoint("TOPLEFT",15,-67-(i-1)*28); widget:Show()
      else widget.data=nil; widget:Hide() end
    end
    return
  end
  local rows, _, total=refresh(); local filtered={}
  local filterCounts={all=0,lowvalue=0,untouched=0,group=0,dungeon=0,raid=0,pvp=0,complete=0,postclassic=0,class=0,profession=0}
  local classes, professions=categoryHeaders()
  local realZone=call(GetRealZoneText)
  local displayZone=call(GetZoneText)
  local function isCurrentZone(zone)
    return type(zone)=="string" and zone~="" and ((type(realZone)=="string" and realZone~="" and zone==realZone) or (type(displayZone)=="string" and displayZone~="" and zone==displayZone))
  end
  for _, row in ipairs(rows) do
    local q=row.info; local p=progress(row); local tag=call(C_QuestLog and C_QuestLog.GetQuestTagInfo, q.questID)
    local color=call(GetQuestDifficultyColor, q.level)
    local low=type(color)=="table" and ((color.g or 0) > (color.r or 0) or (math.abs((color.r or 0)-(color.g or 0)) < 0.05 and math.abs((color.g or 0)-(color.b or 0)) < 0.05)) or false
    local kind=questType(q,tag)
    local header=type(row.zone)=="string" and row.zone:lower() or ""
    local category=classes[header] and "class" or professions[header] and "profession" or nil
    filterCounts.all=filterCounts.all+1
    if low then filterCounts.lowvalue=filterCounts.lowvalue+1 end
    if p==0 and not q.isComplete and not q.isFailed then filterCounts.untouched=filterCounts.untouched+1 end
    if q.isComplete then filterCounts.complete=filterCounts.complete+1 end
    if isPostClassic(q.questID) then filterCounts.postclassic=filterCounts.postclassic+1 end
    if filterCounts[kind] then filterCounts[kind]=filterCounts[kind]+1 end
    if category then filterCounts[category]=filterCounts[category]+1 end
    local match=db.filter=="all" or (db.filter=="untouched" and p==0 and not q.isComplete and not q.isFailed) or (db.filter=="complete" and q.isComplete) or (db.filter=="postclassic" and isPostClassic(q.questID)) or (db.filter==category and category~=nil) or (db.filter==kind and filterCounts[kind]~=nil) or (db.filter=="lowvalue" and low)
    if match then
      row.progress=p
      row.kind=kind
      row.category=category
      row.currentZone=isCurrentZone(row.zone)
      if db.sort=="zone" then row.groupKey=row.zone ~= "" and row.zone or label("Unknown zone", "Unbekanntes Gebiet")
      elseif db.sort=="progress" then row.groupKey=statusGroup(row)
      elseif db.sort=="type" then row.groupKey=({solo=1,class=2,profession=3,group=4,dungeon=5,raid=6,pvp=7,unknown=8})[category or kind]
      else row.groupKey=difficultyGroup(q.level) end
      filtered[#filtered+1]=row
    end
  end
  table.sort(filtered, function(a,b)
    local av,bv
    if db.sort=="zone" and a.currentZone~=b.currentZone then return a.currentZone end
    av,bv=a.groupKey,b.groupKey
    if av~=bv then return av<bv end
    if db.sort=="progress" and a.progress ~= b.progress then return (a.progress or -1)<(b.progress or -1) end
    if db.sort~="progress" and (a.info.level or 0)~=(b.info.level or 0) then return (a.info.level or 0)<(b.info.level or 0) end
    return (a.info.title or "")<(b.info.title or "")
  end)
  local entries, lastGroup={}, nil
  local difficultyNames={label("Grey", "Grau"),label("Green", "Grün"),label("Yellow", "Gelb"),label("Orange", "Orange"),label("Red", "Rot"),label("Unknown difficulty", "Unbekannte Schwierigkeit")}
  local statusNames={label("Untouched", "Unberührt"),label("In progress", "In Arbeit"),label("Unknown progress", "Fortschritt unbekannt"),label("Ready to turn in", "Abgabebereit"),label("Failed", "Fehlgeschlagen")}
  local typeNames={label("Solo", "Solo"),label("Class", "Klasse"),label("Profession", "Beruf"),label("Group / Elite", "Gruppe / Elite"),label("Dungeon", "Dungeon"),label("Raid", "Schlachtzug"),"PvP",label("Unknown type", "Unbekannter Typ")}
  for _, row in ipairs(filtered) do
    if row.groupKey~=lastGroup then
      local title = db.sort=="zone" and row.groupKey or (db.sort=="progress" and statusNames[row.groupKey] or db.sort=="type" and typeNames[row.groupKey] or difficultyNames[row.groupKey])
      if db.sort=="zone" and row.currentZone then title=title .. label(" (Current zone)", " (Aktuelles Gebiet)") end
      entries[#entries+1]={heading=title, currentZone=db.sort=="zone" and row.currentZone}; lastGroup=row.groupKey
    end
    entries[#entries+1]=row
  end
  -- Measure the same wrapped text used by the rows, then fill the last page
  -- backwards so the final scroll position contains no avoidable empty space.
  local listHeight=LIST_HEIGHT
  local measureRow=window.rows[1]
  local moneyMeasure=window.rewardWidthMeasure
  local maxMoneyWidth,maxIcons,hasMore=32,0,false
  for _, entry in ipairs(entries) do
    if entry.heading then entry.height=HEADER_HEIGHT
    else
      local reward=readRewards(entry.info.questID)
      entry.reward=reward; entry.moneyText=formatMoney(reward.money); entry.xpText=formatXP(reward.xp)
      moneyMeasure:SetText(entry.moneyText); local moneyWidth=moneyMeasure:GetStringWidth() or 0
      moneyMeasure:SetText(entry.xpText); local xpWidth=moneyMeasure:GetStringWidth() or 0
      maxMoneyWidth=math.max(maxMoneyWidth,math.min(110,math.ceil(math.max(moneyWidth,xpWidth))+4))
      local shown=math.min(2,#reward.items)
      if shown==0 and reward.unknown then shown=1 end
      maxIcons=math.max(maxIcons,shown)
      if #reward.items>2 then hasMore=true end
    end
  end
  local iconWidth=maxIcons>0 and (maxIcons*18-2) or 0
  local rewardWidth=maxMoneyWidth+iconWidth+(hasMore and 16 or 0)+(maxIcons>0 and 3 or 0)
  local statusWidth=math.max(55,690-2-measureRow.button:GetWidth()-3-measureRow.protect:GetWidth()-5-rewardWidth-8-260)
  for _, entry in ipairs(entries) do
    if not entry.heading then
      entry.moneyWidth=maxMoneyWidth; entry.rewardWidth=rewardWidth; entry.statusWidth=statusWidth
      measureRow.status:SetWidth(entry.statusWidth)
      measureRow.status:SetHeight(0); measureRow.status:SetText(statusText(entry))
      local height=measureRow.status:GetStringHeight() or 0
      entry.height=math.min(listHeight,math.max(28,math.ceil(height)+6))
    end
  end
  local lastPageHeight,lastPageCount,start=0,0,#entries+1
  for i=#entries,1,-1 do
    local height=entries[i].height
    if lastPageCount>=#window.rows or lastPageHeight+height>listHeight then break end
    lastPageHeight=lastPageHeight+height; lastPageCount=lastPageCount+1; start=i
  end
  window.maxOffset=math.max(0,start-1); offset=math.min(offset,window.maxOffset)
  local max=call(C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept) or 20
  local count=total or #rows
  window.count:SetText(tostring(count).." / "..tostring(max)..label(" Quests", " Quests"))
  if count>=max then window.count:SetTextColor(1,0.25,0.2) elseif count>=max-2 then window.count:SetTextColor(1,0.82,0) else window.count:SetTextColor(1,1,1) end
  local sortNames={level=label("Level", "Stufe"), zone=label("Zone", "Gebiet"), progress=label("Progress", "Fortschritt"), type=label("Type", "Typ")}
  local filterNames=filterLabels()
  window.sort.caption:SetText(label("Sort: ", "Sortierung: ")..(sortNames[db.sort] or db.sort))
  for key, button in pairs(window.filterButtons) do
    button.caption:SetText(filterNames[key]); if key==db.filter then button.bg:SetColorTexture(0.39,0.27,0.10,1) else button.bg:SetColorTexture(0.16,0.12,0.08,1) end
    button.filterCount=filterCounts[key]; button:SetAlpha(filterCounts[key]==0 and 0.35 or 1)
  end
  window.lock.icon:SetTexture(ICONS .. (db.locked and "protect" or "unlock"))
  local usedHeight, full = 0, false
  for i, widget in ipairs(window.rows) do
    local row=entries[offset+i]; widget.data=row and not row.heading and row or nil
    if full then row=nil; widget.data=nil end
    local heading=row and row.heading
    widget.currentZone:SetShown(row ~= nil and row.currentZone == true)
    widget.header:SetShown(heading ~= nil); widget.headerBg:SetShown(heading ~= nil)
    widget.level:SetShown(row ~= nil and not heading); widget.text:SetShown(row ~= nil and not heading)
    widget.zone:SetShown(row ~= nil and not heading and db.sort~="zone"); widget.status:SetShown(row ~= nil and not heading)
    widget:EnableMouse(not heading)
    if heading then
      widget:UnlockHighlight()
      widget.header:SetText(heading); widget.kind:Hide(); widget.category:Hide(); widget.forever:Hide(); widget.button:Hide(); widget.protect:Hide(); widget.rewards:Hide(); widget:Show()
    elseif row then
      widget.protect:Show()
      widget.button.icon:SetTexture(ICONS.."abandon")
      widget.text:ClearAllPoints(); widget.text:SetPoint("LEFT", 70, db.sort=="zone" and 0 or 6)
      local q=row.info; local state=statusText(row)
      if row.category then widget.category:SetTexture(ICONS..row.category); widget.category:Show() else widget.category:Hide() end
      widget.forever:SetShown(isPostClassic(q.questID))
      local kind = row.kind
      widget.kindLabel = kind=="dungeon" and label("Dungeon quest", "Dungeonquest") or kind=="raid" and label("Raid quest", "Schlachtzugsquest") or kind=="group" and label("Group / elite quest", "Gruppen- / Elitequest") or kind=="pvp" and label("PvP quest", "PvP-Quest") or nil
      if kind~="solo" and kind~="unknown" then widget.kind:SetTexture(ICONS .. kind); widget.kind:Show() else widget.kind:Hide() end
      widget.level:SetText("["..tostring(q.level or "?").."]")
      local color=call(GetQuestDifficultyColor,q.level)
      if type(color)=="table" then widget.level:SetTextColor(color.r or 1,color.g or 1,color.b or 1) else widget.level:SetTextColor(1,0.82,0) end
      widget.text:SetText(tostring(q.title or "?")); widget.zone:SetText(tostring(row.zone))
      widget.status:SetWidth(row.statusWidth)
      widget.status:SetHeight(0); widget.status:SetText(state)
      widget:Show()
      local rowHeight=row.height
      if usedHeight > 0 and usedHeight + rowHeight > listHeight then
        widget.data=nil; widget:Hide(); full=true
      else
        widget:SetHeight(rowHeight); widget.status:SetHeight(rowHeight-6)
      end
      if q.isFailed then widget.status:SetTextColor(1,0.35,0.3) elseif q.isComplete then widget.status:SetTextColor(0.4,1,0.45) else widget.status:SetTextColor(0.82,0.82,0.82) end
      local dim=row.progress==0 and not q.isComplete and not q.isFailed and 0.55 or 1
      widget.level:SetAlpha(dim); widget.text:SetAlpha(dim); widget.zone:SetAlpha(dim); widget.status:SetAlpha(dim)
      if protected and protected[q.questID] then widget.protect.icon:SetVertexColor(1,0.82,0.25,1) else widget.protect.icon:SetVertexColor(0.75,0.75,0.75,0.7) end
      widget.protect.caption:SetText(protected and protected[q.questID] and label("Protected", "Geschützt") or label("Protect", "Schützen"))
      if protected and protected[q.questID] then widget.protect.bg:SetColorTexture(0.35,0.27,0.10,1) else widget.protect.bg:SetColorTexture(0.16,0.12,0.08,1) end
      if protected and protected[q.questID] then widget.button:Hide() else widget.button:Show() end
      widget.button.caption:SetText(armed==q.questID and label("Sure?", "Sicher?") or label("Abandon", "Abbrechen"))
      if not full then widget:Show() end
      if armed==q.questID then widget.button.bg:SetColorTexture(0.55,0.12,0.10,1) else widget.button.bg:SetColorTexture(0.16,0.12,0.08,1) end
      local reward=row.reward; widget.rewards:Show()
      widget.rewards:SetWidth(row.rewardWidth); widget.rewards.money:SetWidth(row.moneyWidth); widget.rewards.xp:SetWidth(row.moneyWidth)
      widget.rewards.money:SetText(row.moneyText); widget.rewards.xp:SetText(row.xpText)
      widget.rewards.more:SetText(#reward.items>2 and "+"..(#reward.items-2) or "")
      for index, item in ipairs(widget.rewards.items) do
        local info=reward.items[index]
        if not info and index==1 and reward.unknown then info={questID=q.questID} end
        item.reward=info
        if info then
          item.icon:SetTexture(info.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
          local quality=type(ITEM_QUALITY_COLORS)=="table" and ITEM_QUALITY_COLORS[info.quality]
          if type(quality)=="table" then item.border:SetColorTexture(quality.r or 0.6,quality.g or 0.6,quality.b or 0.6,1) else item.border:SetColorTexture(0.55,0.55,0.55,1) end
          item.count:SetText(type(info.count)=="number" and info.count>1 and tostring(info.count) or ""); item:Show()
        else item:Hide() end
      end
    else widget:Hide() end
    if row and not full then
      if heading then
        if usedHeight+HEADER_HEIGHT>listHeight then widget:Hide(); full=true else widget:SetHeight(HEADER_HEIGHT) end
      end
      if not full then widget:ClearAllPoints(); widget:SetPoint("TOPLEFT", 15, -67-usedHeight); usedHeight=usedHeight+widget:GetHeight() end
    end
  end
end
local function toggleWindow()
  if not window then createWindow() end
  if window:IsShown() then window:Hide() else window:Show(); render() end
end
local questLogButton, questLogAnchor
local hookedLogFrames={}
local function applyMapButtonStyle()
  if not questLogButton then return end
  local classic = not db or not db.compat or db.compat.mapbutton ~= "simple"
  questLogButton.border:SetShown(classic)
  questLogButton.icon:SetSize(classic and 18 or 24, classic and 18 or 24)
end
local function installQuestLogButton()
  if not (WorldMapFrame or QuestMapFrame) then return end
  if not questLogButton then
    local button=CreateFrame("Button",nil,UIParent)
    button:SetSize(24,24)
    button:SetFrameStrata("DIALOG"); button:SetFrameLevel(100); button:Hide()
    local icon=button:CreateTexture(nil,"ARTWORK")
    icon:SetPoint("CENTER"); icon:SetTexture(ICONS .. "medallion"); button.icon=icon
    local border=button:CreateTexture(nil,"OVERLAY")
    border:SetSize(38,38); border:SetPoint("CENTER",9,-9); border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); button.border=border
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter",function(self)
      GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:SetText(label("Open QuestPrune", "QuestPrune öffnen")); GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    button:SetScript("OnClick",function()
      GameTooltip:Hide()
      local mapFrame=questLogAnchor
      if mapFrame then
        if type(HideUIPanel)=="function" then HideUIPanel(mapFrame) else mapFrame:Hide() end
      end
      button:Hide()
      if not window then createWindow() end
      if not window:IsShown() then window:Show() end
      render()
    end)
    questLogButton=button
    applyMapButtonStyle()
  end
  local function syncButton()
    local anchor
    if WorldMapFrame and WorldMapFrame:IsVisible() then anchor=WorldMapFrame
    elseif QuestMapFrame and QuestMapFrame:IsVisible() then anchor=QuestMapFrame end
    questLogAnchor=anchor
    if anchor then
      questLogButton:ClearAllPoints(); questLogButton:SetPoint("TOPRIGHT",anchor,"TOPRIGHT",-60,0); questLogButton:Show()
    else questLogButton:Hide() end
  end
  local function hookFrame(frame)
    if frame and not hookedLogFrames[frame] then
      frame:HookScript("OnShow",syncButton); frame:HookScript("OnHide",syncButton)
      hookedLogFrames[frame]=true
    end
  end
  hookFrame(WorldMapFrame); hookFrame(QuestMapFrame)
  syncButton()
end

SLASH_QUESTPRUNE1 = "/qp"
SLASH_QUESTPRUNE2 = "/questprune"
SlashCmdList.QUESTPRUNE = function(msg)
  local cmd, key, value = (msg or ""):lower():match("^%s*(%S*)%s*(%S*)%s*(%S*)")
  if cmd == "debug" then db.debug = not db.debug; signature = nil; say("Debug: " .. tostring(db.debug), "Debug: " .. tostring(db.debug)); if db.debug then banner(); refresh() end
  elseif cmd == "dump" then dump()
  elseif cmd == "lock" then db.locked = true; say("Window locked.", "Fenster gesperrt.")
  elseif cmd == "unlock" then db.locked = false; say("Window unlocked.", "Fenster entsperrt.")
  elseif cmd == "reset" then db.pos = nil; db.sort = "level"; db.filter = "all"; db.locked = true; say("Settings reset; protection retained.", "Einstellungen zurückgesetzt; Schutz bleibt erhalten.")
  elseif cmd == "compat" then
    if key == "mapbutton" and (value == "classic" or value == "simple") then
      db.compat.mapbutton = value; applyMapButtonStyle(); out("mapbutton: " .. value)
    elseif key == "skin" and (value == "classic" or value == "plain") then
      db.compat.skin=value; applyWindowSkin(); out("skin: " .. value)
    elseif key == "rewards" and (value == "direct" or value == "selected") then
      db.compat.rewards=value; if window and window:IsShown() then render() end; out("rewards: " .. value)
    elseif key == "coins" and (value == "native" or value == "text") then
      db.compat.coins=value; if window and window:IsShown() then render() end; out("coins: " .. value)
    elseif key == "" then
      out("mapbutton: " .. (db.compat.mapbutton or "classic") .. " (/qp compat mapbutton classic|simple)")
      out("skin: " .. (db.compat.skin or "classic") .. " (/qp compat skin classic|plain)")
      out("rewards: " .. (db.compat.rewards or "direct") .. " (/qp compat rewards direct|selected)")
      out("coins: " .. (db.compat.coins or "native") .. " (/qp compat coins native|text)")
    else out("/qp compat mapbutton classic|simple  |  skin classic|plain  |  rewards direct|selected  |  coins native|text") end
  elseif cmd == "help" then out("/qp dump | debug | lock | unlock | reset | compat | help")
  else toggleWindow() end
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("QUEST_REMOVED")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:SetScript("OnEvent", function(_, event, name, questID)
  if event == "ADDON_LOADED" and name == ADDON then
    QuestPruneForeverDB = type(QuestPruneForeverDB) == "table" and QuestPruneForeverDB or {}
    db = QuestPruneForeverDB
    if db.locked == nil then db.locked = true end
    if db.debug == nil then db.debug = false end
    db.version = 1; db.sort = db.sort or "level"; db.filter = db.filter or "all"; db.compat = db.compat or {}; db.chars = db.chars or {}
  elseif event == "ADDON_LOADED" and db then
    installQuestLogButton()
  elseif event == "PLAYER_LOGIN" and db then
    local name, realm = UnitName("player"), GetRealmName()
    if name and realm then
      local key = realm .. "-" .. name
      db.chars[key] = db.chars[key] or { protected = {} }
      db.chars[key].protected = db.chars[key].protected or {}
      character = db.chars[key]; character.accepted=character.accepted or {}; character.abandoned=character.abandoned or {}
      protected = character.protected
    else say("Character identity unavailable; quest protection and abandonment disabled.", "Charakter nicht erkannt; Questschutz und Abbrechen deaktiviert.") end
    installQuestLogButton()
    if db.debug then banner(); refresh() end
  elseif event == "QUEST_DETAIL" and character then
    recordOffer()
  elseif event == "QUEST_ACCEPTED" and character then
    local id=type(questID)=="number" and questID or (offeredQuest and offeredQuest.id)
    if id and id>0 then
      if offeredQuest and offeredQuest.id==id then
        character.accepted[id]=offeredQuest
      else
        character.accepted[id]={id=id, title=call(C_QuestLog and C_QuestLog.GetTitleForQuestID,id)}
      end
      character.abandoned[id]=nil; offeredQuest=nil
      if window and window:IsShown() then render() end
    end
  elseif (event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN") and db then
    if protected and type(name) == "number" then protected[name] = nil end
    if character and type(name)=="number" then
      if event=="QUEST_REMOVED" and pendingAbandon and pendingAbandon.id==name then
        local saved=character.accepted[name] or {id=name}
        saved.title=saved.title or pendingAbandon.title; saved.zone=saved.zone or pendingAbandon.zone
        character.abandoned[name]=saved; pendingAbandon=nil
      elseif event=="QUEST_TURNED_IN" then
        character.accepted[name]=nil; character.abandoned[name]=nil
        if pendingAbandon and pendingAbandon.id==name then pendingAbandon=nil end
      end
    end
    if armed == name then armed=nil; armToken=armToken+1 end
    if window and window:IsShown() then render() end
  elseif (event == "QUEST_LOG_UPDATE" or event == "PLAYER_LEVEL_UP" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "QUEST_DATA_LOAD_RESULT" or event == "GET_ITEM_INFO_RECEIVED") and db and (db.debug or (window and window:IsShown())) then
    if not frame.pending then frame.pending = true; C_Timer.After(0.1, function() frame.pending = false; if window and window:IsShown() then render() else refresh() end end) end
  end
end)
