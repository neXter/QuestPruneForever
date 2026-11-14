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
frames = {}
CreateFrame = function(kind, name, parent)
  local f = {shown=true, scripts={}, children={}}
  setmetatable(f, {__index=function(_, key) if key == "pending" then return nil end return function() end end})
  function f:RegisterEvent() end
  function f:SetScript(key, fn) self.scripts[key]=fn; if key == "OnEvent" then self.handler=fn; frame=self end end
  function f:CreateFontString() local t={}; setmetatable(t,{__index=function() return function() end end}); return t end
  function f:CreateTexture() local t={}; setmetatable(t,{__index=function() return function() end end}); return t end
  function f:IsShown() return self.shown end
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
      testbutton=frames[8]
      local questrow=frames[7]
      opened=nil
      QuestMapFrame_OpenToQuestDetails=function(id) opened=id end
      questrow.scripts.OnClick(questrow)
      assert(opened==42 and not frames[2]:IsShown())
      command("")
      testbutton.scripts.OnClick()
      assert(abandoned==0)
      testbutton.scripts.OnClick()
      assert(abandoned==1 and selected==7)
      local protect=frames[9]
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
    ''')
    lua.execute('C_QuestLog.GetQuestObjectives = nil; C_QuestLog.GetInfo = nil; command("dump")')
    print("Chat output:")
    for line in lua.globals().chat.values():
        print(line)
    print("PASS: syntax, startup, dump, debounce, reset, quest protection and abandonment")


if __name__ == "__main__":
    main()


