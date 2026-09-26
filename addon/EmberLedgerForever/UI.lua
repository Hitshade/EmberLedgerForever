-- Copyright (c) 2026 Hitshade
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local _, E = ...
local BACKDROP = {bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1}
local function panel(parent, shade)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(shade or 0.055, 0.055, 0.065, 0.98)
    f:SetBackdropBorderColor(0.28,0.24,0.19,1)
    E:SkinPanel(f,shade~=nil)
    return f
end
local function text(parent, size, color)
    local t = parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    t:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 12)
    t:SetTextColor(unpack(color or {0.88,0.86,0.81}))
    t:SetJustifyH("LEFT")
    E:SkinText(t,size or 12,color and "muted" or "text")
    return t
end
local function button(parent, label, width, handler)
    local b = CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetSize(width,24)
    local caption=text(b,11)
    caption:SetPoint("TOPLEFT",b,"TOPLEFT",4,-2); caption:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",-4,2); caption:SetJustifyH("CENTER"); caption:SetJustifyV("MIDDLE")
    b:SetFontString(caption)
    b:SetPushedTextOffset(0,0)
    b:SetText(label)
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    b:GetHighlightTexture():SetVertexColor(1,1,1,0.12)
    b:SetScript("OnDisable",function() b:SetAlpha(0.45) end)
    b:SetScript("OnEnable",function() b:SetAlpha(1) end)
    -- WoW also offsets button-owned font strings. Keep a single stable text
    -- rectangle; use the button highlight for feedback instead of moving text.
    b:SetScript("OnClick",handler)
    E:SkinButton(b)
    return b
end
local function tip(frame, title, body)
    frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(frame,"ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(body,0.9,0.9,0.9,true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave",function() GameTooltip:Hide() end)
end

function E:CreateUI()
    local f = panel(UIParent)
    self.window = f
    f:Hide()
    f:SetSize(self.db.width,self.db.height)
    f:SetScale(self.db.scale)
    f:SetPoint("CENTER")
    local p = self.db.position
    if type(p)=="table" and type(p.x)=="number" and type(p.y)=="number" then
        f:ClearAllPoints()
        f:SetPoint("CENTER",UIParent,"CENTER",p.x,p.y)
    end
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function() if not E.db.locked then f:StartMoving() end end)
    f:SetScript("OnDragStop",function()
        f:StopMovingOrSizing()
        local x,y = f:GetCenter()
        local ux,uy = UIParent:GetCenter()
        local factor = UIParent:GetEffectiveScale()/f:GetEffectiveScale()
        E.db.position = {x=x-ux*factor,y=y-uy*factor}
    end)
    f:SetScript("OnHide",function() f:StopMovingOrSizing(); GameTooltip:Hide() end)
    local accent = f:CreateTexture(nil,"ARTWORK"); self.accent=accent
    accent:SetColorTexture(0.9,0.36,0.10,1)
    accent:SetPoint("TOPLEFT",1,-1); accent:SetPoint("TOPRIGHT",-1,-1); accent:SetHeight(3)
    local title = text(f,12)
    f.titleLabel=title
    title:SetPoint("TOPLEFT",34,-10); title:SetWidth(235); title:SetWordWrap(false); title:SetText("EmberLedger: Forever")
    local close = button(f,"x",22,function() E.db.hidden=true; f:Hide() end)
    f.closeButton=close; close.isClose=true; close:SetPoint("TOPRIGHT",-8,-6)
    tip(close,"Hide window","Tracking continues while running. Type /elf to reopen.")
    local options=button(f,"Options",54,function() E:ToggleOptions() end)
    f.optionsButton=options; options.isHeader=true; options:SetPoint("RIGHT",close,"LEFT",-6,0)
    tip(options,"Options","Session controls, history, appearance and pricing.")

    self.metrics, self.metricBoxes = {}, {}
    for i,label in ipairs({"TIME","VALUE (EST.)","G / HR (EST.)"}) do
        local box = panel(f,0.085)
        box:SetSize(88,39); box:SetPoint("TOPLEFT",9+(i-1)*91,-36)
        local caption = text(box,9,{0.60,0.59,0.56}); caption:SetPoint("TOPLEFT",5,-5); caption:SetText(label)
        local value = text(box,11); value:SetPoint("BOTTOMLEFT",5,6); value:SetWidth(79)
        self.metrics[i] = value; self.metricBoxes[i]=box
        box:EnableMouse(true)
        tip(box,label,i==3 and "Gross estimated value per active hour. Paused/offline time is excluded. Short sessions produce volatile rates." or "Value uses the selected market source, vendor fallback, or your manual override. Only confirmed looted coin is included; sales, quest money, spending and transfers are excluded.")
    end
    self.metricBoxes[2]:SetScript("OnEnter",function()
        local session=E.db.session
        local total,_,unknown=E:Totals(session)
        GameTooltip:SetOwner(E.metricBoxes[2],"ANCHOR_RIGHT")
        GameTooltip:SetText("Estimated session value")
        GameTooltip:AddLine("Looted coin: "..E.Money(session.coin),1,1,1)
        GameTooltip:AddLine("Items: "..E.Money(total-session.coin),1,1,1)
        GameTooltip:AddLine("Pricing: "..(E.db.pricing or "auto").."; hover an item for its source.",0.8,0.8,0.8,true)
        if unknown>0 then GameTooltip:AddLine(unknown.." items are unpriced",1,0.7,0.2) end
        GameTooltip:Show()
    end)
    self.status = text(f,11,{0.76,0.71,0.62})
    self.status:SetPoint("TOPLEFT",10,-85); self.status:SetWidth(360)
    self.headers={}
    for _,col in ipairs({{"ITEM",31,170},{"QTY",205,28},{"TOTAL",243,94}}) do
        local h=text(f,9,{0.65,0.61,0.54}); h:SetPoint("TOPLEFT",col[2],-101); h:SetWidth(col[3]); h:SetText(col[1])
        self.headers[#self.headers+1]=h
        if col[1]~="ITEM" then h:SetJustifyH("RIGHT") end
    end
    self.rows = {}
    for i=1,19 do
        local row = CreateFrame("Button",nil,f)
        row:SetSize(362,22); row:SetPoint("TOPLEFT",9,-116-(i-1)*22)
        row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
        row.icon = row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(17,17); row.icon:SetPoint("LEFT",1,0)
        row.name=text(row,11); row.name:SetPoint("LEFT",22,0); row.name:SetWidth(132); row.name:SetWordWrap(false)
        row.qty=text(row,11); row.qty:SetPoint("RIGHT",-98,0); row.qty:SetWidth(28); row.qty:SetJustifyH("RIGHT")
        row.each=text(row,11); row.each:Hide(); row.each:SetPoint("RIGHT",-94,0); row.each:SetWidth(72); row.each:SetJustifyH("RIGHT")
        row.total=text(row,11); row.total:SetPoint("RIGHT",-4,0); row.total:SetWidth(84); row.total:SetJustifyH("RIGHT")
        row:SetScript("OnClick",function()
            if not row.data or E.db.session.state=="finished" then return end
            E:EditPrice(row.data)
        end)
        row:SetScript("OnEnter",function()
            if not row.data then return end
            GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
            if row.data.link then GameTooltip:SetHyperlink(row.data.link) else GameTooltip:SetText(row.data.name) end
            GameTooltip:AddLine("Unit price: "..(row.data.unit and E.Money(row.data.unit) or "Unpriced").." / "..row.data.source,1,0.65,0.3)
            GameTooltip:AddLine("Click to set a manual unit value for this item.",0.8,0.8,0.8,true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        self.rows[i]=row
    end
    self.empty=text(f,11,{0.62,0.61,0.58}); self.empty:SetPoint("TOPLEFT",19,-137); self.empty:SetWidth(340)
    self.empty:SetText("Loot or gather to begin filling your ledger.")
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel",function(_,delta)
        E.offset = math.max(0,math.min(math.max(0,(E.rowCount or 0)-(E.visibleRows or 5)),(E.offset or 0)-delta*3)); E:Refresh()
    end)
    self.page=text(f,9,{0.57,0.56,0.53}); self.page:SetPoint("BOTTOMLEFT",11,9)

    local editor=panel(f,0.11); self.editor=editor
    editor:SetPoint("TOPLEFT",f,"BOTTOMLEFT",0,-14); editor:SetPoint("TOPRIGHT",f,"BOTTOMRIGHT",0,-14); editor:SetHeight(110)
    editor:SetFrameLevel(f:GetFrameLevel()+10); editor:EnableMouse(true); editor:Hide()
    editor.title=text(editor,12); editor.title:SetPoint("TOPLEFT",12,-10); editor.title:SetWidth(335)
    editor.inputs={}
    for i,label in ipairs({"Gold","Silver","Copper"}) do
        local field=CreateFrame("EditBox",nil,editor,"InputBoxTemplate")
        field:SetSize(88,20); field:SetPoint("TOPLEFT",18+(i-1)*108,-45)
        field:SetAutoFocus(false); field:SetNumeric(true); field:SetMaxLetters(i==1 and 7 or 2)
        field:SetScript("OnEscapePressed",function() editor:Hide() end)
        local l=text(editor,10); l:SetPoint("BOTTOMLEFT",field,"TOPLEFT",-3,3); l:SetText(label)
        editor.inputs[i]=field
    end
    local apply=button(editor,"Apply",70,function()
        local a=editor.inputs
        E:SetPrice(editor.itemID,E.Number(a[1]:GetText())*10000+E.Number(a[2]:GetText())*100+E.Number(a[3]:GetText()))
        editor:Hide(); E:Refresh()
    end)
    apply:SetPoint("TOPLEFT",12,-78)
    local vendor=button(editor,"Use source",100,function() E:SetPrice(editor.itemID,nil); editor:Hide(); E:Refresh() end)
    vendor:SetPoint("LEFT",apply,"RIGHT",5,0)
    local cancel=button(editor,"Cancel",70,function() editor:Hide() end); cancel:SetPoint("LEFT",vendor,"RIGHT",5,0)
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(350,206,720,600) end
    local grip=CreateFrame("Button",nil,f); self.resizeGrip=grip
    grip:SetSize(14,14); grip:SetPoint("BOTTOMRIGHT",-2,2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetScript("OnMouseDown",function(_,which) if which=="LeftButton" and not E.db.locked then f:StartSizing("BOTTOMRIGHT") end end)
    grip:SetScript("OnMouseUp",function() f:StopMovingOrSizing(); E:SaveDimensions() end)
    f:SetScript("OnSizeChanged",function() E:Layout(); if not E.layoutBusy then E:Refresh() end end)
    self:Layout()
    self:ApplyTheme()
    options:SetParent(f.header)

end

function E:EditPrice(row)
    local p=self.editor
    p.itemID=row.id; p.title:SetText(row.name .. " — unit price")
    local value=row.unit or 0
    p.inputs[1]:SetText(tostring(math.floor(value/10000)))
    p.inputs[2]:SetText(tostring(math.floor(value/100)%100))
    p.inputs[3]:SetText(tostring(value%100))
    p:Show()
end

function E:Refresh()
    if not self.window then return end
    if self.SyncSessionControls then self:SyncSessionControls() end
    if self.RefreshHistory then self:RefreshHistory() end
    local s=self.db.session
    local value,rate,unknown=self:Totals(s)
    self.metrics[1]:SetText(E.Duration(s.elapsed))
    self.metrics[2]:SetText(E.Money(value))
    self.metrics[3]:SetText(E.Money(rate))

    local state=({idle="Ready - start in Options",running="Tracking",paused="Paused - resume in Options",finished="Stopped - new in Options"})[s.state]
    self.status:SetText((state or "Ready") .. "  •  " .. (s.count or 0) .. " items" .. (unknown>0 and ("  •  " .. unknown .. " unpriced") or ""))
    local list={}
    for _,r in pairs(s.items) do list[#list+1]=r end
    table.sort(list,function(a,b)
        local av,bv=(a.unit or 0)*a.qty,(b.unit or 0)*b.qty
        if av~=bv then return av>bv end
        return (a.name or "")<(b.name or "")
    end)
    self.rowCount=#list
    local visible=self.visibleRows or 5
    self.offset=math.min(self.offset or 0,math.max(0,#list-visible))
    for i,row in ipairs(self.rows) do
        local data=i<=visible and list[i+self.offset] or nil; row.data=data
        if data then
            row:Show(); row.name:SetText(data.name); row.qty:SetText(tostring(data.qty))
            row.each:SetText(data.unit~=nil and E.Money(data.unit) or "Unpriced")
            row.total:SetText(data.unit~=nil and E.Money(data.unit*data.qty) or "—")
            row.icon:SetTexture(data.icon or 134400)
            local c=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[data.quality or 1]
            row.name:SetTextColor(c and c.r or 0.88,c and c.g or 0.86,c and c.b or 0.81)
        else row:Hide() end
    end
    self.empty:SetShown(#list==0)
    self.empty:SetText(s.state=="running" and "Loot or gather to fill your ledger." or "Tracking paused or stopped.")
    self.page:SetText(#list>0 and string.format("%d–%d of %d  •  Scroll",self.offset+1,math.min(#list,self.offset+visible),#list) or "No loot recorded")

end

E.UIPanel, E.UIText, E.UIButton, E.UITip = panel,text,button,tip

function E:SaveDimensions()
    self.db.width=math.floor(self.window:GetWidth()+0.5)
    self.db.height=math.floor(self.window:GetHeight()+0.5)
    if self.SyncOptions then self:SyncOptions() end
end

function E:Layout()
    if self.layoutBusy or not self.rows then return end
    self.layoutBusy=true
    local w,h=self.window:GetWidth(),self.window:GetHeight()
    local native=self.db.theme=="camelot"
    local inset=native and 14 or 9
    local shift=native and 18 or 0
    local rowTop=118-shift
    self.visibleRows=math.max(3,math.min(19,math.floor((h-rowTop-22)/22)))
    local gap=native and 4 or 3
    local metricW=(w-2*inset-2*gap)/3
    local x=inset
    for i,box in ipairs(self.metricBoxes) do
        local width=native and (i==3 and w-inset-x or math.floor(metricW)) or metricW
        box:ClearAllPoints(); box:SetPoint("TOPLEFT",x,-44+shift); box:SetSize(width,34)
        self.metrics[i]:SetWidth(width-10)
        x=x+width+gap
    end
    local columns={{inset+22,w-2*inset-147},{w-inset-126,28},{w-inset-88,84}}
    for i,header in ipairs(self.headers) do
        header:ClearAllPoints(); header:SetPoint("TOPLEFT",columns[i][1],-103+shift); header:SetWidth(columns[i][2])
    end
    for i,row in ipairs(self.rows) do
        row:SetWidth(w-2*inset); row.name:SetWidth(w-2*inset-150)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",inset,-rowTop-(i-1)*22)
    end
    self.status:ClearAllPoints(); self.status:SetPoint("TOPLEFT",native and inset or 10,-85+shift); self.status:SetWidth(native and w-2*inset or w-20)
    self.empty:ClearAllPoints(); self.empty:SetPoint("TOPLEFT",native and inset or 19,-137+shift); self.empty:SetWidth(native and w-2*inset or w-38)
    self.page:ClearAllPoints(); self.page:SetPoint("BOTTOMLEFT",native and inset or 11,9)
    self.layoutBusy=false
end
