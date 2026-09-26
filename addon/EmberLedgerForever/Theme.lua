-- Copyright (c) 2026 Hitshade
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local _,E=...
local function rgb(hex)
    return {tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255}
end
E.themes={
    modern={bg=rgb("10161C"),panel=rgb("1C2731"),border=rgb("364653"),accent=rgb("57C9D9"),text=rgb("EFF3F5"),muted=rgb("ABB8C1"),font="Fonts\\FRIZQT__.TTF"},
    camelot={bg=rgb("17130E"),panel=rgb("292016"),border=rgb("8F7445"),accent=rgb("E7BD65"),text=rgb("F2E7D3"),muted=rgb("C5B38F"),font="Fonts\\FRIZQT__.TTF"},
    classic={bg=rgb("171410"),panel=rgb("30271C"),border=rgb("A18D68"),accent=rgb("FFD100"),text=rgb("F4E7CF"),muted=rgb("C7B994"),font="Fonts\\FRIZQT__.TTF"},
}
E.panels,E.labels,E.buttons,E.sections={},{},{},{}
E.flatBackdrop={bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}
E.classicBackdrop={bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=20,insets={left=5,right=5,top=5,bottom=5}}
E.insetBackdrop={bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}}
local pieces={"TopLeftCorner","TopRightCorner","BottomLeftCorner","BottomRightCorner","TopEdge","BottomEdge","LeftEdge","RightEdge"}
local function atlasInfo(name)
    if not C_Texture or not C_Texture.GetAtlasInfo then return end
    local ok,info=pcall(C_Texture.GetAtlasInfo,name)
    if ok then return info end
end
local function atlas(texture,name)
    if not atlasInfo(name) then return false end
    texture:SetAtlas(name); return true
end
function E:SkinPanel(frame,inset) self.panels[#self.panels+1]={frame=frame,inset=inset} end
function E:SkinText(label,size,role) self.labels[#self.labels+1]={label=label,size=size,role=role or "text"} end
function E:SkinButton(button) self.buttons[#self.buttons+1]=button end

-- BackdropTemplate owns TopEdge/TopLeftCorner/etc. Never apply a native
-- NineSlice to that same frame: SetBackdrop replaces those textures and hiding
-- the native skin would also hide the next theme's backdrop border.
function E:PrepareNativeFrame(f)
    if f.nativeChrome then return true end
    if not NineSliceUtil or not NineSliceUtil.GetLayout or not NineSliceUtil.ApplyLayout then return false end
    local source=NineSliceUtil.GetLayout("ButtonFrameTemplateNoPortrait")
    if not source then return false end
    for _,key in ipairs(pieces) do
        if not source[key] or not atlasInfo(source[key].atlas) then return false end
    end
    local layout={}
    for key,value in pairs(source) do
        if type(value)=="table" then
            layout[key]={}
            for k,v in pairs(value) do layout[key][k]=v end
            layout[key].layer="BORDER"; layout[key].subLevel=1
        else layout[key]=value end
    end
    local chrome=CreateFrame("Frame",nil,f)
    chrome:SetAllPoints(f); chrome:EnableMouse(false)
    chrome:SetFrameLevel(f:GetFrameLevel())
    NineSliceUtil.ApplyLayout(chrome,layout)
    f.nativeChrome=chrome
    f.nativeReady=true
    return true
end
function E:SkinSection(parent,label,y)
    local art=parent:CreateTexture(nil,"BACKGROUND",nil,1)
    art:SetSize(197,24); art:SetPoint("TOPLEFT",14,y+6)
    self.sections[#self.sections+1]={art=art,label=label,parent=parent,y=y}
end
function E:ApplyTheme()
    if not self.db then return end
    local key=self.db.theme
    local theme=self.themes[key] or self.themes.modern
    local native=key=="camelot"
    local opacity=self.db.opacity
    for _,data in ipairs(self.panels) do
        local f=data.frame
        local root=not data.inset
        local ready=native and root and self:PrepareNativeFrame(f)
        f:SetBackdrop(key=="classic" and (root and self.classicBackdrop or self.insetBackdrop) or self.flatBackdrop)
        local c=data.inset and theme.panel or theme.bg
        f:SetBackdropColor(c[1],c[2],c[3],opacity)
        f:SetBackdropBorderColor(theme.border[1],theme.border[2],theme.border[3],ready and 0 or 1)
        if f.nativeChrome then f.nativeChrome:SetShown(ready==true) end
        if not f.surface then
            f.surface=f:CreateTexture(nil,"BACKGROUND",nil,1)
            f.surface:SetPoint("TOPLEFT",root and 3 or 2,root and -22 or -2)
            f.surface:SetPoint("BOTTOMRIGHT",root and -3 or -2,root and 3 or 2)
        end
        local textured=native and atlas(f.surface,data.inset and "UI-Character-Info-Line-Bounce" or "UI-Character-Info-General-BG")
        f.surface:SetShown(textured==true); f.surface:SetAlpha(opacity)
        if root then
            if not f.titleShade then
                f.titleShade=f:CreateTexture(nil,"BACKGROUND",nil,2)
                f.titleShade:SetPoint("TOPLEFT",2,-2); f.titleShade:SetPoint("TOPRIGHT",-2,-2); f.titleShade:SetHeight(36)
            end
            f.titleShade:SetColorTexture(theme.panel[1],theme.panel[2],theme.panel[3],opacity)
            f.titleShade:SetShown(not native)
            if not f.header then
                f.header=CreateFrame("Frame",nil,f)
                f.header:SetPoint("TOPLEFT"); f.header:SetPoint("TOPRIGHT"); f.header:SetHeight(36)
                f.header:SetFrameLevel(f:GetFrameLevel()+2); f.header:EnableMouse(false)
            end
            -- The native metal art already includes a 20px title strip.
            -- Its baseline differs from the custom 36px Modern/Classic band.
            f.header:SetHeight(native and 20 or 36)
            f.titleShade:SetParent(f.header)
            if f.titleLabel then
                f.titleLabel:SetParent(f.header)
                f.titleLabel:ClearAllPoints()
                f.titleLabel:SetPoint("TOPLEFT",f.header,"TOPLEFT",14,-4)
                f.titleLabel:SetPoint("BOTTOMRIGHT",f.header,"BOTTOMRIGHT",f==self.window and -104 or -42,4)
                f.titleLabel:SetJustifyV("MIDDLE"); f.titleLabel:SetJustifyH("LEFT")
            end
            if f.closeButton then
                f.closeButton:SetParent(f.header)
                f.closeButton:SetSize(native and 18 or 20,native and 18 or 20)
                f.closeButton:ClearAllPoints(); f.closeButton:SetPoint("RIGHT",f.header,"RIGHT",-10,0)
            end
        end
    end
    for _,data in ipairs(self.labels) do
        data.label:SetFont(theme.font,data.size)
        data.label:SetTextColor(unpack(theme[data.role] or theme.text))
    end
    for _,b in ipairs(self.buttons) do
        local normal,pushed=b:GetNormalTexture(),b:GetPushedTexture()
        if normal then normal:SetAlpha(0) end
        if pushed then pushed:SetAlpha(0) end
        b:GetFontString():SetAlpha(1)
        if b.selectorArrow then b.selectorArrow:SetTextColor(unpack(theme.accent)) end
        b:SetBackdrop(key=="modern" and self.flatBackdrop or self.insetBackdrop)
        b:SetBackdropColor(theme.panel[1],theme.panel[2],theme.panel[3],1)
        b:SetBackdropBorderColor(unpack(theme.border))
        -- Keep every button within its hit rectangle. Avoid stretched legacy
        -- artwork and atlas/crop state leaking between theme switches.
        if key=="classic" and not b.isSelector and not b.isClose and not b.isHeader then
            b:SetBackdropColor(0.30,0.045,0.035,1)
        end
        if b.isClose or b.isHeader then
            b:SetHeight(native and 18 or 20)
        end
        local selected=b.themeKey==key
        if not b.selection then
            b.selection=b:CreateTexture(nil,"OVERLAY")
            b.selection:SetPoint("BOTTOMLEFT",4,1); b.selection:SetPoint("BOTTOMRIGHT",-4,1); b.selection:SetHeight(2)
        end
        b.selection:SetColorTexture(unpack(theme.accent)); b.selection:SetShown(selected)
        local label=b:GetFontString()
        b:SetPushedTextOffset(0,0)
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT",b,"TOPLEFT",b.isSelector and 10 or 4,-2)
        label:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",b.isSelector and -28 or -4,2)
        label:SetJustifyH(b.isSelector and "LEFT" or "CENTER"); label:SetJustifyV("MIDDLE")
        label:SetFont(theme.font,11); label:SetTextColor(unpack(selected and theme.accent or theme.text))
        b:GetHighlightTexture():SetVertexColor(theme.accent[1],theme.accent[2],theme.accent[3],0.16)
    end
    for _,section in ipairs(self.sections) do
        section.art:SetShown(native and atlas(section.art,"UI-Character-Info-Title") or false)
        section.label:ClearAllPoints()
        section.label:SetPoint("TOPLEFT",section.parent,"TOPLEFT",native and 24 or 18,section.y)
        section.label:SetWidth(177); section.label:SetJustifyH("LEFT")
        section.label:SetTextColor(unpack(theme.accent))
    end
    for _,slider in pairs(self.optionSliders or {}) do
        slider:SetBackdrop(self.flatBackdrop)
        slider:SetBackdropColor(theme.bg[1],theme.bg[2],theme.bg[3],1)
        slider:SetBackdropBorderColor(unpack(theme.border))
        slider.fill:SetColorTexture(theme.accent[1],theme.accent[2],theme.accent[3],0.5)
    end
    for _,check in ipairs({self.lockOption,self.minimapOption}) do
        check:SetBackdrop(self.flatBackdrop)
        check:SetBackdropColor(theme.panel[1],theme.panel[2],theme.panel[3],1)
        check:SetBackdropBorderColor(unpack(theme.border))
        check:GetCheckedTexture():SetVertexColor(unpack(theme.accent))
    end
    for i,row in ipairs(self.rows or {}) do
        if not row.stripe then
            row.stripe=row:CreateTexture(nil,"BACKGROUND")
            row.stripe:SetAllPoints(row)
        end
        row.stripe:SetColorTexture(theme.panel[1],theme.panel[2],theme.panel[3],i%2==1 and opacity*0.55 or 0)
        row:GetHighlightTexture():SetVertexColor(theme.accent[1],theme.accent[2],theme.accent[3],0.18)
    end
    if self.accent then self.accent:SetColorTexture(unpack(theme.accent)); self.accent:SetShown(key=="modern") end
    if self.window then
        self.window:SetScale(self.db.scale)
        if self.resizeGrip then self.resizeGrip:SetShown(not self.db.locked) end
    end
    if self.options then self.options:SetScale(self.db.scale) end
    if self.historyPanel then self.historyPanel:SetScale(self.db.scale) end
    self:Layout()
    self:Refresh()
end
