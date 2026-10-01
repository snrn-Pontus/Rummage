local _, ns = ...
local Rummage = ns.core

-- The Rummage window (/rum): one row per category with the current item's
-- icon, the enable toggle and the stat priority. Drag an icon onto any
-- action slot to place that category's macro. Plain movable frame driven by
-- the mouse; it is never handed to the gamepad cursor.

ns.window = {}
local frame
local rows = {}

local ICON_SIZE = 36
local ROW_HEIGHT = 58
local WIDTH = 520

local function GetItemIcon(itemID)
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID)
    end
    if GetItemIcon then
        return GetItemIcon(itemID)
    end
    return nil
end

local function PickupCategoryMacro(key)
    SlashCmdList.RUMMAGE("pickup " .. key)
end

local function ShowCandidateTooltip(button, key)
    local category = Rummage.GetCategory(key)
    local list = Rummage.candidates[key] or {}
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(category.label .. " (" .. category.macroName .. ")", 1, 1, 1)
    if #list == 0 then
        GameTooltip:AddLine("Nothing suitable in your bags.", 0.8, 0.8, 0.8, true)
    else
        for index, candidate in ipairs(list) do
            if index > 8 then
                GameTooltip:AddLine(string.format("... and %d more", #list - 8), 0.6, 0.6, 0.6)
                break
            end
            local text = category.Describe and category.Describe(candidate) or (candidate.link or candidate.name)
            local r, g, b = 0.8, 0.8, 0.8
            if candidate == Rummage.currentPick[key] then
                r, g, b = 0.5, 1, 0.5
            elseif not candidate.usable then
                r, g, b = 1, 0.5, 0.5
                text = text .. string.format(" (%s)", candidate.unusableReason or ("level " .. candidate.minLevel))
            end
            GameTooltip:AddLine(string.format("%d. %s x%d", index, text, candidate.count), r, g, b, true)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Drag or click the icon to put the macro on your cursor, then click an action slot.", 0.6, 0.8, 1, true)
    GameTooltip:Show()
end

-- Stat choices for a category, in the shared stat order.
local function StatOptions(key)
    local category = Rummage.GetCategory(key)
    local options = {}
    for _, stat in ipairs(ns.stats.STATS) do
        if category.statLabels and category.statLabels[stat.key] then
            options[#options + 1] = { key = stat.key, label = stat.label }
        end
    end
    return options
end

local function StatAt(key, position)
    local list = Rummage.GetPriority(key) or {}
    return list[position]
end

local function StatLabel(key, stat)
    local category = Rummage.GetCategory(key)
    if not stat then
        return "Any (strongest)"
    end
    return (category.statLabels and category.statLabels[stat]) or stat
end

local function ChooseStat(key, position, stat)
    Rummage.PreferStat(key, position, stat)
    ns.window.Refresh()
end

-- Forever ships both Blizzard menu systems; prefer the modern DropdownButton
-- and fall back to UIDropDownMenu where it is missing.
local useModernDropdown = MenuUtil ~= nil and pcall(function()
    local probe = CreateFrame("DropdownButton", nil, UIParent, "WowStyle1DropdownTemplate")
    probe:Hide()
end)

local function CreateDropdown(parent, name, width)
    if useModernDropdown then
        local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        dropdown:SetWidth(width)
        return dropdown
    end
    local dropdown = CreateFrame("Frame", "RummageDropdown" .. name, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width - 30)
    dropdown:SetWidth(width)
    return dropdown
end

local function SetupStatDropdown(dropdown, key, position)
    local options = StatOptions(key)
    if useModernDropdown then
        dropdown:SetupMenu(function(_, root)
            root:CreateRadio("Any (strongest)", function() return StatAt(key, position) == nil end, function() ChooseStat(key, position, nil) end)
            for _, option in ipairs(options) do
                root:CreateRadio(option.label, function() return StatAt(key, position) == option.key end, function() ChooseStat(key, position, option.key) end)
            end
        end)
        return
    end
    UIDropDownMenu_Initialize(dropdown, function()
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Any (strongest)"
        info.checked = StatAt(key, position) == nil
        info.func = function() ChooseStat(key, position, nil) end
        UIDropDownMenu_AddButton(info)
        for _, option in ipairs(options) do
            info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.checked = StatAt(key, position) == option.key
            info.func = function() ChooseStat(key, position, option.key) end
            UIDropDownMenu_AddButton(info)
        end
    end)
end

local function UpdateDropdownText(dropdown, key, position)
    local text = StatLabel(key, StatAt(key, position))
    if useModernDropdown then
        if dropdown.OverrideText then
            dropdown:OverrideText(text)
        elseif dropdown.SetText then
            dropdown:SetText(text)
        end
    else
        UIDropDownMenu_SetText(dropdown, text)
    end
end

local function BuildRow(parent, key, y)
    local category = Rummage.GetCategory(key)
    local row = { key = key }

    local icon = CreateFrame("Button", nil, parent)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("TOPLEFT", 20, y)
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnDragStart", function() PickupCategoryMacro(key) end)
    icon:SetScript("OnClick", function() PickupCategoryMacro(key) end)
    icon:SetScript("OnEnter", function(self) ShowCandidateTooltip(self, key) end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    icon.border = icon:CreateTexture(nil, "OVERLAY")
    icon.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    icon.border:SetPoint("TOPLEFT", -12, 12)
    icon.border:SetPoint("BOTTOMRIGHT", 12, -12)

    icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    icon.count:SetPoint("BOTTOMRIGHT", -2, 2)

    icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row.icon = icon

    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
    title:SetText(category.label)
    row.title = title

    local current = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    current:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    current:SetWidth(WIDTH - 110)
    current:SetJustifyH("LEFT")
    current:SetWordWrap(false)
    row.current = current

    local enabled = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    enabled:SetSize(24, 24)
    enabled:SetPoint("TOPRIGHT", -24, y - 4)
    enabled:SetScript("OnClick", function(self)
        Rummage.SetCategoryEnabled(key, self:GetChecked())
        ns.window.Refresh()
    end)
    enabled:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Keep the " .. category.macroName .. " macro updated", 1, 1, 1)
        GameTooltip:Show()
    end)
    enabled:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.enabled = enabled

    if category.statAliases then
        local prefer = CreateDropdown(parent, key .. "Prefer", 150)
        prefer:SetPoint("TOPLEFT", current, "BOTTOMLEFT", -2, -6)
        row.prefer = prefer

        local preferLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        preferLabel:SetPoint("BOTTOMLEFT", prefer, "TOPLEFT", 18, 0)
        preferLabel:SetText("Preferred buff")

        local fallback = CreateDropdown(parent, key .. "Then", 150)
        fallback:SetPoint("LEFT", prefer, "RIGHT", 4, 0)
        row.fallback = fallback

        local fallbackLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fallbackLabel:SetPoint("BOTTOMLEFT", fallback, "TOPLEFT", 18, 0)
        fallbackLabel:SetText("If none, then")

        SetupStatDropdown(prefer, key, 1)
        SetupStatDropdown(fallback, key, 2)

        local order = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        order:SetPoint("LEFT", fallback, "RIGHT", 6, 0)
        order:SetWidth(WIDTH - 68 - 150 - 4 - 150 - 6 - 60)
        order:SetJustifyH("LEFT")
        order:SetWordWrap(false)
        row.order = order

        local reset = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        reset:SetSize(60, 20)
        reset:SetPoint("RIGHT", enabled, "LEFT", -6, 0)
        reset:SetText("Default")
        reset:SetScript("OnClick", function()
            Rummage.SetPriority(key, nil)
            ns.window.Refresh()
        end)
    end

    rows[#rows + 1] = row
    return y - ROW_HEIGHT - (category.statAliases and 40 or 0)
end

local function RefreshRow(row)
    local key = row.key
    local category = Rummage.GetCategory(key)
    local pick = Rummage.currentPick[key]
    local enabled = Rummage.IsCategoryEnabled(key)

    row.enabled:SetChecked(enabled)
    if pick then
        row.icon.texture:SetTexture(GetItemIcon(pick.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.icon.count:SetText(pick.count > 1 and tostring(pick.count) or "")
        row.current:SetText(category.Describe and category.Describe(pick) or (pick.link or pick.name))
    else
        row.icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.icon.count:SetText("")
        row.current:SetText("|cff9d9d9dNothing suitable in your bags|r")
    end
    row.icon.texture:SetDesaturated(not enabled)
    row.icon:SetAlpha(enabled and 1 or 0.5)
    row.title:SetAlpha(enabled and 1 or 0.5)
    if row.prefer then
        UpdateDropdownText(row.prefer, key, 1)
        UpdateDropdownText(row.fallback, key, 2)
        row.order:SetText("Order: " .. Rummage.PriorityToText(key))
    end
end

function ns.window.Refresh()
    if not frame or not frame:IsShown() then
        return
    end
    for _, row in ipairs(rows) do
        RefreshRow(row)
    end
end

local function Build()
    frame = CreateFrame("Frame", "RummageWindow", UIParent, "BackdropTemplate")
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText("Rummage")

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 20, -44)
    hint:SetWidth(WIDTH - 40)
    hint:SetJustifyH("LEFT")
    hint:SetText("Drag an icon onto any action slot. That slot then always uses the best item in your bags. Hover an icon to see every candidate.")

    local y = -44 - hint:GetStringHeight() - 16
    for _, key in ipairs(Rummage.GetCategoryKeys()) do
        y = BuildRow(frame, key, y)
    end

    local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    close:SetSize(90, 22)
    close:SetPoint("BOTTOMRIGHT", -22, 16)
    close:SetText("Close")
    close:SetScript("OnClick", function() frame:Hide() end)

    local rescan = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    rescan:SetSize(110, 22)
    rescan:SetPoint("RIGHT", close, "LEFT", -6, 0)
    rescan:SetText("Rescan bags")
    rescan:SetScript("OnClick", function() Rummage.RequestScan() end)

    frame:SetSize(WIDTH, -y + 56)
    frame:SetScript("OnShow", ns.window.Refresh)
    tinsert(UISpecialFrames, "RummageWindow")
    frame:Hide()
end

function ns.window.Toggle()
    if not frame then
        Build()
    end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        Rummage.RequestScan()
    end
end

function ns.window.Show()
    if not frame then
        Build()
    end
    frame:Show()
end
