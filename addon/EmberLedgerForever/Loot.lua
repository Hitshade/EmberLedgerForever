-- Copyright (c) 2026 Hitshade
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local _, E = ...
local function safe(v) return not (issecretvalue and issecretvalue(v)) end

function E:BagCounts()
    if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo then return nil end
    local counts = {}
    for bag=0,(NUM_BAG_SLOTS or 4) do
        local ok,n = pcall(C_Container.GetContainerNumSlots,bag)
        if not ok or not safe(n) or type(n)~="number" then return nil end
        for slot=1,n do
            local success,info = pcall(C_Container.GetContainerItemInfo,bag,slot)
            if not success then return nil end
            if info then
                if not safe(info) or not safe(info.itemID) or not safe(info.stackCount) then return nil end
                if info.itemID then counts[info.itemID]=(counts[info.itemID] or 0)+E.Number(info.stackCount) end
            end
        end
    end
    return counts
end

function E:ResetLootBaseline()
    self.bagCounts = self:BagCounts()
    self.lootCandidates, self.crossCredits = {}, {}
    self.lootOpen, self.lootExpires = false, 0
end

-- Pair chat and confirmed bag quantities in either event order.
function E:CreditLoot(source,key,id,link,qty)
    if self.db.session.state~="running" then return end
    local now=GetTime()
    for itemID,credits in pairs(self.crossCredits) do
        for _,channel in ipairs({"chat","bag"}) do
            for i=#credits[channel],1,-1 do
                if credits[channel][i].untilTime<now then table.remove(credits[channel],i) end
            end
        end
        if #credits.chat==0 and #credits.bag==0 then self.crossCredits[itemID]=nil end
    end
    local entry=self.crossCredits[id]
    if not entry then entry={chat={},bag={}}; self.crossCredits[id]=entry end
    local other=entry[source=="chat" and "bag" or "chat"]
    local remaining=qty
    for i=#other,1,-1 do if other[i].untilTime<now then table.remove(other,i) end end
    while remaining>0 and #other>0 do
        local used=math.min(remaining,other[1].qty)
        remaining=remaining-used; other[1].qty=other[1].qty-used
        if other[1].qty==0 then table.remove(other,1) end
    end
    if remaining>0 then
        self:AddLoot(key,id,link,remaining)
        self.diagnostics = self.diagnostics or {chat=0,bag=0,unmatched=0,blocked=0}
        self.diagnostics[source] = self.diagnostics[source] + remaining
        table.insert(entry[source],{qty=remaining,untilTime=now+5})
    end
end

function E:CaptureLoot()
    if self.db.session.state~="running" or self:TransferOpen() then return end
    if not GetNumLootItems or not GetLootSlotLink or not GetLootSlotInfo then return end
    if not self.lootOpen then self.lootCandidates={}; self.lootOpen=true end
    local ok,n=pcall(GetNumLootItems)
    if not ok or not safe(n) or type(n)~="number" then return end
    local found={}
    for slot=1,n do
        local good,link=pcall(GetLootSlotLink,slot)
        if good and safe(link) and type(link)=="string" then
            local key=link:match("|H(item:[^|]+)|h")
            local id=key and tonumber(key:match("^item:(%d+)"))
            local info,_,_,quantity=pcall(GetLootSlotInfo,slot)
            if id and info and safe(quantity) and type(quantity)=="number" then
                local row=found[id] or {key=key,id=id,link=link,qty=0}
                row.qty=row.qty+quantity; found[id]=row
            end
        end
    end
    for id,row in pairs(found) do
        if not self.lootCandidates[id] then self.lootCandidates[id]=row end
    end
    self.lootExpires=GetTime()+30
end

function E:ReconcileBags()
    local counts=self:BagCounts()
    if not counts then self.bagCounts=nil; return end
    local before=self.bagCounts
    self.bagCounts=counts
    if not before or self.db.session.state~="running" then return end
    if self:TransferOpen() then self.lootCandidates={}; self.crossCredits={}; return end
    if not self.lootOpen and GetTime()>self.lootExpires then self.lootCandidates={}; return end
    for id,row in pairs(self.lootCandidates) do
        local gained=math.min(row.qty,math.max(0,(counts[id] or 0)-(before[id] or 0)))
        if gained>0 then
            self:CreditLoot("bag",row.key,id,row.link,gained)
            row.qty=row.qty-gained
        end
    end
end
