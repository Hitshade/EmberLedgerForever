-- Copyright (c) 2026 Hitshade
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local _,E=...
function E:ToggleHistory()
    if self.historyPanel and self.historyPanel:IsShown() then self.historyPanel:Hide(); return end
    if not self.historyPanel then
        local f=self.UIPanel(UIParent); self.historyPanel=f
        f:SetSize(440,378); if self.options then f:SetPoint("TOPLEFT",self.options,"TOPRIGHT",18,0) else f:SetPoint("CENTER") end; f:SetFrameStrata("DIALOG")
        f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetClampedToScreen(true)
        f:SetScript("OnDragStart",function() f:StartMoving() end)
        f:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
        f:SetScript("OnHide",function() f:StopMovingOrSizing(); GameTooltip:Hide() end)
        f.titleLabel=self.UIText(f,13); f.titleLabel:SetText("Session history")
        f.closeButton=self.UIButton(f,"x",22,function() f:Hide() end); f.closeButton.isClose=true
        f.date=self.UIText(f,12); f.date:SetPoint("TOPLEFT",14,-48)
        f.summary=self.UIText(f,11); f.summary:SetPoint("TOPLEFT",14,-72); f.summary:SetWidth(412)
        f.money=self.UIText(f,11); f.money:SetPoint("TOPLEFT",14,-92); f.money:SetWidth(412)
        for _,v in ipairs({{"ITEM",36,200},{"QTY",252,32},{"TOTAL",300,120}}) do
            local t=self.UIText(f,10); t:SetPoint("TOPLEFT",v[2],-120); t:SetWidth(v[3]); t:SetText(v[1]); t:SetJustifyH(v[1]=="ITEM" and "LEFT" or "RIGHT")
        end
        f.rows={}
        for i=1,9 do
            local row=CreateFrame("Button",nil,f); row:SetSize(412,22); row:SetPoint("TOPLEFT",14,-136-(i-1)*22)
            row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(17,17); row.icon:SetPoint("LEFT")
            row.name=self.UIText(row,11); row.name:SetPoint("LEFT",22,0); row.name:SetWidth(206); row.name:SetWordWrap(false)
            row.qty=self.UIText(row,11); row.qty:SetPoint("RIGHT",-142,0); row.qty:SetWidth(32); row.qty:SetJustifyH("RIGHT")
            row.total=self.UIText(row,11); row.total:SetPoint("RIGHT",-6,0); row.total:SetWidth(120); row.total:SetJustifyH("RIGHT")
            row:SetScript("OnEnter",function()
                if not row.data then return end
                GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
                if row.data.link then GameTooltip:SetHyperlink(row.data.link) else GameTooltip:SetText(row.data.name) end
                GameTooltip:AddLine("Saved unit price: "..(row.data.unit and E.Money(row.data.unit) or "Unpriced"),1,0.8,0.4)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave",function() GameTooltip:Hide() end)
            f.rows[i]=row
        end
        f.empty=self.UIText(f,12); f.empty:SetPoint("TOPLEFT",18,-158); f.empty:SetText("No saved sessions yet.")
        f.page=self.UIText(f,10); f.page:SetPoint("BOTTOMLEFT",14,14)
        f.older=self.UIButton(f,"Older",65,function() E:BrowseHistory(1) end); f.older:SetPoint("BOTTOMRIGHT",-14,10)
        f.newer=self.UIButton(f,"Newer",65,function() E:BrowseHistory(-1) end); f.newer:SetPoint("RIGHT",f.older,"LEFT",-6,0)
        f:EnableMouseWheel(true)
        f:SetScript("OnMouseWheel",function(_,delta) E.historyOffset=math.max(0,(E.historyOffset or 0)-delta*3); E:RefreshHistory() end)
        self:ApplyTheme()
    end
    self.historySelection=self.db.history[1]; self.historyOffset=0
    self.historyPanel:Show(); self:RefreshHistory()
end
function E:BrowseHistory(delta)
    local index=1
    for i,s in ipairs(self.db.history) do if s==self.historySelection then index=i; break end end
    index=math.max(1,math.min(#self.db.history,index+delta))
    self.historySelection=self.db.history[index]; self.historyOffset=0; self:RefreshHistory()
end
function E:RefreshHistory()
    local f=self.historyPanel
    if not f or not f:IsShown() then return end
    local index
    for i,s in ipairs(self.db.history) do if s==self.historySelection then index=i; break end end
    if not index then self.historySelection=self.db.history[1]; index=1 end
    local s=self.historySelection
    local list={}
    if s then for _,row in pairs(s.items) do list[#list+1]=row end end
    table.sort(list,function(a,b) local av,bv=(a.unit or 0)*a.qty,(b.unit or 0)*b.qty; if av~=bv then return av>bv end; return a.name<b.name end)
    self.historyOffset=math.min(self.historyOffset or 0,math.max(0,#list-9))
    f.date:SetText(s and (date("%b %d, %Y  %H:%M",s.started).."  /  "..index.." of "..#self.db.history) or "Session archive")
    f.summary:SetText(s and (E.Duration(s.elapsed).." active  /  "..s.count.." items") or "Stop a nonempty session, or start a new one, to save it.")
    local value,rate=0,0
    if s then value,rate=self:Totals(s) end
    f.money:SetText(s and (E.Money(value).." value  /  "..E.Money(rate).." per hour") or "")
    for i,row in ipairs(f.rows) do
        local data=list[i+self.historyOffset]; row.data=data; row:SetShown(data~=nil)
        if data then row.name:SetText(data.name); row.qty:SetText(tostring(data.qty)); row.total:SetText(data.unit and E.Money(data.unit*data.qty) or "Unpriced"); row.icon:SetTexture(data.icon or 134400) end
    end
    f.empty:SetShown(not s or #list==0)
    f.empty:SetText(s and "No item loot in this session." or "No saved sessions yet.")
    f.page:SetText(#list>0 and (self.historyOffset+1).."-"..math.min(#list,self.historyOffset+9).." of "..#list.."  /  Scroll" or "")
    f.older:SetEnabled(s~=nil and index<#self.db.history); f.newer:SetEnabled(s~=nil and index>1)
end
