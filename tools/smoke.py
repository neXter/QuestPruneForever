"""Test the current diagnostic add-on without the game: python tools/smoke.py.

Requires lupa: python -m pip install --user lupa
"""
from pathlib import Path
import sys

try:
    from lupa import LuaRuntime
except ImportError:
    sys.exit("Install lupa first: python -m pip install --user lupa")

ROOT = Path(__file__).resolve().parent.parent
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PRELUDE = r'''
chat, timers = {}, {}
print = function(s) chat[#chat + 1] = s end
GetLocale = function() return "enUS" end
UnitName = function(unit) return unit=="npc" and "Quest Giver" or "Tester" end
GetRealmName = function() return "Realm" end
shift = false; IsShiftKeyDown = function() return shift end
have = 1; noObjectives = false; failed = false
GetBuildInfo = function() return "test", "123" end
SlashCmdList = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
C_QuestLog = {
  GetNumQuestLogEntries = function() return 3, 1 end,
  GetInfo = function(i)
    if i == 1 then return {isHeader=true, title="Test Zone"} end
    if i == 2 then return {questID=42, title="Test Quest", level=5, isFailed=failed} end
    return {questID=99, title="Hidden", isHidden=true}
  end,
  GetQuestObjectives = function() if noObjectives then return {} end return {{text="Collect", numFulfilled=have, numRequired=2}} end,
}
UIParent = {}; UISpecialFrames = {}; tinsert = table.insert
GameTooltip = setmetatable({}, {__index=function() return function() end end})
frames = {}
CreateFrame = function(kind, name, parent)
  local f = {shown=true, scripts={}, hooks={}, children={}}
  setmetatable(f, {__index=function(_, key) if key == "pending" then return nil end return function() end end})
  function f:RegisterEvent() end
  function f:SetBackdrop(value) self.backdrop=value end
  function f:SetScript(key, fn) self.scripts[key]=fn; if key == "OnEvent" then self.handler=fn; frame=self end end
  function f:HookScript(key, fn) self.hooks[key]=fn end
  function f:CreateFontString() local t={}; function t:SetText(s) self.text=s end; function t:GetStringWidth() return #(self.text or "")*6 end; function t:GetStringHeight() local _,n=(self.text or ""):gsub("\n", ""); return (n+1)*12 end; setmetatable(t,{__index=function() return function() end end}); return t end
  function f:CreateTexture() local t={}; function t:SetTexture(path) self.texture=path end; function t:SetColorTexture(r,g,b,a) self.color={r,g,b,a} end; function t:SetShown(shown) self.shown=shown end; setmetatable(t,{__index=function() return function() end end}); return t end
  function f:IsShown() return self.shown end
  function f:IsVisible() return self.shown end
  function f:SetHeight(h) self.height=h end
  function f:GetHeight() return self.height or 28 end
  function f:SetAlpha(a) self.alpha=a end
  function f:SetWidth(w) self.width=w end
  function f:GetWidth() return self.width or 24 end
  function f:SetPoint(...) self.point={...} end
  function f:LockHighlight() self.highlightLocked=true end
  function f:UnlockHighlight() self.highlightLocked=false end
  function f:Show() local changed=not self.shown; self.shown=true; if changed and self.hooks.OnShow then self.hooks.OnShow(self) end end
  function f:Hide() local changed=self.shown; self.shown=false; if changed and self.hooks.OnHide then self.hooks.OnHide(self) end end
  function f:SetShown(shown) self.shown=shown end
  function f:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
  frames[#frames+1]=f
  return f
end
function event(name, arg, second) frame.handler(frame, name, arg, second) end
function command(s) SlashCmdList.QUESTPRUNE(s) end
function flush() local pending = timers; timers = {}; for _, fn in ipairs(pending) do fn() end end
'''


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    source = (ROOT / "QuestPruneForever.lua").read_text(encoding="utf-8-sig")
    compile_lua = lua.eval("function(s) local f, err = load(s); if not f then error(err) end; return f end")
    lua.execute(PRELUDE)
    compile_lua(source)("QuestPruneForever")
    lua.execute('event("ADDON_LOADED", "QuestPruneForever"); event("PLAYER_LOGIN")')
    assert lua.eval("QuestPruneForeverDB.debug == false and QuestPruneForeverDB.locked == true")
    lua.execute('command("dump")')
    output = "\n".join(lua.globals().chat.values())
    assert "id=42" in output and "Test Zone" in output and "Collect" in output
    assert "id=99" not in output and "max=20 (fallback)" in output
    lua.execute('command("debug"); event("QUEST_LOG_UPDATE"); event("QUEST_LOG_UPDATE")')
    assert lua.eval("#timers") == 1, "Quest updates should be debounced"
    lua.execute('flush(); command("unlock"); command("reset")')
    assert lua.eval("QuestPruneForeverDB.locked == true")
    lua.execute('''
      selected=7; abandoned=0
      C_QuestLog.GetSelectedQuest=function() return selected end
      C_QuestLog.SetSelectedQuest=function(id) selected=id end
      C_QuestLog.SetAbandonQuest=function() assert(selected==42) end
      C_QuestLog.AbandonQuest=function() abandoned=abandoned+1 end
      GetQuestID=function() return 42 end
      GetTitleText=function() return "Test Quest" end
      C_Map={GetBestMapForUnit=function() return 12 end, GetMapInfo=function() return {name="Test Map"} end,
        GetPlayerMapPosition=function() return {GetXY=function() return .25,.75 end} end}
      event("QUEST_DETAIL"); event("QUEST_ACCEPTED",1,42)
      assert(QuestPruneForeverDB.chars["Realm-Tester"].accepted[42].giver=="Quest Giver")
      command("")
      frames[93].scripts.OnClick(); assert(QuestPruneForeverDB.filter=="group")
      frames[93].scripts.OnClick(); assert(QuestPruneForeverDB.filter=="all")
      frames[93].scripts.OnClick(); frames[94].scripts.OnClick(); assert(QuestPruneForeverDB.filter=="dungeon")
      frames[6].scripts.OnClick(); assert(QuestPruneForeverDB.filter=="all")
      assert(frames[2].opaque.color[4]==1 and frames[2].titleBar.texture:match("titlebar$"))
      assert(frames[2].backdrop.edgeFile:match("UI%-DialogBox%-Border$"))
      command("compat skin plain"); assert(frames[2].backdrop.edgeFile:match("UI%-Tooltip%-Border$"))
      command("compat skin classic"); assert(frames[2].backdrop.edgeFile:match("UI%-DialogBox%-Border$"))
      assert(frames[91]:GetWidth()==28)
      assert(frames[101]:GetWidth()==#"Active"*6+30 and frames[102]:GetWidth()==#"Abandoned"*6+30)
      for _, f in ipairs(frames) do if f.scripts.OnClick then testbutton=f end end
      -- The first row button follows the title buttons in the frame list.
      testbutton=frames[11]
      local questrow=frames[10]
      assert(testbutton:GetWidth()==74 and frames[12]:GetWidth()==80)
      opened=nil
      QuestMapFrame_OpenToQuestDetails=function(id) opened=id end
      questrow.scripts.OnClick(questrow)
      assert(opened==42 and not frames[2]:IsShown())
      command("")
      testbutton.scripts.OnClick()
      assert(abandoned==0)
      testbutton.scripts.OnClick()
      assert(abandoned==1 and selected==7)
      event("QUEST_REMOVED",42)
      local saved=QuestPruneForeverDB.chars["Realm-Tester"].abandoned[42]
      assert(saved and saved.map=="Test Map" and saved.x==.25 and saved.y==.75)
      frames[102].scripts.OnClick()
      assert(frames[7].data.info.title=="Test Quest" and frames[7].status.text=="Test Map  25.0, 75.0")
      C_Map.SetUserWaypoint=function(point) waypoint=point end
      UiMapPoint={CreateFromCoordinates=function(map,x,y) return {map=map,x=x,y=y} end}
      C_SuperTrack={SetSuperTrackedUserWaypoint=function(v) tracked=v end}
      frames[8].scripts.OnClick()
      assert(waypoint.map==12 and waypoint.x==.25 and waypoint.y==.75 and tracked)
      C_Map.CanSetUserWaypointOnMap=function() return false end
      TomTom={AddWaypoint=function(_,map,x,y) tomtom={map=map,x=x,y=y}; return 1 end}
      frames[8].scripts.OnClick()
      assert(tomtom.map==12 and tomtom.x==.25 and tomtom.y==.75)
      local oldWaypoint=waypoint
      saved.x=nil; frames[102].scripts.OnClick(); assert(not frames[8]:IsShown())
      frames[7].scripts.OnClick(frames[7]); assert(waypoint==oldWaypoint)
      saved.x=.25
      frames[101].scripts.OnClick()
      event("QUEST_DETAIL"); event("QUEST_ACCEPTED",1,42)
      assert(not QuestPruneForeverDB.chars["Realm-Tester"].abandoned[42])
      local protect=frames[12]
      for _, button in ipairs({testbutton, protect}) do
        button.scripts.OnEnter(button)
        assert(questrow.highlightLocked)
        button.scripts.OnLeave(button)
        assert(not questrow.highlightLocked)
      end
      protect.scripts.OnClick()
      assert(QuestPruneForeverDB.chars["Realm-Tester"].protected[42])
      testbutton.scripts.OnClick(); testbutton.scripts.OnClick()
      assert(abandoned==1)
      protect.scripts.OnClick()
      have=0; testbutton.scripts.OnClick()
      assert(abandoned==1)
      testbutton.scripts.OnClick(); assert(abandoned==2)
      noObjectives=true; testbutton.scripts.OnClick()
      assert(abandoned==2)
      flush(); shift=true; testbutton.scripts.OnClick()
      assert(abandoned==2)
      testbutton.scripts.OnClick(); shift=false
      assert(abandoned==3)
      failed=true; testbutton.scripts.OnClick(); assert(abandoned==3)
      testbutton.scripts.OnClick(); failed=false
      assert(abandoned==4)
      protect.scripts.OnClick(); event("QUEST_REMOVED",42)
      assert(not QuestPruneForeverDB.chars["Realm-Tester"].protected[42])
      C_QuestLog.GetNumQuestLogEntries=function() return 4, 2 end
      C_QuestLog.GetInfo=function(i)
        if i==1 then return {isHeader=true,title="Alpha"} end
        if i==2 then return {questID=42,title="First",level=5} end
        if i==3 then return {isHeader=true,title="Beta"} end
        return {questID=43,title="Second",level=10,isComplete=true}
      end
      GetQuestDifficultyColor=function(level) if level==5 then return {r=.5,g=.5,b=.5} end return {r=1,g=1,b=0} end
      currentZone="Alpha"; GetRealZoneText=function() return currentZone end
      Enum={QuestTag={Raid=62}}
      C_QuestLog.GetQuestTagInfo=function(id) if id==43 then return {tagID=62} end end
      QuestPruneForeverDB.sort="zone"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[7].header.text=="Alpha (Current zone)" and frames[10].data.info.questID==42)
      assert(frames[13].header.text=="Beta" and frames[16].data.info.questID==43)
      assert(frames[16].kind.texture:match("raid$"))
      assert(frames[7].currentZone.shown and frames[10].currentZone.shown and not frames[13].currentZone.shown)
      currentZone="Beta"; event("ZONE_CHANGED_NEW_AREA"); flush()
      assert(frames[7].header.text=="Beta (Current zone)" and frames[7].currentZone.shown and frames[10].currentZone.shown)
      assert(frames[13].header.text=="Alpha" and not frames[13].currentZone.shown)
      currentZone="Alpha"; event("ZONE_CHANGED_NEW_AREA"); flush()
      QuestPruneForeverDB.sort="level"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[7].header.text=="Grey" and frames[13].header.text=="Yellow")
      QuestPruneForeverDB.sort="progress"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[7].header.text=="Unknown progress" and frames[13].header.text=="Ready to turn in")
      QuestPruneForeverDB.sort="type"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[7].header.text=="Solo" and frames[10].data.info.questID==42)
      assert(frames[13].header.text=="Raid" and frames[16].data.info.questID==43)
      C_QuestLog.GetQuestObjectives=function(id)
        if id==42 then return {{text="First",numFulfilled=0,numRequired=1}, {text="Second",numFulfilled=0,numRequired=1}, {text="Third",numFulfilled=0,numRequired=1}, {text="Fourth",numFulfilled=0,numRequired=1}} end
        return {}
      end
      QuestPruneForeverDB.sort="zone"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[10].status.text=="First\\nSecond\\nThird\\nFourth")
      assert(frames[10]:GetHeight()==54 and frames[13].point[3]==-141)
      QuestPruneForeverDB.chars["Realm-Tester"].abandoned[42]=nil
      C_QuestLog.AbandonQuest=function() error("blocked") end
      shift=true; frames[11].scripts.OnClick(); frames[11].scripts.OnClick(); shift=false
      event("QUEST_REMOVED",42)
      assert(not QuestPruneForeverDB.chars["Realm-Tester"].abandoned[42])
      C_QuestLog.GetNumQuestLogEntries=function() return 6,5 end
      C_QuestLog.GetInfo=function(i) if i==1 then return {isHeader=true,title="Test"} end return {questID=100+i,title="Quest "..i,level=i} end
      C_QuestLog.GetQuestTagInfo=function(id) local ids={[103]=1,[104]=81,[105]=62,[106]=41}; if ids[id] then return {tagID=ids[id]} end end
      QuestPruneForeverDB.sort="type"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[7].header.text=="Solo" and frames[13].header.text=="Group / Elite" and frames[19].header.text=="Dungeon")
      assert(frames[25].header.text=="Raid" and frames[31].header.text=="PvP")
      QuestPruneForeverDB.filter="group"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[7].header.text=="Group / Elite" and frames[10].data.info.questID==103 and not frames[13]:IsShown())
      QuestPruneForeverDB.filter="dungeon"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[7].header.text=="Dungeon" and frames[10].data.info.questID==104 and not frames[13]:IsShown())
      QuestPruneForeverDB.filter="raid"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[7].header.text=="Raid" and frames[10].data.info.questID==105)
      QuestPruneForeverDB.filter="pvp"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[7].header.text=="PvP" and frames[10].data.info.questID==106)
      assert(frames[95].alpha==1 and frames[96].alpha==1)
      C_QuestLog.GetNumQuestLogEntries=function() return 2,1 end
      QuestPruneForeverDB.filter="all"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[95].alpha==0.35 and frames[96].alpha==0.35)
      C_QuestLog.GetNumQuestLogEntries=function() return 31,30 end
      C_QuestLog.GetInfo=function(i) if i==1 then return {isHeader=true,title="Test"} end return {questID=100+i,title=("Quest %02d"):format(i),level=5} end
      C_QuestLog.GetQuestObjectives=function(id) if id==131 then return {{text="One"},{text="Two"},{text="Three"}} end return {{text="One"}} end
      QuestPruneForeverDB.sort="level"; event("QUEST_LOG_UPDATE"); flush()
      frames[2].scripts.OnMouseWheel(frames[2],-100)
      assert(frames[7].data.info.questID==113 and frames[61].data.info.questID==131 and not frames[64]:IsShown())
      WorldMapFrame=CreateFrame("Frame"); QuestMapFrame=CreateFrame("Frame"); QuestMapFrame:Hide()
      HideUIPanel=function(panel) panel:Hide() end
      event("ADDON_LOADED","Blizzard_QuestMap")
      local logButton=frames[#frames]
      assert(logButton.point[5]==0 and logButton.border.shown)
      command("compat mapbutton simple"); assert(not logButton.border.shown)
      command("compat mapbutton classic"); assert(logButton.border.shown)
      frames[2]:Hide(); WorldMapFrame:Show(); logButton.scripts.OnClick()
      assert(not WorldMapFrame:IsShown() and frames[2]:IsShown() and not logButton:IsShown())
      WorldMapFrame:Show(); logButton.scripts.OnClick()
      assert(not WorldMapFrame:IsShown() and frames[2]:IsShown())
      WorldMapFrame:Show(); assert(logButton:IsShown())
      WorldMapFrame:Hide(); assert(not logButton:IsShown())
      C_QuestLog.GetNumQuestLogEntries=function() return 4,3 end
      C_QuestLog.GetInfo=function(i) if i==1 then return {isHeader=true,title="Test"} end local ids={9665,9666,95041}; return {questID=ids[i-1],title=("Quest %d"):format(ids[i-1]),level=5} end
      QuestPruneForeverDB.sort="level"; QuestPruneForeverDB.filter="postclassic"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[10].data.info.questID==95041 and frames[13].data.info.questID==9666 and not frames[16]:IsShown())
      C_QuestLog.GetNumQuestLogEntries=function() return 6,3 end
      C_QuestLog.GetInfo=function(i)
        if i==1 then return {isHeader=true,title="Shaman"} end
        if i==2 then return {questID=201,title="Class",level=5} end
        if i==3 then return {isHeader=true,title="Alchemy"} end
        if i==4 then return {questID=202,title="Profession dungeon",level=5} end
        if i==5 then return {isHeader=true,title="Wetlands"} end
        return {questID=203,title="Normal",level=5}
      end
      C_QuestLog.GetQuestTagInfo=function(id) if id==202 then return {tagID=81} end end
      QuestPruneForeverDB.sort="type"; QuestPruneForeverDB.filter="all"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[13].header.text=="Class" and frames[16].data.info.questID==201)
      assert(frames[19].header.text=="Profession" and frames[22].data.info.questID==202)
      QuestPruneForeverDB.filter="class"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[7].header.text=="Class" and frames[10].data.info.questID==201 and not frames[13]:IsShown())
      QuestPruneForeverDB.filter="profession"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[10].data.info.questID==202 and not frames[13]:IsShown())
      QuestPruneForeverDB.filter="dungeon"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[10].data.info.questID==202 and not frames[13]:IsShown())
      C_QuestLog.GetNumQuestLogEntries=function() return 24,12 end
      C_QuestLog.GetInfo=function(i)
        local group=math.ceil(i/2)
        if i%2==1 then return {isHeader=true,title=("Zone %02d"):format(group)} end
        return {questID=1000+group,title=("Quest %02d"):format(group),level=5}
      end
      QuestPruneForeverDB.sort="zone"; QuestPruneForeverDB.filter="all"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[73]:IsShown() and frames[73].header.text=="Zone 12" and not frames[76]:IsShown())
      frames[2].scripts.OnMouseWheel(frames[2],-100)
      assert(frames[73].data.info.questID==1012 and not frames[76]:IsShown())
      C_QuestLog.GetNumQuestLogEntries=function() return 2,1 end
      C_QuestLog.GetInfo=function(i) if i==1 then return {isHeader=true,title="Test"} end return {questID=42,title="Reward test",level=5} end
      loaded=false; requests=0; selectedMode=false
      local function checkID(id) if selectedMode then assert(id==nil and selected==42) else assert(id==42) end end
      GetNumQuestLogChoices=function(id) checkID(id); return 2 end
      GetNumQuestLogRewards=function(id) checkID(id); return 2 end
      GetQuestLogChoiceInfo=function(i,id) checkID(id); if i==2 and not loaded then return nil,nil end; return "Choice",100+i,2,2,true,1000+i end
      GetQuestLogRewardInfo=function(i,id) checkID(id); return "Reward",200+i,1,3,true,2000+i end
      GetQuestLogRewardMoney=function(id) checkID(id); return 4500 end
      GetQuestLogRewardXP=function(id) checkID(id); return 1400 end
      C_QuestLog.RequestLoadQuestByID=function(id) assert(id==42); requests=requests+1 end
      QuestPruneForeverDB.sort="level"; event("QUEST_LOG_UPDATE"); flush()
      local rewards=frames[10].rewards
      assert(rewards.money.text=="45s" and rewards.xp.text=="1.4k XP" and rewards.more.text=="+1")
      assert(rewards.items[1].reward.kind=="choice" and rewards.items[1].icon.texture==101)
      assert(rewards.items[2].icon.texture:match("QuestionMark$") and requests==1)
      loaded=true; event("QUEST_DATA_LOAD_RESULT",42,true); flush()
      assert(rewards.items[2].icon.texture==102 and requests==1)
      GameTooltip.SetQuestLogItem=function(_,kind,slot,id) tooltipItem={kind,slot,id,selected} end
      rewards.items[1].scripts.OnEnter(rewards.items[1]); rewards.items[1].scripts.OnLeave(rewards.items[1])
      assert(tooltipItem[1]=="choice" and tooltipItem[2]==1 and tooltipItem[3]==42)
      selected=7; selectedMode=true; command("compat rewards selected"); assert(selected==7)
      rewards.items[1].scripts.OnEnter(rewards.items[1]); rewards.items[1].scripts.OnLeave(rewards.items[1])
      assert(tooltipItem[3]==nil and tooltipItem[4]==42 and selected==7)
      selectedMode=false; command("compat rewards direct"); assert(selected==7)
    ''')
    lua.execute('C_QuestLog.GetQuestObjectives = nil; C_QuestLog.GetInfo = nil; command("dump")')
    german = LuaRuntime(unpack_returned_tuples=True)
    german.execute(PRELUDE)
    german.execute('GetLocale=function() return "deDE" end')
    german.eval("function(s) local f,err=load(s); if not f then error(err) end; return f end")(source)("QuestPruneForever")
    german.execute('''
      event("ADDON_LOADED","QuestPruneForever"); event("PLAYER_LOGIN")
      C_QuestLog.GetNumQuestLogEntries=function() return 4,2 end
      C_QuestLog.GetInfo=function(i)
        if i==1 then return {isHeader=true,title="Schamane"} end
        if i==2 then return {questID=1,title="Klasse",level=5} end
        if i==3 then return {isHeader=true,title="Alchemie"} end
        return {questID=2,title="Beruf",level=5}
      end
      QuestPruneForeverDB.filter="class"; command("")
      assert(frames[10].data.info.questID==1)
      QuestPruneForeverDB.filter="profession"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[10].data.info.questID==2)
    ''')
    print("Chat output:")
    for line in lua.globals().chat.values():
        print(line)
    print("PASS: syntax, startup, dump, debounce, reset, quest protection and abandonment")


if __name__ == "__main__":
    main()


