"""Integration checks using the inspected Forever UI source mirror.
Usage: python test_native.py path/to/theme-research
The source directory is external to the addon/release ZIP.
"""
import sys
from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1])
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((root/'tests/mock.lua').read_text(encoding='utf-8'))
lua.execute("""
function GetFinalNameFromTextureKit(name) return name end
C_Texture={GetAtlasInfo=function(name) return {width=32,height=32} end}
""")
for name in ['layouts.txt','NineSlice.txt','NineSliceEngine.lua','Backdrop.lua']:
    lua.execute((source/name).read_text(encoding='utf-8'))
# Exercise the real backdrop too: its corner names collided with native art
# in 0.3.0, a failure the previous no-op backdrop mock could not catch.
lua.execute("""
max=math.max
local rawCreateFrame=CreateFrame
function CreateFrame(kind,name,parent,template)
    local f=rawCreateFrame(kind,name,parent,template)
    if template and template:find('BackdropTemplate',1,true) then
        for k,v in pairs(BackdropTemplateMixin) do f[k]=v end
    end
    return f
end
""")
ns=lua.table()
for name in ['Ledger.lua','Loot.lua','Core.lua','Theme.lua','UI.lua','Options.lua','History.lua','Broker.lua']:
    lua.execute((root/'addon/EmberLedgerForever'/name).read_text(encoding='utf-8'),'EmberLedgerForever',ns)
lua.execute("E=EmberLedgerForever; E:OnEvent('ADDON_LOADED','EmberLedgerForever'); E:ToggleOptions()")
checks={
 'Native art uses complete client layout on both windows': "E:SetAppearance('theme','camelot'); assert(E.window.nativeReady and E.options.nativeReady); assert(E.window.nativeChrome.TopLeftCorner.useAtlasSize); assert(E.window.nativeChrome.TopEdge.layer=='BORDER'); assert(E.window.surface.atlas=='UI-Character-Info-General-BG')",
 'Native border survives backdrop recoloring': "local f=E.window; assert(f.nativeChrome.TopEdge~=f.TopEdge); assert(f.nativeChrome.TopEdge.atlas=='_UI-Frame-Metal-EdgeTop'); assert(f.TopEdge.color[4]==0); assert(f.nativeChrome.TopEdge:GetVertexColor()==1)",
 'Modern and Classic borders survive visiting Forever': "for _,theme in ipairs({'modern','classic'}) do E:SetAppearance('theme',theme); for _,f in ipairs({E.window,E.options}) do assert(f.TopEdge:IsShown()); assert(f.TopEdge.path==E[theme=='modern' and 'flatBackdrop' or 'classicBackdrop'].edgeFile); assert(f.TopEdge.color[4]==1) end end",
 'Header foreground and square close button': "E:SetAppearance('theme','camelot'); assert(E.window.header:GetFrameLevel()>E.window.nativeChrome:GetFrameLevel()); assert(E.window.titleLabel.parent==E.window.header); assert(E.window.closeButton.width==18 and E.window.closeButton.height==18)",
 'Section decorations clear their following buttons': "assert(E.sections[1].art.height==24); assert(-E.sections[1].art.point[3]+24<124); assert(-E.sections[2].art.point[3]+24<335)",
 'Pricing selector never receives stretched red artwork': "E:SetAppearance('theme','classic'); local b=E.pricingOption; assert(b.isSelector and b.height==24); assert(not b:GetNormalTexture() or b:GetNormalTexture().alpha==0); assert(b:GetFontString().width==318)",
 'History shares appearance but keeps its own frame': "E:ToggleHistory(); E:SetAppearance('theme','camelot'); assert(E.historyPanel.nativeChrome and E.historyPanel~=E.window); E:SetAppearance('theme','modern'); assert(not E.historyPanel.nativeChrome:IsShown())",
 'Branding stays in Options and all frames use plain corners': "assert(not E.window.logo and not E.window.logoMask); assert(E.options.brandLogo.width==40); E:SetAppearance('theme','camelot'); assert(E.window.nativeChrome.TopLeftCorner.atlas=='UI-Frame-Metal-CornerTopLeft'); assert(E.options.nativeChrome.TopLeftCorner.atlas=='UI-Frame-Metal-CornerTopLeft')",
 'Buttons keep consistent bounds and visible close labels across themes': "for _,theme in ipairs({'modern','camelot','classic'}) do E:SetAppearance('theme',theme); for _,b in ipairs(E.buttons) do assert(b.height==((b.isClose or b.isHeader) and (theme=='camelot' and 18 or 20) or 24)); assert(b:GetFontString().alpha==1) end end; assert(E.startButton.width==82 and E.finishButton.width==82 and E.newButton.width==82 and E.historyButton.width==82)",
 'Blizzard layout remains unchanged': "assert(NineSliceUtil.GetLayout('ButtonFrameTemplateNoPortrait').TopEdge.layer=='OVERLAY'); assert(NineSliceUtil.GetLayout('ButtonFrameTemplateNoPortrait').BottomLeftCorner.y==-8)",
 'Repeated theme switching hides old chrome and restores close caption': "for i=1,5 do E:SetAppearance('theme','modern'); assert(not E.window.nativeChrome:IsShown() and not E.options.nativeChrome:IsShown()); assert(E.window.closeButton:GetFontString().alpha==1); E:SetAppearance('theme','classic'); assert(not E.window.closeButton:GetNormalTexture() or E.window.closeButton:GetNormalTexture().alpha==0); E:SetAppearance('theme','camelot'); assert(E.window.nativeChrome:IsShown() and E.options.nativeChrome:IsShown()); assert(E.window.closeButton:GetFontString().alpha==1); assert(E.themeButtons.camelot.selection:IsShown() and not E.themeButtons.modern.selection:IsShown()) end",
 'Resizing and opacity preserve frame clarity and options scale': "E:SetAppearance('width',600); E:SetAppearance('height',500); E:SetAppearance('opacity',0.3); E:SetAppearance('scale',0.8); assert(E.window.surface.alpha==0.3); assert(E.window.alpha==nil); assert(E.options.scale==0.8); assert(E.window.nativeChrome.TopEdge.alpha==nil); assert(E.visibleRows==17)",
 'Missing one native asset creates no partial frame': "C_Texture.GetAtlasInfo=function(name) if name=='UI-Frame-Metal-CornerTopLeft' then return nil end return {} end; assert(E:PrepareNativeFrame(CreateFrame('Frame'))==false)",
 'Button text uses a stable centered rectangle': "for _,b in ipairs(E.buttons) do local label=b:GetFontString(); assert(b.pushX==0 and b.pushY==0); assert(label.justifyV=='MIDDLE'); assert(label.justifyH==(b.isSelector and 'LEFT' or 'CENTER')); assert(not b.scripts.OnMouseDown and not b.scripts.OnMouseUp) end",
 'Custom title bars retain their original centerline': "E:SetAppearance('theme','modern'); for _,f in ipairs({E.window,E.options,E.historyPanel}) do assert(f.header.height==36); assert(f.titleLabel.justifyV=='MIDDLE'); assert(f.closeButton.point[1]=='RIGHT' and f.closeButton.point[5]==0) end",
 'Forever uses native title strip without duplicate shading': "for _,theme in ipairs({'camelot','modern','classic','camelot'}) do E:SetAppearance('theme',theme); for _,f in ipairs({E.window,E.options,E.historyPanel}) do assert(f.header.height==(theme=='camelot' and 20 or 36)); assert(f.titleShade:IsShown()==(theme~='camelot')); assert(f.closeButton.point[1]=='RIGHT' and f.closeButton.point[5]==0) end end",
 'Forever tracker fits the title and shares column edges': "E:SetAppearance('theme','camelot'); E:SetAppearance('width',350); E:SetAppearance('height',206); local a,b,c=unpack(E.metricBoxes); assert(a.point[2]==14 and a.point[3]==-26); assert(c.point[2]+c.width==336); assert(b.point[2]-a.point[2]-a.width==4); assert(E.rows[1].point[2]==14 and E.rows[1].point[3]==-100); assert(E.headers[3].point[2]+E.headers[3].width==350-14-4); assert(E.page.point[2]==14)",
 'Other themes restore their accepted content spacing': "for _,theme in ipairs({'modern','classic'}) do E:SetAppearance('theme',theme); assert(E.metricBoxes[1].point[2]==9 and E.metricBoxes[1].point[3]==-44); assert(E.rows[1].point[3]==-118 and E.status.point[3]==-85) end",
 'Slider fill and selected theme stay synchronized': "E:SetAppearance('opacity',1); assert(math.abs(E.optionSliders.opacity.fill.width-173)<0.001); E:SetAppearance('opacity',0.15); assert(E.optionSliders.opacity.fill.width==1); E:SetAppearance('theme','modern'); assert(E.themeButtons.modern.selection:IsShown())",
}
for title,code in checks.items():
    lua.execute(code)
    print('PASS',title)
print(str(len(checks))+' native-layout integration checks passed (rendering still requires WoW).')

