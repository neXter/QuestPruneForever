local ADDON = ...
local VERSION = "0.2.0"
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
local armed, armToken = nil, 0
local protected
local sorts = {"level", "zone", "progress"}
local filters = {"all", "lowvalue", "untouched", "group", "complete"}
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
local function abandon(row)
  local q = row.info
  if not q.questID or not protected or protected[q.questID] then return end
  -- Re-read the quest before deciding whether it can be abandoned immediately.
  local current = snapshot()
  local found
  for _, entry in ipairs(current) do if entry.info.questID == q.questID then found = entry; break end end
  if not found then say("Quest no longer in log.", "Quest nicht mehr im Log."); render(); return end
  local state = found.info
  local oneClick = state.isFailed or (not state.isComplete and progress(found) == 0)
  local shift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
  if not oneClick and not shift and armed ~= q.questID then
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
  local success, err = pcall(function() api.SetSelectedQuest(q.questID); api.SetAbandonQuest(); api.AbandonQuest() end)
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
local function createWindow()
  window = CreateFrame("Frame", "QuestPruneForeverFrame", UIParent, "BackdropTemplate")
  window:Hide()
  window:SetFrameStrata("DIALOG")
  window:SetSize(720, 660); window:SetPoint("CENTER"); window:SetClampedToScreen(true); window:SetMovable(true)
  window:EnableMouse(true); window:RegisterForDrag("LeftButton")
  if window.SetDontSavePosition then window:SetDontSavePosition(true) end
  window:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=14, insets={left=3,right=3,top=3,bottom=3}})
  window:SetBackdropColor(0.075, 0.055, 0.04, 1)
  window:SetBackdropBorderColor(0.72, 0.60, 0.40, 1)
  local bar = window:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT", 5, -5); bar:SetPoint("TOPRIGHT", -5, -5); bar:SetHeight(27); bar:SetColorTexture(0.19, 0.12, 0.065, 1)
  local rule = window:CreateTexture(nil, "ARTWORK")
  rule:SetPoint("TOPLEFT", 12, -64); rule:SetPoint("TOPRIGHT", -12, -64); rule:SetHeight(1); rule:SetColorTexture(0.49, 0.37, 0.20, 0.8)
  if db.pos then window:ClearAllPoints(); window:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4]) end
  window:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
  window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, r, x, y = self:GetPoint(); db.pos={p,r,x,y} end)
  tinsert(UISpecialFrames, "QuestPruneForeverFrame")
  local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 16, -12); title:SetText("QuestPrune")
  window.count = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  window.count:SetPoint("LEFT", title, "RIGHT", 20, 0)
  local close = CreateFrame("Button", nil, window, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -2, -2)
  local lock = iconButton(window, "protect"); lock:SetPoint("TOPRIGHT", -36, -7)
  lock:SetScript("OnClick", function() db.locked = not db.locked; render() end); window.lock = lock
  lock:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(db.locked and label("Unlock window", "Fenster entsperren") or label("Lock window", "Fenster sperren")); GameTooltip:Show() end)
  lock:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local sort = flatButton(window, 160, 22); sort:SetPoint("TOPLEFT", 12, -38)
  sort:SetScript("OnClick", function() db.sort=cycle(sorts, db.sort); offset=0; render() end); window.sort=sort
  local filter = flatButton(window, 50, 22); filter:SetPoint("LEFT", sort, "RIGHT", 8, 0)
  filter:SetScript("OnClick", function() db.filter="all"; offset=0; render() end); window.filterButtons={all=filter}
  window.rows={}
  for i=1,20 do
    local row=CreateFrame("Button", nil, window); row:SetSize(690, 28); row:SetPoint("TOPLEFT", 15, -67-(i-1)*28)
    row.headerBg=row:CreateTexture(nil,"BACKGROUND"); row.headerBg:SetPoint("BOTTOMLEFT", 4, 0); row.headerBg:SetPoint("BOTTOMRIGHT", -4, 0); row.headerBg:SetHeight(1); row.headerBg:SetColorTexture(0.55,0.42,0.25,0.35)
    row.header=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); row.header:SetPoint("LEFT", 8, 0); row.header:SetTextColor(0.72,0.62,0.44)
    if i % 2 == 0 then local stripe=row:CreateTexture(nil,"BACKGROUND"); stripe:SetAllPoints(); stripe:SetColorTexture(0.8,0.57,0.27,0.045) end
    row.level=row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.level:SetPoint("LEFT", 2, 0); row.level:SetWidth(42); row.level:SetJustifyH("LEFT")
    row.kind=row:CreateTexture(nil, "ARTWORK"); row.kind:SetSize(17,17); row.kind:SetPoint("LEFT", 42, 0)
    row.text=row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.text:SetPoint("LEFT", 64, 6); row.text:SetWidth(219); row.text:SetJustifyH("LEFT"); row.text:SetWordWrap(false)
    row.zone=row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); row.zone:SetPoint("LEFT", 64, -7); row.zone:SetWidth(219); row.zone:SetJustifyH("LEFT"); row.zone:SetWordWrap(false)
    row.status=row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.status:SetPoint("TOPLEFT", 290, -3); row.status:SetWidth(170); row.status:SetJustifyH("LEFT"); row.status:SetJustifyV("TOP"); row.status:SetWordWrap(true)
    row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row:SetScript("OnClick", function(self)
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
      GameTooltip:AddLine(self.data.zone or "", 0.7, 0.7, 0.7)
      if self.kindLabel then GameTooltip:AddLine(self.kindLabel, 1, 0.82, 0) end
      for _, objective in ipairs(self.data.objectives) do
        GameTooltip:AddLine(objective.text or "?", objective.finished and 0.3 or 1, 1, objective.finished and 0.3 or 1, true)
      end
      GameTooltip:AddLine(label("Click to open quest details", "Klicken für Questdetails"), 0.5, 0.8, 1, true)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.button=iconButton(row, "abandon"); row.button:SetPoint("RIGHT", -2, 0)
    row.button:SetWidth(105); row.button.icon:ClearAllPoints(); row.button.icon:SetPoint("LEFT", 4, 0)
    row.button.caption=row.button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.button.caption:SetPoint("LEFT", row.button.icon, "RIGHT", 2, 0); row.button.caption:SetPoint("RIGHT", -3, 0); row.button.caption:SetJustifyH("CENTER")
    row.button:SetScript("OnClick", function() if row.data then abandon(row.data) end end)
    buttonTip(row.button, row, function() return armed == (row.data and row.data.info.questID) and label("Click again to confirm", "Zum Bestätigen erneut klicken") or label("Abandon quest (Shift-click: immediate)", "Quest abbrechen (Shift-Klick: sofort)") end)
    row.protect=iconButton(row, "protect"); row.protect:SetPoint("RIGHT", row.button, "LEFT", -3, 0)
    row.protect:SetWidth(105); row.protect.icon:ClearAllPoints(); row.protect.icon:SetPoint("LEFT", 4, 0)
    row.protect.caption=row.protect:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.protect.caption:SetPoint("LEFT", row.protect.icon, "RIGHT", 2, 0); row.protect.caption:SetPoint("RIGHT", -3, 0); row.protect.caption:SetJustifyH("CENTER")
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
  local widths={lowvalue=88, untouched=44, group=124, complete=110}
  for _, key in ipairs({"lowvalue", "untouched", "group", "complete"}) do
    local selected=key
    local button=flatButton(window,widths[key],22); button:SetPoint("LEFT",previous,"RIGHT",3,0)
    button:SetScript("OnClick",function() db.filter=selected; offset=0; render() end)
    window.filterButtons[key]=button; previous=button
  end
  local hint=window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); hint:SetPoint("BOTTOMLEFT", 16, 10); hint:SetText(label("Click: details. Wheel: scroll. Shift-click Abandon: immediate.", "Klick: Details. Mausrad: scrollen. Shift-Klick auf Abbrechen: sofort."))
  window:EnableMouseWheel(true); window:SetScript("OnMouseWheel", function(_, delta) offset=math.max(0, math.min(window.maxOffset or 0, offset-delta)); render() end)
  window:SetScript("OnHide", function() armed=nil; armToken=armToken+1 end)
end
render = function()
  if not window then return end
  local rows, _, total=refresh(); local filtered={}
  for _, row in ipairs(rows) do
    local q=row.info; local p=progress(row); local tag=call(C_QuestLog and C_QuestLog.GetQuestTagInfo, q.questID)
    local tagID=type(tag)=="table" and tag.tagID
    local color=call(GetQuestDifficultyColor, q.level)
    local low=type(color)=="table" and ((color.g or 0) > (color.r or 0) or (math.abs((color.r or 0)-(color.g or 0)) < 0.05 and math.abs((color.g or 0)-(color.b or 0)) < 0.05)) or false
    local match=db.filter=="all" or (db.filter=="untouched" and p==0 and not q.isComplete and not q.isFailed) or (db.filter=="complete" and q.isComplete) or (db.filter=="group" and (tagID==1 or tagID==81 or (q.suggestedGroup or 0)>0)) or (db.filter=="lowvalue" and low)
    if match then
      row.progress=p
      if db.sort=="zone" then row.groupKey=row.zone ~= "" and row.zone or label("Unknown zone", "Unbekanntes Gebiet")
      elseif db.sort=="progress" then row.groupKey=statusGroup(row)
      else row.groupKey=difficultyGroup(q.level) end
      filtered[#filtered+1]=row
    end
  end
  table.sort(filtered, function(a,b)
    local av,bv
    av,bv=a.groupKey,b.groupKey
    if av~=bv then return av<bv end
    if db.sort=="progress" and a.progress ~= b.progress then return (a.progress or -1)<(b.progress or -1) end
    if db.sort~="progress" and (a.info.level or 0)~=(b.info.level or 0) then return (a.info.level or 0)<(b.info.level or 0) end
    return (a.info.title or "")<(b.info.title or "")
  end)
  local entries, lastGroup={}, nil
  local difficultyNames={label("Grey", "Grau"),label("Green", "Grün"),label("Yellow", "Gelb"),label("Orange", "Orange"),label("Red", "Rot"),label("Unknown difficulty", "Unbekannte Schwierigkeit")}
  local statusNames={label("Untouched", "Unberührt"),label("In progress", "In Arbeit"),label("Unknown progress", "Fortschritt unbekannt"),label("Ready to turn in", "Abgabebereit"),label("Failed", "Fehlgeschlagen")}
  for _, row in ipairs(filtered) do
    if row.groupKey~=lastGroup then
      local title = db.sort=="zone" and row.groupKey or (db.sort=="progress" and statusNames[row.groupKey] or difficultyNames[row.groupKey])
      entries[#entries+1]={heading=title}; lastGroup=row.groupKey
    end
    entries[#entries+1]=row
  end
  window.maxOffset=math.max(0,#entries-1); offset=math.min(offset,window.maxOffset)
  local max=call(C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept) or 20
  local count=total or #rows
  window.count:SetText(tostring(count).." / "..tostring(max)..label(" Quests", " Quests"))
  if count>=max then window.count:SetTextColor(1,0.25,0.2) elseif count>=max-2 then window.count:SetTextColor(1,0.82,0) else window.count:SetTextColor(1,1,1) end
  local sortNames={level=label("Level", "Stufe"), zone=label("Zone", "Gebiet"), progress=label("Progress", "Fortschritt")}
  local filterNames={all=label("All", "Alle"), lowvalue=label("Grey / Green", "Grau / Grün"), untouched="0 %", group=label("Group / Dungeon", "Gruppe / Dungeon"), complete=label("Ready to turn in", "Abgabebereit")}
  window.sort:SetText(label("Sort: ", "Sortierung: ")..(sortNames[db.sort] or db.sort))
  for key, button in pairs(window.filterButtons) do
    button:SetText(filterNames[key]); if key==db.filter then button.bg:SetColorTexture(0.39,0.27,0.10,1) else button.bg:SetColorTexture(0.16,0.12,0.08,1) end
  end
  window.lock.icon:SetTexture(ICONS .. (db.locked and "protect" or "unlock"))
  local usedHeight, listHeight, full = 0, 560, false
  for i, widget in ipairs(window.rows) do
    local row=entries[offset+i]; widget.data=row and not row.heading and row or nil
    if full then row=nil; widget.data=nil end
    local heading=row and row.heading
    widget.header:SetShown(heading ~= nil); widget.headerBg:SetShown(heading ~= nil)
    widget.level:SetShown(row ~= nil and not heading); widget.text:SetShown(row ~= nil and not heading)
    widget.zone:SetShown(row ~= nil and not heading and db.sort~="zone"); widget.status:SetShown(row ~= nil and not heading)
    widget:EnableMouse(not heading)
    if heading then
      widget:UnlockHighlight()
      widget.header:SetText(heading); widget.kind:Hide(); widget.button:Hide(); widget.protect:Hide(); widget:Show()
    elseif row then
      widget.protect:Show()
      widget.text:ClearAllPoints(); widget.text:SetPoint("LEFT", 64, db.sort=="zone" and 0 or 6)
      local q=row.info; local state=q.isFailed and label("Failed", "Fehlgeschlagen") or (q.isComplete and label("Complete", "Fertig") or (row.progress and math.floor(row.progress*100).."%" or "?"))
      local tag=call(C_QuestLog and C_QuestLog.GetQuestTagInfo,q.questID)
      local tagID=type(tag)=="table" and tag.tagID
      local kind = tagID==81 and "dungeon" or tagID==41 and "pvp" or (tagID==1 or (q.suggestedGroup or 0)>0) and "group" or nil
      widget.kindLabel = kind=="dungeon" and label("Dungeon quest", "Dungeonquest") or kind=="group" and label("Group / elite quest", "Gruppen- / Elitequest") or kind=="pvp" and label("PvP quest", "PvP-Quest") or nil
      if kind then widget.kind:SetTexture(ICONS .. kind); widget.kind:Show() else widget.kind:Hide() end
      widget.level:SetText("["..tostring(q.level or "?").."]")
      local color=call(GetQuestDifficultyColor,q.level)
      if type(color)=="table" then widget.level:SetTextColor(color.r or 1,color.g or 1,color.b or 1) else widget.level:SetTextColor(1,0.82,0) end
      widget.text:SetText(tostring(q.title or "?")); widget.zone:SetText(tostring(row.zone))
      local open={}; for _, objective in ipairs(row.objectives) do if not objective.finished and objective.text then open[#open+1]=objective.text end end
      if not q.isFailed and not q.isComplete and #open>0 then state=table.concat(open, "\n") end
      widget.status:SetHeight(0); widget.status:SetText(state)
      widget:Show()
      local textHeight=widget.status:GetStringHeight() or 0
      local rowHeight=math.min(listHeight, math.max(28, math.ceil(textHeight)+6))
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
    else widget:Hide() end
    if row and not full then
      if heading then
        if usedHeight+20>listHeight then widget:Hide(); full=true else widget:SetHeight(20) end
      end
      if not full then widget:ClearAllPoints(); widget:SetPoint("TOPLEFT", 15, -67-usedHeight); usedHeight=usedHeight+widget:GetHeight() end
    end
  end
  if offset==0 and not full and #entries<=#window.rows then window.maxOffset=0 end
end
local function toggleWindow()
  if not window then createWindow() end
  if window:IsShown() then window:Hide() else window:Show(); render() end
end

SLASH_QUESTPRUNE1 = "/qp"
SLASH_QUESTPRUNE2 = "/questprune"
SlashCmdList.QUESTPRUNE = function(msg)
  local cmd = (msg or ""):lower():match("^%s*(%S*)")
  if cmd == "debug" then db.debug = not db.debug; signature = nil; say("Debug: " .. tostring(db.debug), "Debug: " .. tostring(db.debug)); if db.debug then banner(); refresh() end
  elseif cmd == "dump" then dump()
  elseif cmd == "lock" then db.locked = true; say("Window locked.", "Fenster gesperrt.")
  elseif cmd == "unlock" then db.locked = false; say("Window unlocked.", "Fenster entsperrt.")
  elseif cmd == "reset" then db.pos = nil; db.sort = "level"; db.filter = "all"; db.locked = true; say("Settings reset; protection retained.", "Einstellungen zurückgesetzt; Schutz bleibt erhalten.")
  elseif cmd == "compat" then say("Compatibility switches arrive with the UI.", "Kompatibilitätsschalter folgen mit der Oberfläche.")
  elseif cmd == "help" then out("/qp dump | debug | lock | unlock | reset | compat | help")
  else toggleWindow() end
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("QUEST_REMOVED")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == ADDON then
    QuestPruneForeverDB = type(QuestPruneForeverDB) == "table" and QuestPruneForeverDB or {}
    db = QuestPruneForeverDB
    if db.locked == nil then db.locked = true end
    if db.debug == nil then db.debug = false end
    db.version = 1; db.sort = db.sort or "level"; db.filter = db.filter or "all"; db.compat = db.compat or {}; db.chars = db.chars or {}
  elseif event == "PLAYER_LOGIN" and db then
    local name, realm = UnitName("player"), GetRealmName()
    if name and realm then
      local key = realm .. "-" .. name
      db.chars[key] = db.chars[key] or { protected = {} }
      db.chars[key].protected = db.chars[key].protected or {}
      protected = db.chars[key].protected
    else say("Character identity unavailable; quest protection and abandonment disabled.", "Charakter nicht erkannt; Questschutz und Abbrechen deaktiviert.") end
    if db.debug then banner(); refresh() end
  elseif (event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN") and db then
    if protected and type(name) == "number" then protected[name] = nil end
    if armed == name then armed=nil; armToken=armToken+1 end
    if window and window:IsShown() then render() end
  elseif (event == "QUEST_LOG_UPDATE" or event == "PLAYER_LEVEL_UP") and db and (db.debug or (window and window:IsShown())) then
    if not frame.pending then frame.pending = true; C_Timer.After(0.1, function() frame.pending = false; if window and window:IsShown() then render() else refresh() end end) end
  end
end)
