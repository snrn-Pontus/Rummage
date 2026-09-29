local _, ns = ...
local Rummage = ns.core

-- Settings > AddOns > Rummage.
--
-- Forever hangs when the Settings window is closed with the controller after
-- the gamepad cursor (SmartNavigation) has picked up addon-created controls,
-- and Blizzard's vertical-layout settings list triggers that on its own. So
-- this page is a canvas built once at login from plain widgets, never
-- announced to the cursor, and it opens no dropdown menus: the buff choice
-- is a click-to-cycle button here. The /rum window keeps its dropdowns.

ns.settings = {}
local rows = {}
local general = {}
local registered = false
local panel

local function PanelVisible()
    return panel and panel:IsVisible()
end

local function GetItemIcon(itemID)
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID)
    end
    if GetItemIcon then
        return GetItemIcon(itemID)
    end
    return nil
end

-- nil first ("Any"), then every stat the category knows, in shared order.
local function StatOptions(key)
    local category = Rummage.GetCategory(key)
    local options = { false }
    for _, stat in ipairs(ns.stats.STATS) do
        if category.statLabels and category.statLabels[stat.key] then
            options[#options + 1] = stat.key
        end
    end
    return options
end

local function StatLabel(key, stat)
    if not stat then
        return "Any (strongest)"
    end
    local category = Rummage.GetCategory(key)
    return (category.statLabels and category.statLabels[stat]) or stat
end

local function CycleStat(key, position, step)
    local options = StatOptions(key)
    local current = (Rummage.GetPriority(key) or {})[position] or false
    local index = 1
    for i, option in ipairs(options) do
        if option == current then
            index = i
            break
        end
    end
    index = ((index - 1 + step) % #options) + 1
    Rummage.PreferStat(key, position, options[index] or nil)
end

local function AttachTooltip(control, title, text)
    control:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if text then
            GameTooltip:AddLine(text, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    control:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function CreateCycleButton(parent, key, position, labelText, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(labelText)

    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(160, 22)
    button:SetPoint("LEFT", label, "RIGHT", 8, 0)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(_, mouseButton)
        CycleStat(key, position, mouseButton == "RightButton" and -1 or 1)
        ns.settings.Refresh()
    end)
    AttachTooltip(button, labelText, "Left-click for the next buff, right-click for the previous one. \"Any (strongest)\" ranks purely by amount.")
    return button
end

local function BuildCategory(content, key, y)
    local category = Rummage.GetCategory(key)
    local row = { key = key }

    y = y - 10
    local icon = CreateFrame("Button", nil, content)
    icon:SetSize(28, 28)
    icon:SetPoint("TOPLEFT", 8, y)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnDragStart", function() SlashCmdList.RUMMAGE("pickup " .. key) end)
    icon:SetScript("OnClick", function() SlashCmdList.RUMMAGE("pickup " .. key) end)
    AttachTooltip(icon, category.label, "Drag or click to put the " .. category.macroName .. " macro on your cursor, then click an action slot.")
    row.icon = icon

    local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    header:SetText(category.label .. "  |cff9d9d9d(macro: " .. category.macroName .. ")|r")
    y = y - 34

    local enabled = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enabled:SetPoint("TOPLEFT", 4, y)
    enabled:SetSize(26, 26)
    enabled.label = enabled:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enabled.label:SetPoint("LEFT", enabled, "RIGHT", 4, 0)
    enabled.label:SetText("Keep the " .. category.macroName .. " macro updated")
    enabled:SetScript("OnClick", function(self)
        Rummage.SetCategoryEnabled(key, self:GetChecked())
    end)
    row.enabled = enabled
    y = y - 30

    local current = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    current:SetPoint("TOPLEFT", 12, y)
    current:SetWidth(540)
    current:SetJustifyH("LEFT")
    current:SetWordWrap(false)
    row.current = current
    y = y - 24

    if category.statAliases then
        row.prefer = CreateCycleButton(content, key, 1, "Preferred buff:", 12, y)
        y = y - 28
        row.fallback = CreateCycleButton(content, key, 2, "If none, then:", 12, y)

        local reset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        reset:SetSize(80, 22)
        reset:SetPoint("LEFT", row.fallback, "RIGHT", 8, 0)
        reset:SetText("Default")
        reset:SetScript("OnClick", function()
            Rummage.SetPriority(key, nil)
            ns.settings.Refresh()
        end)
        AttachTooltip(reset, "Default order", "Restores the built-in priority for " .. category.label:lower() .. ".")
        y = y - 26

        local order = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        order:SetPoint("TOPLEFT", 12, y)
        order:SetWidth(540)
        order:SetJustifyH("LEFT")
        row.order = order
        y = y - 20
    end

    rows[#rows + 1] = row
    return y - 6
end

local function RefreshRow(row)
    local key = row.key
    local category = Rummage.GetCategory(key)
    local pick = Rummage.currentPick[key]
    local enabled = Rummage.IsCategoryEnabled(key)

    row.enabled:SetChecked(enabled)
    if pick then
        row.icon.texture:SetTexture(GetItemIcon(pick.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.current:SetText("Currently: " .. (category.Describe and category.Describe(pick) or pick.link or tostring(pick.itemID)))
    else
        row.icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.current:SetText("Currently: |cff9d9d9dnothing suitable in your bags|r")
    end
    row.icon.texture:SetDesaturated(not enabled)
    if row.prefer then
        local priority = Rummage.GetPriority(key) or {}
        row.prefer:SetText(StatLabel(key, priority[1]))
        row.fallback:SetText(StatLabel(key, priority[2]))
        row.order:SetText("Order: " .. Rummage.PriorityToText(key))
    end
end

function ns.settings.Refresh()
    if not PanelVisible() then
        return
    end
    if general.debug then
        general.debug:SetChecked(RummageDB and RummageDB.debug or false)
    end
    for _, row in ipairs(rows) do
        RefreshRow(row)
    end
end

function ns.settings.Register()
    if registered or not Settings or type(Settings.RegisterCanvasLayoutCategory) ~= "function" then
        return
    end
    registered = true

    -- Hidden until the Settings window displays it, so OnShow always fires.
    panel = CreateFrame("Frame")
    panel.name = "Rummage"
    panel:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(560, 1)
    scrollFrame:SetScrollChild(content)

    local y = -6
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 6, y)
    title:SetText("Rummage")
    y = y - 26

    local note = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 6, y)
    note:SetWidth(540)
    note:SetJustifyH("LEFT")
    note:SetText("Each category keeps one macro that always uses the best item in your bags. Drag an icon below onto any action slot once; the macro is rewritten whenever your bags change (outside combat). With a controller, use the mouse on this page: the gamepad cursor cannot enter it without freezing Forever when Settings is closed.")
    y = y - (note:GetStringHeight() + 14)

    local openWindow = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    openWindow:SetPoint("TOPLEFT", 6, y)
    openWindow:SetSize(200, 24)
    openWindow:SetText("Open Rummage window")
    openWindow:SetScript("OnClick", function()
        if ns.window and ns.window.Show then
            ns.window.Show()
        end
    end)
    AttachTooltip(openWindow, "Rummage window", "The same controls in a movable window (/rum), with dropdowns for the buff choice.")

    local rescan = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    rescan:SetPoint("LEFT", openWindow, "RIGHT", 8, 0)
    rescan:SetSize(120, 24)
    rescan:SetText("Rescan bags")
    rescan:SetScript("OnClick", function()
        Rummage.RequestScan()
    end)
    y = y - 32

    local debug = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    debug:SetPoint("TOPLEFT", 4, y)
    debug:SetSize(26, 26)
    debug.label = debug:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    debug.label:SetPoint("LEFT", debug, "RIGHT", 4, 0)
    debug.label:SetText("Debug output in chat")
    debug:SetScript("OnClick", function(self)
        RummageDB.debug = self:GetChecked() and true or false
    end)
    general.debug = debug
    y = y - 34

    for _, key in ipairs(Rummage.GetCategoryKeys()) do
        local divider = content:CreateTexture(nil, "ARTWORK")
        divider:SetColorTexture(1, 1, 1, 0.15)
        divider:SetPoint("TOPLEFT", 6, y)
        divider:SetSize(540, 1)
        y = BuildCategory(content, key, y - 2)
    end

    content:SetHeight(-y + 10)

    -- Deliberately not announced to the gamepad cursor (SmartNavigation):
    -- the controls exist from login and are only reparented into the
    -- Settings window, so the cursor never picks them up on its own.
    panel:SetScript("OnShow", ns.settings.Refresh)

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    ns.settings.category = category
end

function ns.settings.Open()
    if not registered then
        ns.settings.Register()
    end
    if ns.settings.category and Settings and type(Settings.OpenToCategory) == "function" then
        Settings.OpenToCategory(ns.settings.category:GetID())
    end
end
