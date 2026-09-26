from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((root/'tests/mock.lua').read_text(encoding='utf-8'))
lua.execute("""
strmatch=string.match
Minimap=CreateFrame('Frame',nil,UIParent); Minimap:SetSize(140,140)
WOW_PROJECT_ID=1; WOW_PROJECT_MAINLINE=1
securecallfunction=function(fn,...) return fn(...) end
""")
addon=root/'addon/EmberLedgerForever'
ns=lua.table()
# Exercise the actual packaged load order, including all four upstream libs.
for line in (addon/'EmberLedgerForever.toc').read_text(encoding='utf-8').splitlines():
    if line.endswith('.lua'):
        lua.execute((addon/line.replace('\\','/')).read_text(encoding='utf-8'),'EmberLedgerForever',ns)
lua.execute("E=EmberLedgerForever; E:OnEvent('ADDON_LOADED','EmberLedgerForever'); icon=LibStub('LibDBIcon-1.0'); b=icon:GetMinimapButton('EmberLedgerForever')")
checks={
 'Packaged libraries register one minimap button': "assert(b and not E.brokerError); E:InitBroker(); assert(icon:GetMinimapButton('EmberLedgerForever')==b and not E.brokerError)",
 'Login positions the icon around Minimap': "for _,f in ipairs(frames) do if f.registered.PLAYER_LOGIN and f.scripts.OnEvent then f.scripts.OnEvent(f,'PLAYER_LOGIN') end end; assert(b.point[2]==Minimap and b:IsShown())",
 'Left-click hides without pausing and shows again': "E:Start(); b.scripts.OnClick(b,'LeftButton'); assert(not E.window:IsShown() and E.db.hidden and E.db.session.state=='running'); loot(1,2); b.scripts.OnClick(b,'LeftButton'); assert(E.window:IsShown() and not E.db.hidden and E.db.session.count==2)",
 'Right-click opens options without toggling the tracker': "b.scripts.OnClick(b,'LeftButton'); b.scripts.OnClick(b,'RightButton'); assert(E.options:IsShown() and not E.window:IsShown())",
 'Hide/show preference survives initialization': "E:SetMinimapShown(false); assert(E.db.minimap.hide and not b:IsShown()); E:InitDB(); assert(E.db.minimap.hide); E:SetMinimapShown(true); assert(b:IsShown() and not E.db.minimap.hide)",
 'Minimap position storage is the saved table': "assert(b.db==E.db.minimap); b.db.minimapPos=123; E:InitDB(); assert(E.db.minimap.minimapPos==123)",
 'Unavailable library preserves slash access': "local stub=LibStub; LibStub=nil; E:InitBroker(); SlashCmdList.EMBERLEDGERFOREVER(''); assert(E.window:IsShown()); LibStub=stub",
}
for name,code in checks.items():
    lua.execute(code); print('PASS',name)
print(str(len(checks))+' bundled broker integration checks passed.')
