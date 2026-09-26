-- Copyright (c) 2026 Hitshade
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local addon, E = ...
EmberLedgerForever = E
E.offset = 0

local function readable(value)
    return not (issecretvalue and issecretvalue(value))
end

function E:PriceRow(row, force)
    local keepPrice = row.unit ~= nil and not force
    if keepPrice and not row.pendingName then return end
    local getter = C_Item and C_Item.GetItemInfo or GetItemInfo
    local name, link, quality, icon, sell, bindType
    if getter then
        local ok, n, l, q, _, _, _, _, _, _, texture, price, _, _, binding = pcall(getter, row.link or row.id)
        if ok and readable(n) and readable(price) then
            name, link, quality, icon, sell, bindType = n, l, q, texture, price, binding
        end
    end
    row.pendingName = not name
    if name then row.name, row.link, row.quality, row.icon = name, link or row.link, quality, icon end
    if keepPrice then return end
    local override = self.db.prices[row.id]
    if override ~= nil then row.unit, row.source = override, "Manual"
    elseif name and type(sell) == "number" then
        local price, source = self:MarketPrice(row.id, bindType)
        row.unit, row.source = price or E.Number(sell), source or "Vendor"
    else
        row.unit, row.source = nil, "Unpriced"
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, row.id) end
    end
end

function E:MarketPrice(id, bindType)
    if bindType==1 or bindType==4 then return nil end
    local mode=self.db.pricing or "auto"
    local function positive(ok,value)
        return ok and readable(value) and type(value)=="number" and value>0 and value<math.huge
    end
    if (mode=="auto" or mode=="tsm") and TSM_API and type(TSM_API.GetCustomPriceValue)=="function" then
        local ok,value=pcall(TSM_API.GetCustomPriceValue,"dbmarket","i:"..id)
        if positive(ok,value) then return E.Number(value),"TSM" end
    end
    if (mode=="auto" or mode=="auctionator") and Auctionator then
        local api=Auctionator.API and Auctionator.API.v1
        if api and type(api.GetAuctionPriceByItemID)=="function" then
            local ok,value=pcall(api.GetAuctionPriceByItemID,"EmberLedgerForever",id)
            if positive(ok,value) then return E.Number(value),"Auctionator" end
        end
        local database=Auctionator.Database
        if database and type(database.GetPrice)=="function" then
            local ok,value=pcall(database.GetPrice,database,tostring(id))
            if positive(ok,value) then return E.Number(value),"Auctionator" end
        end
    end
end

function E:RepriceSession()
    if not self.db or self.db.session.state=="finished" then return end
    for _,row in pairs(self.db.session.items) do self:PriceRow(row,true) end
    self:Refresh()
end

function E:SetPrice(id, copper)
    self.db.prices[id] = copper ~= nil and E.Number(copper) or nil
    if self.db.session.state ~= "finished" then
        for _, row in pairs(self.db.session.items) do
            if row.id == id then self:PriceRow(row, true) end
        end
    end
end

function E:BuildPatterns()
    self.lootPatterns, self.moneyPatterns, self.coinPatterns = {}, {}, {}
    for _, key in ipairs({"LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF"}) do
        local p = E.FormatPattern(_G[key])
        if p then self.lootPatterns[#self.lootPatterns+1] = p end
    end
    for _, key in ipairs({"YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT", "YOU_LOOT_MONEY_GUILD", "LOOT_MONEY_SPLIT_GUILD"}) do
        local p = E.FormatPattern(_G[key])
        if p then self.moneyPatterns[#self.moneyPatterns+1] = p end
    end
    for _, data in ipairs({{"GOLD_AMOUNT",10000},{"SILVER_AMOUNT",100},{"COPPER_AMOUNT",1}}) do
        local p = E.FormatPattern(_G[data[1]])
        if p then
            p.pattern = p.pattern:sub(2,-2)
            p.value = data[2]
            self.coinPatterns[#self.coinPatterns+1] = p
        end
    end
    self.seen, self.seenOrder = {}, {}
end

function E:TransferOpen()
    for _, name in ipairs({"MerchantFrame", "MailFrame", "BankFrame", "BankPanel", "GuildBankFrame", "TradeFrame", "AuctionHouseFrame", "AuctionFrame"}) do
        local frame = _G[name]
        if frame and frame.IsVisible and frame:IsVisible() then return true end
    end
    return false
end

function E:SeenLine(event, lineID)
    if not readable(lineID) or type(lineID) ~= "number" or lineID <= 0 then return false end
    local key = event .. ":" .. lineID
    if self.seen[key] then return true end
    self.seen[key] = true
    self.seenOrder[#self.seenOrder+1] = key
    if #self.seenOrder > 256 then self.seen[table.remove(self.seenOrder, 1)] = nil end
    return false
end

function E:LootMessage(message)
    for _, pattern in ipairs(self.lootPatterns) do
        local args = E.Match(pattern, message)
        if args then
            local link = args[1]
            local key = link and link:match("|H(item:[^|]+)|h")
            local id = key and tonumber(key:match("^item:(%d+)"))
            if id then self:CreditLoot("chat", key, id, link, tonumber(args[2]) or 1) end
            return
        end
    end
    self.diagnostics = self.diagnostics or {chat=0,bag=0,unmatched=0,blocked=0}
    self.diagnostics.unmatched = self.diagnostics.unmatched + 1
end

function E:MoneyMessage(message)
    for _, pattern in ipairs(self.moneyPatterns) do
        local args = E.Match(pattern, message)
        if args and args[1] then
            local copper = 0
            for _, coin in ipairs(self.coinPatterns) do
                local result = E.Match(coin, args[1])
                if result then copper = copper + E.Number(result[1]) * coin.value end
            end
            self:AddCoin(copper)
            return
        end
    end
end

function E:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= addon then
            if self.db and (loaded=="Auctionator" or loaded=="TradeSkillMaster") then self:RepriceSession() end
            return
        end
        self:InitDB()
        self:BuildPatterns()
        self:ResetLootBaseline()
        self:CreateUI()
        self:InitBroker()
        if not self.db.hidden then self.window:Show() end
        self:RepriceSession()
        self:Refresh()
        return
    end
    if not self.db then return end
    if event == "PLAYER_LOGOUT" then
        local resume = self.db.session.state == "running"
        self:Pause()
        self.db.resumeAfterReload = resume
    elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
        self:CaptureLoot()
    elseif event == "LOOT_CLOSED" then
        self:ReconcileBags()
        self.lootOpen = false
        self.lootExpires = GetTime() + 3
    elseif event == "AUCTION_HOUSE_CLOSED" then
        self:RepriceSession()
    elseif event == "BAG_UPDATE_DELAYED" then
        self:ReconcileBags()
    elseif event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_MONEY" then
        local message = ...
        if self.db.session.state ~= "running" or not readable(message) or type(message) ~= "string" or self:TransferOpen() then return end
        if self:SeenLine(event, select(11,...)) then return end
        if event == "CHAT_MSG_LOOT" then self:LootMessage(message) else self:MoneyMessage(message) end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local id, success = ...
        if success and readable(id) and self.db.session.state ~= "finished" then
            for _, row in pairs(self.db.session.items) do
                if row.id == id and (row.source == "Unpriced" or row.pendingName) then self:PriceRow(row) end
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        local login, reload = ...
        if not self.enteredWorld then
            self.enteredWorld = true
            self:BuildPatterns()
            self:ResetLootBaseline()
            if not reload then self:New(); self:Start()
            elseif self.db.resumeAfterReload ~= false and self.db.session.state ~= "finished" then self:Start() end
        else self:ResetLootBaseline() end
        if self.db.session.state ~= "finished" then
            for _, row in pairs(self.db.session.items) do if row.unit == nil then self:PriceRow(row) end end
        end
    end
    self:Refresh()
end

local events = CreateFrame("Frame")
E.events = events
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGOUT", "PLAYER_ENTERING_WORLD", "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "GET_ITEM_INFO_RECEIVED", "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED", "BAG_UPDATE_DELAYED", "AUCTION_HOUSE_CLOSED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, ...) E:OnEvent(event, ...) end)
local elapsed = 0
events:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 1 or not E.db then return end
    elapsed = 0
    E:Tick(GetTime())
    if E.window then E:Refresh() end
end)

SLASH_EMBERLEDGERFOREVER1 = "/elf"
SLASH_EMBERLEDGERFOREVER2 = "/emberforever"
SlashCmdList.EMBERLEDGERFOREVER = function(message)
    if not E.db then return end
    message = (message or ""):lower():match("^%s*(.-)%s*$")
    if message=="history" then E:ToggleHistory(); return end
    if message=="options" then E:ToggleOptions(); return end
    if message == "debug" then
        local d=E.diagnostics or {}
        print("EmberLedger "..E.VERSION..": "..E.db.session.state..", patterns="..#E.lootPatterns..", transfer="..tostring(E:TransferOpen())..", chat items="..(d.chat or 0)..", bag items="..(d.bag or 0)..", unmatched="..(d.unmatched or 0))
        return
    end
    if message == "resetpos" then
        E.db.position = nil
        E.db.scale = 1
        E.window:SetScale(1)
        E.window:ClearAllPoints()
        E.window:SetPoint("CENTER")
    end
    E.db.hidden = false
    E.window:Show()
    E:Refresh()
end
