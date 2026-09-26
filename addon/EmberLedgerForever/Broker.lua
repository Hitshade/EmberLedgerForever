-- Copyright (c) 2026 Hitshade
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local _,E=...
local name="EmberLedgerForever"
function E:ToggleTracker()
    if not self.window then return end
    self.db.hidden=self.window:IsShown()
    self.window:SetShown(not self.db.hidden)
    self:Refresh()
end
function E:InitBroker()
    if not LibStub or not self.db then return end
    local ldb=LibStub("LibDataBroker-1.1",true)
    local icon=LibStub("LibDBIcon-1.0",true)
    if not ldb or not icon then return end
    local ok,err=pcall(function()
        self.broker=ldb:GetDataObjectByName(name) or ldb:NewDataObject(name,{type="launcher",label="EmberLedger: Forever",icon="Interface\\AddOns\\EmberLedgerForever\\Media\\EmberLedgerLogo"})
        self.broker.OnClick=function(_,button)
            if button=="RightButton" then E:ToggleOptions()
            elseif button=="LeftButton" then E:ToggleTracker() end
        end
        self.broker.OnTooltipShow=function(tip)
            tip:AddLine("EmberLedger: Forever")
            tip:AddLine("Left-click: show / hide tracker",1,1,1)
            tip:AddLine("Right-click: options and history",1,1,1)
            tip:AddLine("Drag: move minimap button",0.7,0.7,0.7)
        end
        if not icon:IsRegistered(name) then icon:Register(name,self.broker,self.db.minimap)
        else icon:Refresh(name,self.db.minimap) end
        self.minimapLibrary=icon
    end)
    if not ok then self.brokerError=tostring(err); print("EmberLedger: minimap button unavailable; use /elf or /elf options.") end
end
function E:SetMinimapShown(shown)
    self.db.minimap.hide=not shown
    if not self.minimapLibrary then self:InitBroker() end
    if self.minimapLibrary then
        local fn=shown and self.minimapLibrary.Show or self.minimapLibrary.Hide
        local ok,err=pcall(fn,self.minimapLibrary,name)
        if not ok then self.brokerError=tostring(err) end
    end
    if self.minimapOption then self.minimapOption:SetChecked(shown) end
end
