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
UnitName = function() return "Tester" end
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
  local f = {shown=true, scripts={}, children={}}
  setmetatable(f, {__index=function(_, key) if key == "pending" then return nil end return function() end end})
  function f:RegisterEvent() end
  function f:SetScript(key, fn) self.scripts[key]=fn; if key == "OnEvent" then self.handler=fn; frame=self end end
  function f:CreateFontString() local t={}; function t:SetText(s) self.text=s end; function t:GetStringHeight() local _,n=(self.text or ""):gsub("\n", ""); return (n+1)*12 end; setmetatable(t,{__index=function() return function() end end}); return t end
  function f:CreateTexture() local t={}; setmetatable(t,{__index=function() return function() end end}); return t end
  function f:IsShown() return self.shown end
  function f:SetHeight(h) self.height=h end
  function f:GetHeight() return self.height or 28 end
  function f:SetPoint(...) self.point={...} end
  function f:LockHighlight() self.highlightLocked=true end
  function f:UnlockHighlight() self.highlightLocked=false end
  function f:Show() self.shown=true end
  function f:Hide() self.shown=false end
  function f:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
  frames[#frames+1]=f
  return f
end
function event(name, arg) frame.handler(frame, name, arg) end
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
      command("")
      for _, f in ipairs(frames) do if f.scripts.OnClick then testbutton=f end end
      -- The first row button follows the title buttons in the frame list.
      testbutton=frames[11]
      local questrow=frames[10]
      opened=nil
      QuestMapFrame_OpenToQuestDetails=function(id) opened=id end
      questrow.scripts.OnClick(questrow)
      assert(opened==42 and not frames[2]:IsShown())
      command("")
      testbutton.scripts.OnClick()
      assert(abandoned==0)
      testbutton.scripts.OnClick()
      assert(abandoned==1 and selected==7)
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
      assert(abandoned==2)
      noObjectives=true; testbutton.scripts.OnClick()
      assert(abandoned==2)
      flush(); testbutton.scripts.OnClick()
      assert(abandoned==2)
      shift=true; testbutton.scripts.OnClick(); shift=false
      assert(abandoned==3)
      failed=true; testbutton.scripts.OnClick(); failed=false
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
      QuestPruneForeverDB.sort="zone"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[7].header.text=="Alpha" and frames[10].data.info.questID==42)
      assert(frames[13].header.text=="Beta" and frames[16].data.info.questID==43)
      QuestPruneForeverDB.sort="level"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[7].header.text=="Grey" and frames[13].header.text=="Yellow")
      QuestPruneForeverDB.sort="progress"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[7].header.text=="Unknown progress" and frames[13].header.text=="Ready to turn in")
      C_QuestLog.GetQuestObjectives=function(id)
        if id==42 then return {{text="First",numFulfilled=0,numRequired=1}, {text="Second",numFulfilled=0,numRequired=1}, {text="Third",numFulfilled=0,numRequired=1}, {text="Fourth",numFulfilled=0,numRequired=1}} end
        return {}
      end
      QuestPruneForeverDB.sort="zone"; event("QUEST_LOG_UPDATE"); flush()
      assert(frames[10].status.text=="First\\nSecond\\nThird\\nFourth")
      assert(frames[10]:GetHeight()==54 and frames[13].point[3]==-141)
    ''')
    lua.execute('C_QuestLog.GetQuestObjectives = nil; C_QuestLog.GetInfo = nil; command("dump")')
    print("Chat output:")
    for line in lua.globals().chat.values():
        print(line)
    print("PASS: syntax, startup, dump, debounce, reset, quest protection and abandonment")


if __name__ == "__main__":
    main()


