local addonName = "TrinketTracker"
local TrinketTracker = CreateFrame("Frame", addonName)

TrinketTrackerDB = TrinketTrackerDB or {}

local DB

local trinketSlots = {13, 14}
local buttons = {}

-- TODO: fill in current-patch item IDs
-- altItemIDs lists replacement variants of the same consumable (checked before itemID).
-- Healthstone becomes Demonic Healthstone for warlocks specced into Pact of Gluttony;
-- Light's Potential Potion has two item IDs for its quality variants.
-- showCount draws how many uses you have in the corner of the button: charges for items
-- that have them (Demonic Healthstone), stack count for everything else.
local trackedItems = {
    { key = "reckless",    itemID = 241288, dbFlag = "showReckless",    label = "Potion of Recklessness",
      showCount = true },
    { key = "healthpot",   itemID = 241304, dbFlag = "showHealthPot",   label = "Health Potion",
      showCount = true },
    { key = "lightspot",   itemID = 241308, dbFlag = "showLightsPot",   label = "Light's Potential Potion",
      altItemIDs = { 241309 }, showCount = true },
    { key = "healthstone", itemID = 5512,   dbFlag = "showHealthstone", label = "Healthstone",
      altItemIDs = { 224464 }, showCount = true },
}
local itemButtons = {}

local function ApplyPosition(btn, posKey)
    local pos = DB and DB.positions and DB.positions[posKey]
    if pos and #pos == 5 then
        local point, relName, relativePoint, xOfs, yOfs = unpack(pos)
        local relFrame
        if relName == "UIParent" then
            relFrame = UIParent
        else
            relFrame = _G[relName]
        end
        if relFrame then
            btn:ClearAllPoints()
            btn:SetPoint(point, relFrame, relativePoint, xOfs, yOfs)
        end
    else
        btn:ClearAllPoints()
        btn:SetPoint("CENTER")
    end
end

local function ApplyButtonPositions()
    for i, btn in ipairs(buttons) do
        ApplyPosition(btn, trinketSlots[i])
    end
    for _, btn in ipairs(itemButtons) do
        ApplyPosition(btn, btn.posKey)
    end
end

local function CreateTrinketButton(slot)
    local btn = CreateFrame("Button", "TrinketButton"..slot, UIParent, "BackdropTemplate")
    btn:SetSize(40, 40)

    btn.icon = btn:CreateTexture(nil, "BACKGROUND")
    btn.icon:SetAllPoints()
    
    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints()

    btn.slot = slot

    local function SaveButtonPosition(self)
        if not DB then return end
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
        local relName = relativeTo and relativeTo:GetName() or "UIParent"
        DB.positions[self.slot] = { point, relName, relativePoint, xOfs, yOfs }
    end

    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        if DB and not DB.locked then
            self:StartMoving()
        end
    end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveButtonPosition(self)
    end)

    return btn
end

local function CreateItemButton(item)
    local btn = CreateFrame("Button", "TrinketItemButton"..item.itemID, UIParent, "BackdropTemplate")
    btn:SetSize(40, 40)

    btn.icon = btn:CreateTexture(nil, "BACKGROUND")
    btn.icon:SetAllPoints()

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints()

    if item.showCount then
        -- Own frame above the cooldown, otherwise the swipe covers the number.
        local countLayer = CreateFrame("Frame", nil, btn)
        countLayer:SetAllPoints()
        countLayer:SetFrameLevel(btn.cooldown:GetFrameLevel() + 1)

        btn.countText = countLayer:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        btn.countText:SetPoint("BOTTOMRIGHT", -2, 2)
        btn.countText:SetJustifyH("RIGHT")
    end

    btn.itemID = item.itemID
    btn.posKey = "item:"..item.itemID

    local function SaveButtonPosition(self)
        if not DB then return end
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
        local relName = relativeTo and relativeTo:GetName() or "UIParent"
        DB.positions[self.posKey] = { point, relName, relativePoint, xOfs, yOfs }
    end

    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        if DB and not DB.locked then
            self:StartMoving()
        end
    end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveButtonPosition(self)
    end)

    return btn
end

local function CancelCooldownAlert(btn)
    if btn.cdTimer then
        btn.cdTimer:Cancel()
        btn.cdTimer = nil
    end
    btn.cdStart = nil
    btn.cdDuration = nil
end

local function ScheduleCooldownAlert(btn, start, duration, enable)
    if btn.cdStart == start and btn.cdDuration == duration then return end
    btn.cdStart = start
    btn.cdDuration = duration
    if btn.cdTimer then
        btn.cdTimer:Cancel()
        btn.cdTimer = nil
    end
    if enable == 1 and start and start > 0 and duration and duration > 1.5 then
        local remaining = (start + duration) - GetTime()
        if remaining > 0 then
            btn.cdTimer = C_Timer.NewTimer(remaining, function()
                if DB and DB.playReadySound then
                    PlaySound(SOUNDKIT.RAID_WARNING, "Master")
                end
                btn.cdTimer = nil
            end)
        end
    end
end

local function UpdateTrinkets()
    if not DB then return end

    for i, slot in ipairs(trinketSlots) do
        local itemID = GetInventoryItemID("player", slot)
        local texture = GetInventoryItemTexture("player", slot)
        local btn = buttons[i]
        local showTrinket = (i == 1 and DB.showTrinket1) or (i == 2 and DB.showTrinket2)

        if itemID and texture and showTrinket then
            btn.icon:SetTexture(texture)
            btn:Show()

            local start, duration, enable = GetInventoryItemCooldown("player", slot)
            CooldownFrame_Set(btn.cooldown, start, duration, enable)
            ScheduleCooldownAlert(btn, start, duration, enable)
        else
            btn:Hide()
            CancelCooldownAlert(btn)
        end
    end
end

-- With includeUses set, GetItemCount reports total charges instead of item count, so a
-- single 3-charge Demonic Healthstone reads 3. Items without charges are unaffected.
local function CountFor(itemID)
    return C_Item.GetItemCount(itemID, false, true) or 0
end

-- Returns the item ID the player actually carries for this entry, and how many uses it has.
local function ResolveItemID(item)
    if item.altItemIDs then
        for _, id in ipairs(item.altItemIDs) do
            local count = CountFor(id)
            if count > 0 then return id, count end
        end
    end
    local count = item.itemID > 0 and CountFor(item.itemID) or 0
    return item.itemID, count
end

local function UpdateItems()
    if not DB then return end

    for i, item in ipairs(trackedItems) do
        local btn = itemButtons[i]
        if not btn then break end

        local itemID, count = ResolveItemID(item)
        if count > 0 and DB[item.dbFlag] then
            btn.icon:SetTexture(C_Item.GetItemIconByID(itemID))
            if btn.countText then
                btn.countText:SetText(count)
            end
            local start, duration, enable = C_Container.GetItemCooldown(itemID)
            CooldownFrame_Set(btn.cooldown, start, duration, enable)
            btn:Show()
        else
            btn:Hide()
        end
    end
end

TrinketTracker:RegisterEvent("PLAYER_LOGIN")
TrinketTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
TrinketTracker:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
TrinketTracker:RegisterEvent("BAG_UPDATE_COOLDOWN")
TrinketTracker:RegisterEvent("BAG_UPDATE")
TrinketTracker:RegisterEvent("SPELL_UPDATE_COOLDOWN")

TrinketTracker:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local playerKey = UnitGUID("player")

        TrinketTrackerDB[playerKey] = TrinketTrackerDB[playerKey] or {
            locked = false,
            scale = 1,
            positions = {},
            menuPos = { "CENTER", "CENTER", 0, 0 },
            showTrinket1 = true,
            showTrinket2 = true,
            showReckless = true,
            showHealthPot = true,
            showLightsPot = true,
            showHealthstone = true,
            playReadySound = true,
        }

        DB = TrinketTrackerDB[playerKey]
        DB.positions = DB.positions or {}
        if DB.showReckless    == nil then DB.showReckless    = true end
        if DB.showHealthPot   == nil then DB.showHealthPot   = true end
        if DB.showLightsPot   == nil then DB.showLightsPot   = true end
        if DB.showHealthstone == nil then DB.showHealthstone = true end
        if DB.playReadySound  == nil then DB.playReadySound  = true end

        for _, btn in ipairs(buttons) do
            btn:SetScale(DB.scale)
        end
        for _, btn in ipairs(itemButtons) do
            btn:SetScale(DB.scale)
        end

        ApplyButtonPositions()
        UpdateTrinkets()
        UpdateItems()

    else
        UpdateTrinkets()
        UpdateItems()
    end
end)

for i, slot in ipairs(trinketSlots) do
    buttons[i] = CreateTrinketButton(slot)
end

for i, item in ipairs(trackedItems) do
    itemButtons[i] = CreateItemButton(item)
end

local configFrame = CreateFrame("Frame", "TrinketTrackerConfig", UIParent, "BackdropTemplate")
configFrame:SetSize(240, 305)
configFrame:SetMovable(true)
configFrame:EnableMouse(true)
configFrame:RegisterForDrag("LeftButton")
configFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
configFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if not DB then return end
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    DB.menuPos = { point, relativePoint, xOfs, yOfs }
    print("Menu Position gespeichert:", unpack(DB.menuPos))
end)

configFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
configFrame:SetBackdropColor(0, 0, 0, 0.7)
configFrame:SetBackdropBorderColor(1, 0.82, 0, 1)
configFrame:SetClampedToScreen(true)
configFrame:SetFrameStrata("DIALOG")

local closeBtn = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -5, -5)
closeBtn:SetScript("OnClick", function() configFrame:Hide() end)

local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -10)
title:SetTextColor(1, 0.82, 0)
title:SetText("TrinketTracker")

local lockCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
lockCheck:SetPoint("TOPLEFT", 20, -40)
lockCheck.text:SetText("Lock Position")
lockCheck:SetScript("OnClick", function(self)
    if not DB then return end
    DB.locked = self:GetChecked()
end)

local slider = CreateFrame("Slider", nil, configFrame, "OptionsSliderTemplate")
slider:SetPoint("TOP", 0, -80)
slider:SetMinMaxValues(0.5, 2)
slider:SetValueStep(0.1)
slider:SetObeyStepOnDrag(true)
slider:SetWidth(160)
slider:SetScript("OnValueChanged", function(self, value)
    if not DB then return end
    DB.scale = value
    for _, btn in ipairs(buttons) do
        btn:SetScale(value)
    end
    for _, btn in ipairs(itemButtons) do
        btn:SetScale(value)
    end
end)
if slider.Low then slider.Low:SetText("0.5") end
if slider.High then slider.High:SetText("2") end
if slider.Text then slider.Text:SetText("Scale") end

local showTrinket1Check = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
showTrinket1Check:SetPoint("TOPLEFT", 20, -115)
showTrinket1Check.text:SetText("Show Trinket 1")
showTrinket1Check:SetScript("OnClick", function(self)
    if not DB then return end
    DB.showTrinket1 = self:GetChecked()
    UpdateTrinkets()
end)

local showTrinket2Check = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
showTrinket2Check:SetPoint("TOPLEFT", 20, -140)
showTrinket2Check.text:SetText("Show Trinket 2")
showTrinket2Check:SetScript("OnClick", function(self)
    if not DB then return end
    DB.showTrinket2 = self:GetChecked()
    UpdateTrinkets()
end)

local showRecklessCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
showRecklessCheck:SetPoint("TOPLEFT", 20, -165)
showRecklessCheck.text:SetText("Show Recklessness Potion")
showRecklessCheck:SetScript("OnClick", function(self)
    if not DB then return end
    DB.showReckless = self:GetChecked()
    UpdateItems()
end)

local showHealthPotCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
showHealthPotCheck:SetPoint("TOPLEFT", 20, -190)
showHealthPotCheck.text:SetText("Show Health Potion")
showHealthPotCheck:SetScript("OnClick", function(self)
    if not DB then return end
    DB.showHealthPot = self:GetChecked()
    UpdateItems()
end)

local showLightsPotCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
showLightsPotCheck:SetPoint("TOPLEFT", 20, -215)
showLightsPotCheck.text:SetText("Show Light's Potential Potion")
showLightsPotCheck:SetScript("OnClick", function(self)
    if not DB then return end
    DB.showLightsPot = self:GetChecked()
    UpdateItems()
end)

local showHealthstoneCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
showHealthstoneCheck:SetPoint("TOPLEFT", 20, -240)
showHealthstoneCheck.text:SetText("Show Healthstone")
showHealthstoneCheck:SetScript("OnClick", function(self)
    if not DB then return end
    DB.showHealthstone = self:GetChecked()
    UpdateItems()
end)

local playReadySoundCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
playReadySoundCheck:SetPoint("TOPLEFT", 20, -265)
playReadySoundCheck.text:SetText("Play Sound When Trinket Ready")
playReadySoundCheck:SetScript("OnClick", function(self)
    if not DB then return end
    DB.playReadySound = self:GetChecked()
end)

configFrame:Hide()

SLASH_TRINKETTRACKER1 = "/trinket"
SlashCmdList["TRINKETTRACKER"] = function()
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        configFrame:Show()
        if DB then
            lockCheck:SetChecked(DB.locked)
            slider:SetValue(DB.scale)
            showTrinket1Check:SetChecked(DB.showTrinket1)
            showTrinket2Check:SetChecked(DB.showTrinket2)
            showRecklessCheck:SetChecked(DB.showReckless)
            showHealthPotCheck:SetChecked(DB.showHealthPot)
            showLightsPotCheck:SetChecked(DB.showLightsPot)
            showHealthstoneCheck:SetChecked(DB.showHealthstone)
            playReadySoundCheck:SetChecked(DB.playReadySound)

            if DB.menuPos and #DB.menuPos == 4 then
                configFrame:ClearAllPoints()
                configFrame:SetPoint(DB.menuPos[1], UIParent, DB.menuPos[2], DB.menuPos[3], DB.menuPos[4])
            end
        end
    end
end