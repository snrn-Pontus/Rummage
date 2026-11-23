local _, ns = ...
local Rummage = ns.core

-- The Rummage bar: a movable row of buttons, one per category that has
-- something in your bags, each using that category's best item. It grows and
-- shrinks with your bags, like the old AutoBar. It is separate from the
-- Smart* macros; both follow the same pick.
--
-- The buttons are secure action buttons running the category's macro text,
-- so their attributes, size and position can only change out of combat.
-- Bag scans only run out of combat too, so the layout follows each scan and
-- stays put during a fight. Counts, cooldowns and the usability tint keep
-- updating in combat. The bar is never handed to the gamepad cursor.

ns.bar = {}
local bar, grip
local buttons = {}            -- category key -> button
local pendingLayout = false

local BUTTON_SIZE = 36
local SPACING = 4
local PADDING = 6

local function GetItemIcon(itemID)
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID)
    end
    if _G.GetItemIcon then
        return _G.GetItemIcon(itemID)
    end
    return nil
end

local function GetItemCount(itemID)
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(itemID) or 0
    end
    if _G.GetItemCount then
        return _G.GetItemCount(itemID) or 0
    end
    return 0
end

local function GetItemCooldown(itemID)
    if C_Item and C_Item.GetItemCooldown then
        return C_Item.GetItemCooldown(itemID)
    end
    if C_Container and C_Container.GetItemCooldown then
        return C_Container.GetItemCooldown(itemID)
    end
    if _G.GetItemCooldown then
        return _G.GetItemCooldown(itemID)
    end
    return 0, 0, 1
end

local function IsUsableItem(itemID)
    if C_Item and C_Item.IsUsableItem then
        return C_Item.IsUsableItem(itemID)
    end
    if _G.IsUsableItem then
        return _G.IsUsableItem(itemID)
    end
    return true, false
end

--------------------------------------------------------------------------------
-- Saved settings (per character)
--------------------------------------------------------------------------------

local DEFAULTS = {
    shown = true,
    locked = false,
    vertical = false,
    showEmpty = false,
    scale = 1,
}

local function Options()
    RummageCharDB.bar = RummageCharDB.bar or {}
    local saved = RummageCharDB.bar
    for key, value in pairs(DEFAULTS) do
        if saved[key] == nil then
            saved[key] = value
        end
    end
    return saved
end

function ns.bar.Get(option)
    return Options()[option]
end

--------------------------------------------------------------------------------
-- Buttons
--------------------------------------------------------------------------------

local function ShowTooltip(button)
    local key = button.key
    local category = Rummage.GetCategory(key)
    local pick = button.itemID and Rummage.currentPick[key]
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if pick and GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(pick.itemID)
        -- SmartFoodDrink shows the food; name the drink that comes with it.
        if pick.food and pick.drink then
            GameTooltip:AddLine("+ " .. (pick.drink.link or pick.drink.name or ("item:" .. pick.drink.itemID)), 1, 1, 1)
        end
    else
        GameTooltip:SetText(category.label, 1, 1, 1)
        GameTooltip:AddLine("Nothing suitable in your bags.", 0.8, 0.8, 0.8, true)
    end
    local list = Rummage.candidates[key] or {}
    local others = 0
    for _, candidate in ipairs(list) do
        if candidate ~= pick and candidate.usable then
            others = others + 1
        end
    end
    local line = "Rummage: " .. category.label
    if others > 0 then
        line = line .. string.format(" (%d other%s in bags)", others, others == 1 and "" or "s")
    end
    GameTooltip:AddLine(line, 0.5, 0.85, 1)
    if not Options().locked then
        GameTooltip:AddLine("Drag the blue handle to move the bar; /rum bar lock locks it.", 0.6, 0.6, 0.6, true)
    end
    GameTooltip:Show()
end

local function CreateButton(key)
    local button = CreateFrame("Button", "RummageBarButton_" .. key, bar, "SecureActionButtonTemplate")
    button.key = key
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    -- Mouse clicks fire on release; key bindings follow ActionButtonUseKeyDown.
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type", "macro")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    button.border:SetPoint("TOPLEFT", -12, 12)
    button.border:SetPoint("BOTTOMRIGHT", 12, -12)

    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)

    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)

    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    buttons[key] = button
    return button
end

-- Count, cooldown sweep and tint; safe in combat (no secure attributes).
local function RefreshButtonState(button)
    local itemID = button.itemID
    if not itemID then
        button.count:SetText("")
        CooldownFrame_Set(button.cooldown, 0, 0, false)
        button.icon:SetVertexColor(0.4, 0.4, 0.4)
        return
    end
    local count = GetItemCount(itemID)
    button.count:SetText(count > 1 and tostring(count) or "")
    local start, duration, enable = GetItemCooldown(itemID)
    CooldownFrame_Set(button.cooldown, start or 0, duration or 0, enable)
    local usable, noMana = IsUsableItem(itemID)
    if count == 0 then
        button.icon:SetVertexColor(0.4, 0.4, 0.4)
    elseif usable then
        button.icon:SetVertexColor(1, 1, 1)
    elseif noMana then
        button.icon:SetVertexColor(0.5, 0.5, 1)
    else
        button.icon:SetVertexColor(0.4, 0.4, 0.4)
    end
end

local function RefreshStates()
    if not bar or not bar:IsShown() then
        return
    end
    for _, button in pairs(buttons) do
        if button:IsShown() then
            RefreshButtonState(button)
        end
    end
end

--------------------------------------------------------------------------------
-- Layout (out of combat only)
--------------------------------------------------------------------------------

local function SavePosition()
    local point, _, relativePoint, x, y = bar:GetPoint(1)
    Options().point = { point, relativePoint, x, y }
end

local function ApplyPosition()
    local saved = Options().point
    bar:ClearAllPoints()
    if saved then
        bar:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    else
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 220)
    end
end

local function Layout()
    if InCombatLockdown() then
        pendingLayout = true
        return
    end
    pendingLayout = false
    local settings = Options()

    if not settings.shown then
        bar:Hide()
        return
    end

    local shown = 0
    for _, key in ipairs(Rummage.GetCategoryKeys()) do
        local category = Rummage.GetCategory(key)
        local pick = Rummage.currentPick[key]
        local button = buttons[key] or CreateButton(key)
        local wanted = Rummage.IsCategoryEnabled(key) and (pick ~= nil or settings.showEmpty)
        if wanted then
            button.itemID = pick and pick.itemID or nil
            button:SetAttribute("macrotext", Rummage.MacroBody(category, pick))
            button.icon:SetTexture(pick and GetItemIcon(pick.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
            button:ClearAllPoints()
            local offset = PADDING + shown * (BUTTON_SIZE + SPACING)
            if settings.vertical then
                button:SetPoint("TOPLEFT", bar, "TOPLEFT", PADDING, -offset)
            else
                button:SetPoint("TOPLEFT", bar, "TOPLEFT", offset, -PADDING)
            end
            button:Show()
            RefreshButtonState(button)
            shown = shown + 1
        else
            button.itemID = nil
            button:Hide()
        end
    end

    local length = PADDING * 2 + math.max(shown, 1) * BUTTON_SIZE + math.max(shown - 1, 0) * SPACING
    local thickness = PADDING * 2 + BUTTON_SIZE
    if settings.vertical then
        bar:SetSize(thickness, length)
    else
        bar:SetSize(length, thickness)
    end
    bar:SetScale(settings.scale or 1)

    if settings.locked then
        grip:Hide()
        bar.bg:Hide()
    else
        grip:Show()
        bar.bg:Show()
    end
    -- Nothing to show and nothing to drag: hide the whole bar.
    bar:SetShown(shown > 0 or not settings.locked)
end

local function Build()
    bar = CreateFrame("Frame", "RummageBar", UIParent)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:SetSize(BUTTON_SIZE + PADDING * 2, BUTTON_SIZE + PADDING * 2)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.35)

    -- Plain (insecure) drag handle, shown while the bar is unlocked.
    grip = CreateFrame("Button", nil, bar)
    grip:SetSize(12, 12)
    grip:SetPoint("BOTTOMRIGHT", bar, "TOPLEFT", 12, 0)
    grip.texture = grip:CreateTexture(nil, "ARTWORK")
    grip.texture:SetAllPoints()
    grip.texture:SetColorTexture(0.2, 0.8, 1, 0.8)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function()
        if not InCombatLockdown() then
            bar:StartMoving()
        end
    end)
    grip:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        SavePosition()
    end)
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Rummage bar", 1, 1, 1)
        GameTooltip:AddLine("Drag to move. /rum bar lock to lock it, /rum bar for all options.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ApplyPosition()

    bar:RegisterEvent("BAG_UPDATE_COOLDOWN")
    bar:RegisterEvent("BAG_UPDATE_DELAYED")
    bar:RegisterEvent("SPELL_UPDATE_USABLE")
    bar:RegisterEvent("PLAYER_REGEN_DISABLED")
    bar:RegisterEvent("PLAYER_REGEN_ENABLED")
    bar:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and pendingLayout then
            Layout()
        end
        RefreshStates()
    end)
end

-- Called by the core after every bag scan.
function ns.bar.Refresh()
    if not RummageCharDB then
        return
    end
    if not bar then
        if InCombatLockdown() then
            pendingLayout = true
            return
        end
        Build()
    end
    Layout()
end

function ns.bar.Set(option, value)
    Options()[option] = value
    if option == "point" and bar and not InCombatLockdown() then
        ApplyPosition()
    end
    ns.bar.Refresh()
    if ns.window and ns.window.Refresh then
        ns.window.Refresh()
    end
    if ns.settings and ns.settings.Refresh then
        ns.settings.Refresh()
    end
end

--------------------------------------------------------------------------------
-- /rum bar ...
--------------------------------------------------------------------------------

local function Print(...)
    Rummage.Print(...)
end

function ns.bar.HandleSlash(rest)
    local command, arg = (rest or ""):lower():match("^(%S*)%s*(.-)$")
    local settings = Options()
    if InCombatLockdown() and command ~= "" and command ~= "help" then
        Print("the bar cannot be changed in combat")
        return
    end
    if command == "" or command == "toggle" then
        ns.bar.Set("shown", not settings.shown)
        Print("bar %s", settings.shown and "shown" or "hidden")
    elseif command == "on" or command == "show" then
        ns.bar.Set("shown", true)
        Print("bar shown")
    elseif command == "off" or command == "hide" then
        ns.bar.Set("shown", false)
        Print("bar hidden")
    elseif command == "lock" then
        ns.bar.Set("locked", true)
        Print("bar locked")
    elseif command == "unlock" then
        ns.bar.Set("locked", false)
        Print("bar unlocked: drag the blue handle to move it")
    elseif command == "vertical" or command == "horizontal" then
        ns.bar.Set("vertical", command == "vertical")
        Print("bar is now %s", command)
    elseif command == "empty" then
        ns.bar.Set("showEmpty", not settings.showEmpty)
        Print("empty categories %s", settings.showEmpty and "shown" or "hidden")
    elseif command == "scale" and tonumber(arg) then
        local scale = math.min(math.max(tonumber(arg), 0.5), 2)
        ns.bar.Set("scale", scale)
        Print("bar scale %.2f", scale)
    elseif command == "reset" then
        ns.bar.Set("point", nil)
        Print("bar moved back to its default spot")
    else
        Print("bar commands:")
        print("  /rummage bar  - show or hide the bar")
        print("  /rummage bar lock|unlock  - lock it in place, or show the drag handle")
        print("  /rummage bar vertical|horizontal  - change its direction")
        print("  /rummage bar empty  - show or hide categories with nothing in your bags")
        print("  /rummage bar scale <0.5-2>  - resize it")
        print("  /rummage bar reset  - move it back to the default spot")
    end
end
