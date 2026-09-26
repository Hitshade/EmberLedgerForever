now=100
function GetTime() return now end
function time() return 1790340000 + math.floor(now) end
date=os.date
function issecretvalue(v) return type(v)=='table' and v.secret end
SlashCmdList={}
STANDARD_TEXT_FONT='Fonts/test.ttf'
ITEM_QUALITY_COLORS={[1]={r=1,g=1,b=1}}
LOOT_ITEM_SELF='You receive loot: %s.'
LOOT_ITEM_SELF_MULTIPLE='You receive loot: %sx%d.'
LOOT_ITEM_PUSHED_SELF='You receive item: %s.'
LOOT_ITEM_PUSHED_SELF_MULTIPLE='You receive item: %sx%d.'
YOU_LOOT_MONEY='You loot %s'
LOOT_MONEY_SPLIT='Your share of the loot is %s.'
YOU_LOOT_MONEY_GUILD='You loot %s (%s deposited to guild bank)'
LOOT_MONEY_SPLIT_GUILD='Your share of the loot is %s. (%s deposited to guild bank)'
GOLD_AMOUNT='%d Gold'; SILVER_AMOUNT='%d Silver'; COPPER_AMOUNT='%d Copper'
local function noop() end
local methods={}
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:RegisterEvent(e) self.registered[e]=true end
function methods:SetText(t) self.text=t end
function methods:GetText() return self.text or '' end
function methods:SetSize(w,h) self.width,self.height=w,h; if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,w,h) end end
function methods:GetWidth() return self.width or 380 end
function methods:GetHeight() return self.height or 278 end
function methods:GetFontString() if not self.fontString then self.fontString=CreateFrame('FontString',nil,self) end; return self.fontString end
function methods:SetFontString(v) self.fontString=v end
function methods:SetHighlightTexture(v) self.highlight=CreateFrame('Texture',nil,self); self.highlight.path=v end
function methods:GetHighlightTexture() return self.highlight end
function methods:SetNormalTexture(t) assert(t~=nil,'SetNormalTexture requires an asset'); self.normalTexture=self.normalTexture or CreateFrame('Texture',nil,self); self.normalTexture.path=t end
function methods:GetNormalTexture() return self.normalTexture end
function methods:SetPushedTexture(t) assert(t~=nil,'SetPushedTexture requires an asset'); self.pushedTexture=self.pushedTexture or CreateFrame('Texture',nil,self); self.pushedTexture.path=t end
function methods:GetPushedTexture() return self.pushedTexture end
function methods:SetCheckedTexture(t) self.checkedTexture=CreateFrame('Texture',nil,self); self.checkedTexture.path=t end
function methods:GetCheckedTexture() return self.checkedTexture end
function methods:SetThumbTexture(t) self.thumb=CreateFrame('Texture',nil,self); self.thumb.path=t end
function methods:GetThumbTexture() return self.thumb end
function methods:SetAtlas(name,useSize) self.atlas=name; self.useAtlasSize=useSize end
function methods:SetDrawLayer(layer,level) self.layer=layer; self.subLevel=level end
function methods:SetColorTexture(...) self.color={...} end
function methods:SetVertexColor(...) self.color={...} end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:SetValue(v) local old=self.value; self.value=v; if old~=v and self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end end
function methods:SetBackdrop(v) self.backdrop=v end
function methods:SetBackdropColor(...) self.bg={...} end
function methods:SetBackdropBorderColor(...) self.border={...} end
function methods:SetAlpha(v) self.alpha=v end
function methods:SetHeight(h) self.height=h end
function methods:SetWidth(w) self.width=w end
function methods:SetPoint(...) self.point={...} end
function methods:SetScale(n) self.scale=n end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:GetCenter() return 500,500 end
function methods:GetFrameLevel() return self.frameLevel or (self.parent and self.parent:GetFrameLevel()+1) or 1 end
function methods:SetFrameLevel(v) self.frameLevel=v end
function methods:SetPushedTextOffset(x,y) self.pushX,self.pushY=x,y end
function methods:SetJustifyH(v) self.justifyH=v end
function methods:SetJustifyV(v) self.justifyV=v end
function methods:SetParent(v) self.parent=v end
function methods:GetParent() return self.parent end
function methods:CreateAnimationGroup() return CreateFrame("Frame",nil,self) end
function methods:CreateAnimation() return CreateFrame("Frame",nil,self) end
function methods:SetTexture(path) self.path=path; self.atlas=nil end
function methods:GetVertexColor() return unpack(self.color or {1,1,1,1}) end
function methods:SetEnabled(v) self.enabled=v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:CreateTexture() return CreateFrame('Texture',nil,self) end
function methods:CreateMaskTexture() return CreateFrame('Texture',nil,self) end
function methods:CreateFontString() return CreateFrame('FontString',nil,self) end
frames={}
function CreateFrame(kind,name,parent,template)
 local f=setmetatable({kind=kind,name=name,parent=parent,template=template,scripts={},registered={},shown=true}, {__index=function(_,k) if k:match('Corner$') or k:match('Edge$') or k=='Center' then return nil end; return methods[k] or (k:match('^%u') and noop or nil) end})
 frames[#frames+1]=f
 if name then _G[name]=f end
 return f
end
UIParent=CreateFrame('Frame'); GameTooltip=CreateFrame('Frame')
catalog={[1]={name='Peacebloom',price=7},[2]={name='Worn Sword',price=103},[3]={name='Quest Token',price=0}}
C_Item={}
function C_Item.GetItemInfo(ref)
 local id=tonumber(ref) or tonumber(ref:match('item:(%d+)'))
 local r=catalog[id]
 if not r then return nil end
 return r.name, '|cffffffff|Hitem:'..id..':0|h['..r.name..']|h|r',1,1,1,'Misc','Junk',20,'',134400,r.price
end
requested={}
function C_Item.RequestLoadItemDataByID(id) requested[id]=true end
function link(id) return '|cffffffff|Hitem:'..id..':0|h[Test]|h|r' end
function loot(id,qty,lineID)
 local msg=qty==1 and string.format(LOOT_ITEM_SELF,link(id)) or string.format(LOOT_ITEM_SELF_MULTIPLE,link(id),qty)
 EmberLedgerForever:OnEvent('CHAT_MSG_LOOT',msg,nil,nil,nil,nil,nil,nil,nil,nil,nil,lineID)
end
function money(msg,lineID) EmberLedgerForever:OnEvent('CHAT_MSG_MONEY',msg,nil,nil,nil,nil,nil,nil,nil,nil,nil,lineID) end
function advance(n) now=now+n; EmberLedgerForever.events.scripts.OnUpdate(nil,n) end
bags={}
C_Container={GetContainerNumSlots=function(bag) return bag==0 and #bags or 0 end, GetContainerItemInfo=function(bag,slot) return bags[slot] end}
lootSlots={}
function GetNumLootItems() return #lootSlots end
function GetLootSlotLink(slot) return link(lootSlots[slot].id) end
function GetLootSlotInfo(slot) return 134400,'Leather',lootSlots[slot].qty end
