local addonName = "TrinketTracker"
local TrinketTracker = CreateFrame("Frame", addonName)

TrinketTrackerDB = TrinketTrackerDB or {}

local DB

local trinketSlots = {13, 14}
local buttons = {}

local function ApplyButtonPositions()
    for i, btn in ipairs(buttons) do
        local slot = trinketSlots[i]
        local pos = DB and DB.positions and DB.positions[slot]
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
        else
            btn:Hide()
        end
    end
end

TrinketTracker:RegisterEvent("PLAYER_LOGIN")
TrinketTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
TrinketTracker:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
TrinketTracker:RegisterEvent("BAG_UPDATE_COOLDOWN")

TrinketTracker:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local playerKey = UnitGUID("player")

        TrinketTrackerDB[playerKey] = TrinketTrackerDB[playerKey] or {
            locked = false,
            scale = 1,
            positions = {},
            menuPos = { "CENTER", "CENTER", 0, 0 },
            showTrinket1 = true,
            showTrinket2 = true
        }

        DB = TrinketTrackerDB[playerKey]
        DB.positions = DB.positions or {}

        for _, btn in ipairs(buttons) do
            btn:SetScale(DB.scale)
        end

        ApplyButtonPositions()
        UpdateTrinkets()

    else
        UpdateTrinkets()
    end
end)

for i, slot in ipairs(trinketSlots) do
    buttons[i] = CreateTrinketButton(slot)
end

local configFrame = CreateFrame("Frame", "TrinketTrackerConfig", UIParent, "BackdropTemplate")
configFrame:SetSize(240, 180)
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

            if DB.menuPos and #DB.menuPos == 4 then
                configFrame:ClearAllPoints()
                configFrame:SetPoint(DB.menuPos[1], UIParent, DB.menuPos[2], DB.menuPos[3], DB.menuPos[4])
            end
        end
    end
end