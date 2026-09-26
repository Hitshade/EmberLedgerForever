-- Copyright (c) 2026 Hitshade
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local _, E = ...
E.VERSION = "0.5.0"

function E.Number(value, fallback)
    if issecretvalue and issecretvalue(value) then return fallback or 0 end
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return fallback or 0 end
    return math.max(0, math.floor(n))
end

function E.Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = E.Copy(v) end
    return out
end

function E.NewSession()
    return {state="idle", elapsed=0, coin=0, items={}, started=time(), count=0}
end

function E:InitDB()
    local db = type(EmberLedgerForeverDB) == "table" and EmberLedgerForeverDB or {}
    EmberLedgerForeverDB = db
    db.version = 1
    db.minimap=type(db.minimap)=="table" and db.minimap or {}
    db.minimap.hide=db.minimap.hide==true
    db.minimap.minimapPos=E.Number(db.minimap.minimapPos,225)%360
    db.prices = type(db.prices) == "table" and db.prices or {}
    for id, price in pairs(db.prices) do
        if type(id) ~= "number" or type(price) ~= "number" or price < 0 or price ~= price then
            db.prices[id] = nil
        else db.prices[id] = E.Number(price) end
    end
    db.history = type(db.history) == "table" and db.history or {}
    local clean = {}
    for _, s in ipairs(db.history) do
        if type(s) == "table" and type(s.items) == "table" and type(s.elapsed) == "number" then
            clean[#clean+1] = s
            if #clean == 20 then break end
        end
    end
    db.history = clean
    local s = db.session
    if type(s) ~= "table" or type(s.items) ~= "table" then s = E.NewSession() end
    s.elapsed, s.coin = E.Number(s.elapsed), E.Number(s.coin)
    s.count = 0
    for key, row in pairs(s.items) do
        if type(key) ~= "string" or type(row) ~= "table" or type(row.id) ~= "number" then
            s.items[key] = nil
        else
            row.qty = E.Number(row.qty)
            row.unit = row.unit ~= nil and E.Number(row.unit) or nil
            row.name = type(row.name) == "string" and row.name or ("Item " .. row.id)
            row.source = type(row.source) == "string" and row.source or "Unpriced"
            s.count = s.count + row.qty
        end
    end
    if s.state ~= "idle" and s.state ~= "finished" then s.state = "paused" end
    db.session = s
    db.scale = math.min(1.5, math.max(0.65, tonumber(db.scale) or 1))
    if not db.compactLayout then
        db.width,db.height=350,206
        db.compactLayout=true
    end
    if not db.cleanHeaderLayout then
        if db.height==220 then db.height=206 end
        db.cleanHeaderLayout=true
    end
    if db.height==198 then db.height=206 end
    db.width = math.min(720, math.max(350, E.Number(db.width,350)))
    db.height = math.min(600, math.max(206, E.Number(db.height,206)))
    db.opacity = math.min(1, math.max(0.15, tonumber(db.opacity) or 0.95))
    if not ({modern=true,camelot=true,classic=true})[db.theme] then db.theme="modern" end
    if not ({auto=true,tsm=true,auctionator=true,vendor=true})[db.pricing] then db.pricing="auto" end
    self.db, self.lastTick = db, nil
end

function E:Tick(now)
    local s = self.db.session
    if s.state == "running" and self.lastTick then
        s.elapsed = s.elapsed + math.max(0, now - self.lastTick)
    end
    self.lastTick = now
end

function E:Start()
    local s = self.db.session
    if s.state == "finished" then return end
    s.state = "running"
    self.lastTick = GetTime()
    self.view = nil
    self.db.resumeAfterReload = true
    if self.ResetLootBaseline then self:ResetLootBaseline() end
end

function E:Pause()
    self:Tick(GetTime())
    if self.db.session.state == "running" then self.db.session.state = "paused" end
    self.db.resumeAfterReload = false
    if self.ResetLootBaseline then self:ResetLootBaseline() end
end

function E:Finish()
    local s = self.db.session
    if s.state == "finished" or s.state == "idle" then return end
    self:Pause()
    s.state, s.finished = "finished", time()
    if s.count > 0 or s.coin > 0 then
        table.insert(self.db.history, 1, E.Copy(s))
        while #self.db.history > 20 do table.remove(self.db.history) end
    end
end

function E:New()
    self:Finish()
    self.db.session = E.NewSession()
    self.view, self.offset, self.lastTick = nil, 0, nil
end

function E:AddLoot(key, id, link, qty)
    local s = self.db.session
    if s.state ~= "running" then return end
    qty = E.Number(qty)
    if qty < 1 then return end
    local row = s.items[key]
    if not row then
        row = {id=id, link=link, qty=0, name="Item " .. id, source="Unpriced"}
        s.items[key] = row
        self:PriceRow(row)
    end
    row.qty, s.count = row.qty + qty, s.count + qty
end

function E:AddCoin(copper)
    local s = self.db.session
    if s.state == "running" then s.coin = s.coin + E.Number(copper) end
end

function E:Totals(s)
    local value, unpriced = s.coin or 0, 0
    for _, row in pairs(s.items) do
        if row.unit ~= nil then value = value + row.qty * row.unit
        else unpriced = unpriced + row.qty end
    end
    local elapsed = tonumber(s.elapsed) or 0
    return value, elapsed > 0 and math.floor(value * 3600 / elapsed) or 0, unpriced
end

function E.Money(copper)
    copper = E.Number(copper)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then return string.format("%dg %02ds %02dc", g, s, c) end
    if s > 0 then return string.format("%ds %02dc", s, c) end
    return c .. "c"
end

function E.Duration(seconds)
    seconds = E.Number(seconds)
    return string.format("%02d:%02d:%02d", math.floor(seconds/3600), math.floor(seconds/60)%60, seconds%60)
end

-- Compile Blizzard's localized printf strings, including positional placeholders.
function E.FormatPattern(formatString)
    if type(formatString) ~= "string" then return nil end
    local result, captures, i, nextArg = {"^"}, {}, 1, 1
    while i <= #formatString do
        local tail = formatString:sub(i)
        local token, pos, kind = tail:match("^(%%(%d+)%$([sd]))")
        if not token then token, kind = tail:match("^(%%([sd]))") end
        if token then
            captures[#captures+1] = {arg=tonumber(pos) or nextArg, kind=kind}
            nextArg = nextArg + 1
            result[#result+1] = kind == "d" and "(%d+)" or "(.-)"
            i = i + #token
        else
            local ch = formatString:sub(i,i)
            if ch == "%" and formatString:sub(i+1,i+1) == "%" then i = i + 1 end
            result[#result+1] = ch:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            i = i + 1
        end
    end
    result[#result+1] = "$"
    return {pattern=table.concat(result), captures=captures}
end

function E.Match(format, message)
    if not format then return nil end
    local values = {message:match(format.pattern)}
    if #values == 0 then return nil end
    local args = {}
    for i, capture in ipairs(format.captures) do args[capture.arg] = values[i] end
    return args
end
