-- Copyright (c) 2026 Hitshade
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local _,E=...
local function clamp(value,low,high) return math.min(high,math.max(low,tonumber(value) or low)) end

function E:SetAppearance(key,value)
    if key=="theme" then if not self.themes[value] then return end
    elseif key=="width" then value=math.floor(clamp(value,350,720))
    elseif key=="height" then value=math.floor(clamp(value,206,600))
    elseif key=="opacity" then value=clamp(value,0.15,1)
    elseif key=="scale" then value=clamp(value,0.65,1.5)
    elseif key=="locked" then value=value==true
    else return end
    self.db[key]=value
    if self.window then
        if key=="locked" and value then self.window:StopMovingOrSizing() end
        self.window:SetSize(self.db.width,self.db.height)
        self:Layout(); self:ApplyTheme()
    end
    self:SyncOptions()
end

function E:SyncOptions()
    if not self.options then return end
    self.syncingOptions=true
    for key,slider in pairs(self.optionSliders) do
        local value=self.db[key]
        slider:SetValue(value)
        slider.fill:SetWidth(math.max(1,173*(value-slider.minimum)/(slider.maximum-slider.minimum)))
        slider.valueLabel:SetText((key=="opacity" or key=="scale") and (math.floor(value*100+0.5).."%") or tostring(math.floor(value)))
    end
    self.lockOption:SetChecked(self.db.locked==true)
    if self.minimapOption then self.minimapOption:SetChecked(not self.db.minimap.hide) end
    for key,b in pairs(self.themeButtons) do b:SetText(b.caption) end
    local labels={auto="Auto: TSM / Auctionator / Vendor",tsm="TSM / Vendor",auctionator="Auctionator / Vendor",vendor="Vendor only"}
    self.pricingOption:SetText(labels[self.db.pricing] or labels.auto)
    self.syncingOptions=false
end

function E:CreateOptions()
    if self.options then return end
    local panel,label,button,tip=self.UIPanel,self.UIText,self.UIButton,self.UITip
    local f=panel(UIParent); self.options=f
    f:SetSize(390,536); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetClampedToScreen(true)
    f:SetScript("OnDragStart",function() f:StartMoving() end)
    f:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
    f:SetScript("OnHide",function() f:StopMovingOrSizing() end)
    local title=label(f,13); f.titleLabel=title; title:SetPoint("TOPLEFT",16,-10); title:SetText("EmberLedger options")
    local close=button(f,"x",23,function() f:Hide() end); f.closeButton=close; close.isClose=true; close:SetPoint("TOPRIGHT",-8,-6)
    local logo=f:CreateTexture(nil,"ARTWORK"); f.brandLogo=logo
    logo:SetSize(40,40); logo:SetPoint("TOPLEFT",18,-46)
    logo:SetTexture("Interface\\AddOns\\EmberLedgerForever\\Media\\EmberLedgerLogo")
    local brand=label(f,13); brand:SetPoint("TOPLEFT",70,-50); brand:SetText("EmberLedger: Forever")
    local subtitle=label(f,10,{1,1,1}); subtitle:SetPoint("TOPLEFT",70,-70); subtitle:SetText("Farming ledger / "..E.VERSION)
    local heading=label(f,11); heading:SetPoint("TOPLEFT",24,-104); heading:SetText("Appearance"); self:SkinSection(f,heading,-104)
    self.themeButtons={}
    for i,data in ipairs({{"modern","Modern"},{"camelot","Forever"},{"classic","Classic"}}) do
        local key=data[1]
        local b=button(f,data[2],112,function() E:SetAppearance("theme",key) end)
        b.caption=data[2]; b.themeKey=key; b:SetPoint("TOPLEFT",18+(i-1)*120,-124); self.themeButtons[key]=b
    end
    tip(self.themeButtons.camelot,"Forever / Camelot","Native Forever bronze frame, character-panel textures and warm gold details.")
    local check=CreateFrame("CheckButton",nil,f,"BackdropTemplate"); self.lockOption=check
    check:SetSize(18,18); check:SetPoint("TOPLEFT",18,-158)
    check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    check:GetHighlightTexture():SetVertexColor(1,1,1,0.12)
    check:SetScript("OnClick",function(b) E:SetAppearance("locked",b:GetChecked()) end)
    local lockText=label(f,12); lockText:SetPoint("LEFT",check,"RIGHT",8,0); lockText:SetText("Lock window movement and resizing")
    self.optionSliders={}
    for i,data in ipairs({{"scale","UI scale",0.65,1.5,0.05},{"opacity","Opacity",0.15,1,0.05}}) do
        local key=data[1]
        local y=-200-(i-1)*40
        local caption=label(f,12); caption:SetPoint("TOPLEFT",18,y); caption:SetText(data[2])
        local slider=CreateFrame("Slider",nil,f,"BackdropTemplate")
        slider:SetOrientation("HORIZONTAL"); slider:SetSize(175,8); slider:SetPoint("TOPLEFT",125,y-4)
        slider:SetMinMaxValues(data[3],data[4]); slider:SetValueStep(data[5]); slider:SetObeyStepOnDrag(true)
        slider:SetBackdrop(E.flatBackdrop); slider:SetBackdropColor(0.12,0.16,0.20,1); slider:SetBackdropBorderColor(0.35,0.45,0.5,1)
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        slider:GetThumbTexture():SetSize(18,24)
        slider.fill=slider:CreateTexture(nil,"ARTWORK")
        slider.fill:SetPoint("TOPLEFT",1,-1); slider.fill:SetHeight(6)
        slider.minimum,slider.maximum=data[3],data[4]
        slider.valueLabel=label(f,11); slider.valueLabel:SetPoint("LEFT",slider,"RIGHT",10,0); slider.valueLabel:SetWidth(55)
        slider:SetScript("OnValueChanged",function(_,v) if not E.syncingOptions then E:SetAppearance(key,v) end end)
        self.optionSliders[key]=slider
    end
    local note=label(f,10,{1,1,1}); note:SetPoint("TOPLEFT",18,-274); note:SetWidth(352)
    note:SetText("Opacity affects backgrounds; text stays readable. Drag the tracker’s lower-right corner to resize when unlocked.")
    local pricing=label(f,11); pricing:SetPoint("TOPLEFT",24,-311); pricing:SetText("Item pricing"); self:SkinSection(f,pricing,-311)
    self.pricingOption=button(f,"Auto",350,function()
        local nextMode={auto="tsm",tsm="auctionator",auctionator="vendor",vendor="auto"}
        E.db.pricing=nextMode[E.db.pricing] or "auto"
        E:RepriceSession(); E:SyncOptions()
    end)
    self.pricingOption.isSelector=true
    self.pricingOption:SetPoint("TOPLEFT",18,-335)
    self.pricingOption:SetHeight(24)
    local pricingText=self.pricingOption:GetFontString()
    pricingText:ClearAllPoints(); pricingText:SetPoint("LEFT",10,0)
    pricingText:SetWidth(318); pricingText:SetJustifyH("LEFT")
    local arrow=label(self.pricingOption,11)
    arrow:SetPoint("RIGHT",-8,0); arrow:SetText(">")
    self.pricingOption.selectorArrow=arrow
    tip(self.pricingOption,"Pricing source","Click to cycle sources. Manual per-item prices override this choice. Missing market data falls back to vendor value. Saved history never changes.")
    local refresh=button(f,"Refresh prices",172,function() E:RepriceSession() end); refresh:SetPoint("TOPLEFT",18,-385)
    local reset=button(f,"Reset appearance",172,function()
        E.db.width,E.db.height,E.db.scale,E.db.opacity,E.db.theme,E.db.locked=350,206,1,0.95,"modern",false
        E:SetAppearance("theme","modern")
    end); reset:SetPoint("TOPRIGHT",-18,-385)
    local sessionHeading=label(f,11); sessionHeading:SetPoint("TOPLEFT",18,-422); sessionHeading:SetText("Current session")
    self.sessionSummary=label(f,10); self.sessionSummary:SetPoint("TOPLEFT",18,-443)
    self.startButton=button(f,"Pause",82,function()
        if E.db.session.state=="running" then E:Pause() else E:Start() end
        E.editor:Hide(); E:Refresh()
    end)
    self.startButton:SetPoint("TOPLEFT",18,-467)
    self.finishButton=button(f,"Stop",82,function() E:Finish(); E.editor:Hide(); E:Refresh() end)
    self.finishButton:SetPoint("LEFT",self.startButton,"RIGHT",8,0)
    self.newButton=button(f,"New",82,function() E:New(); E:Start(); E.editor:Hide(); E:Refresh() end)
    self.newButton:SetPoint("LEFT",self.finishButton,"RIGHT",8,0)
    tip(self.newButton,"New session","Saves the current nonempty session and immediately begins a new one.")
    self.historyButton=button(f,"History",82,function() E:ToggleHistory() end)
    self.historyButton:SetPoint("TOPRIGHT",-18,-467)
    local mini=CreateFrame("CheckButton",nil,f,"BackdropTemplate"); self.minimapOption=mini
    mini:SetSize(18,18); mini:SetPoint("TOPLEFT",18,-502)
    mini:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    mini:SetScript("OnClick",function(b) E:SetMinimapShown(b:GetChecked()) end)
    local miniText=label(f,11); miniText:SetPoint("LEFT",mini,"RIGHT",8,0); miniText:SetText("Show minimap button")
    self:SyncOptions(); self:ApplyTheme()
end

function E:ToggleOptions()
    if not self.options then self:CreateOptions()
    elseif self.options:IsShown() then self.options:Hide(); return end
    self.options:Show(); self:SyncOptions()
end

function E:SyncSessionControls()
    if not self.startButton then return end
    local s=self.db.session
    self.startButton:SetText(s.state=="running" and "Pause" or (s.state=="paused" and "Resume" or "Start"))
    self.startButton:SetEnabled(s.state~="finished")
    self.finishButton:SetEnabled(s.state=="running" or s.state=="paused")
    self.sessionSummary:SetText(E.Duration(s.elapsed).."  /  "..s.count.." items  /  "..s.state)
end
