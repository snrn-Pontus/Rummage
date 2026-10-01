local ADDON_NAME, ns = ...

-- Rummage keeps one macro per consumable category ("SmartFood", ...) and
-- rewrites it, out of combat, to use the best matching item in your bags.
-- Categories (Categories/*.lua) tell the core how to recognise an item and
-- how to rank the candidates. The core owns bag scanning, macro upkeep,
-- saved variables and the slash command.

Rummage = Rummage or {}
local Rummage = Rummage
ns.core = Rummage

local categories = {}
local categoryOrder = {}
local dirty = true
local scanScheduled = false
local pendingMacroUpdate = false
local waitingForItemInfo = false
local SCAN_DELAY = 0.5


Rummage.currentPick = {}     -- category key -> candidate table (or nil)
Rummage.candidates = {}      -- category key -> ranked list, for /rum list

local function Print(fmt, ...)
    local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    print("|cff7fd8ffRummage|r: " .. msg)
end
Rummage.Print = Print

local function Debug(fmt, ...)
    if RummageDB and RummageDB.debug then
        Print("[debug] " .. fmt, ...)
    end
end
Rummage.Debug = Debug

--------------------------------------------------------------------------------
-- Saved variables
--------------------------------------------------------------------------------

local function InitSavedVariables()
    RummageDB = RummageDB or {}
    if RummageDB.debug == nil then
        RummageDB.debug = false
    end

    RummageCharDB = RummageCharDB or {}
    RummageCharDB.priorities = RummageCharDB.priorities or {}
    RummageCharDB.enabled = RummageCharDB.enabled or {}
end

function Rummage.GetPriority(key)
    local category = categories[key]
    if not category then
        return nil
    end
    -- A saved empty list means "any buff, strongest wins"; nil means default.
    local saved = RummageCharDB and RummageCharDB.priorities[key]
    if type(saved) == "table" then
        return saved
    end
    if type(category.defaultPriority) == "function" then
        return category.defaultPriority()
    end
    return category.defaultPriority or {}
end

-- Puts stat at the given position of the priority (1 = preferred buff,
-- 2 = fallback, ...), keeping the rest of the order. stat = nil clears that
-- position and everything after it, so "any" means strongest wins.
function Rummage.PreferStat(key, position, stat)
    local current = Rummage.GetPriority(key)
    if not current then
        return
    end
    local list = {}
    for index = 1, position - 1 do
        if current[index] and current[index] ~= stat then
            list[#list + 1] = current[index]
        end
    end
    if stat then
        list[#list + 1] = stat
        for index = position, #current do
            if current[index] ~= stat and not tContains(list, current[index]) then
                list[#list + 1] = current[index]
            end
        end
    end
    Rummage.SetPriority(key, list)
end

function Rummage.SetPriority(key, list)
    if not categories[key] then
        return false
    end
    RummageCharDB.priorities[key] = list
    Rummage.RequestScan()
    return true
end

function Rummage.IsCategoryEnabled(key)
    local saved = RummageCharDB and RummageCharDB.enabled[key]
    if saved == nil then
        return true
    end
    return saved
end

function Rummage.SetCategoryEnabled(key, enabled)
    if not categories[key] then
        return
    end
    RummageCharDB.enabled[key] = enabled and true or false
    Rummage.RequestScan()
end

--------------------------------------------------------------------------------
-- Categories
--------------------------------------------------------------------------------

-- A category is a table with:
--   key              "food"
--   label            "Food"
--   macroName        "SmartFood"
--   defaultPriority  { "HASTE", "CRIT", ... } (stat keys, see ParsePriority),
--                    or a function returning one (e.g. per class)
--   statAliases      { haste = "HASTE", crit = "CRIT", ... } (optional)
--   Prefilter(itemID, classID, subclassID) -> bool, cheap filter before tooltips
--   Classify(itemID, tooltipLines) -> info table or nil
--   Rank(candidates, priority) -> sorts candidates in place, best first; may
--                    set usable = false and unusableReason to skip one
--   Describe(candidate) -> string for chat output (optional)
--   MacroBody(candidate) -> macro text (optional; default "/use item:ID")
-- Categories without statAliases have no priority; they rank on their own.
--   Prepare() -> called once before each bag scan (optional)
--   events           { "QUEST_LOG_UPDATE", ... } extra events that trigger a scan
local eventFrame = CreateFrame("Frame")

function Rummage.RegisterCategory(category)
    assert(type(category.key) == "string", "category needs a key")
    assert(type(category.macroName) == "string", "category needs a macroName")
    if categories[category.key] then
        return
    end
    categories[category.key] = category
    categoryOrder[#categoryOrder + 1] = category.key
    for _, event in ipairs(category.events or {}) do
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
end

function Rummage.GetCategory(key)
    return categories[key]
end

function Rummage.GetCategoryKeys()
    return categoryOrder
end

--------------------------------------------------------------------------------
-- Bag scanning
--------------------------------------------------------------------------------

local function GetNumBagSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    end
    if GetContainerNumSlots then
        return GetContainerNumSlots(bag) or 0
    end
    return 0
end

local function GetBagItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
            return info.itemID, info.stackCount or 1, info.hyperlink
        end
        return nil
    end
    if GetContainerItemInfo then
        local _, count, _, _, _, _, link, _, _, itemID = GetContainerItemInfo(bag, slot)
        return itemID, count or 1, link
    end
    return nil
end

local function GetItemClass(itemID)
    local getter = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not getter then
        return nil
    end
    local _, _, _, _, _, classID, subclassID = getter(itemID)
    return classID, subclassID
end

local function GetItemMinLevel(itemID)
    local getter = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getter then
        return 0
    end
    local _, _, _, _, minLevel = getter(itemID)
    if minLevel == nil then
        waitingForItemInfo = true
    end
    return minLevel or 0
end

local function LastBagIndex()
    return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

-- Walks the bags once and hands every item to every enabled category.
-- Each category's Prefilter keeps the tooltip work down to the classes it
-- cares about.
local function ScanBags()
    local playerLevel = UnitLevel("player") or 1
    waitingForItemInfo = false
    local found = {}          -- key -> { [itemID] = candidate }
    for _, key in ipairs(categoryOrder) do
        found[key] = {}
        local category = categories[key]
        if category.Prepare and Rummage.IsCategoryEnabled(key) then
            category.Prepare()
        end
    end

    for bag = 0, LastBagIndex() do
        for slot = 1, GetNumBagSlots(bag) do
            local itemID, count, link = GetBagItem(bag, slot)
            if itemID then
                local classID, subclassID = GetItemClass(itemID)
                do
                    local lines
                    for _, key in ipairs(categoryOrder) do
                        local category = categories[key]
                        if Rummage.IsCategoryEnabled(key)
                            and (not category.Prefilter or category.Prefilter(itemID, classID, subclassID)) then
                            local existing = found[key][itemID]
                            if existing then
                                existing.count = existing.count + count
                            else
                                lines = lines or ns.GetBagItemTooltipLines(bag, slot, itemID)
                                local info = category.Classify(itemID, lines)
                                if info then
                                    info.itemID = itemID
                                    info.count = count
                                    info.link = link
                                    info.minLevel = GetItemMinLevel(itemID)
                                    info.usable = info.minLevel <= playerLevel
                                    found[key][itemID] = info
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for _, key in ipairs(categoryOrder) do
        local list = {}
        for _, candidate in pairs(found[key]) do
            list[#list + 1] = candidate
        end
        categories[key].Rank(list, Rummage.GetPriority(key))
        Rummage.candidates[key] = list

        local best
        for _, candidate in ipairs(list) do
            if candidate.usable then
                best = candidate
                break
            end
        end
        Rummage.currentPick[key] = best
        Debug("%s: %d candidate(s), pick %s", key, #list, best and (best.link or best.itemID) or "none")
    end
end

--------------------------------------------------------------------------------
-- Macros
--------------------------------------------------------------------------------

local MACRO_ICON = "INV_MISC_QUESTIONMARK"

local function MacroBody(category, pick)
    if pick then
        if category.MacroBody then
            return category.MacroBody(pick)
        end
        return "#showtooltip\n/use item:" .. pick.itemID
    end
    return string.format("#showtooltip\n/run Rummage.Print(\"No %s in your bags.\")", category.label:lower())
end

local function EnsureMacro(category, body)
    local index = GetMacroIndexByName(category.macroName)
    if index and index > 0 then
        return index
    end

    local numGlobal, numPerChar = GetNumMacros()
    local perCharacter = (numPerChar or 0) < (MAX_CHARACTER_MACROS or 18)
    if not perCharacter and (numGlobal or 0) >= (MAX_ACCOUNT_MACROS or 120) then
        Print("Cannot create the %s macro: all macro slots are used.", category.macroName)
        return nil
    end
    local ok, result = pcall(CreateMacro, category.macroName, MACRO_ICON, body, perCharacter)
    if not ok then
        Print("Cannot create the %s macro: %s", category.macroName, tostring(result))
        return nil
    end
    Print("Created the %s macro. Type /rum and drag its icon to an action slot.", category.macroName)
    return result
end

local function UpdateMacros()
    if InCombatLockdown() then
        pendingMacroUpdate = true
        return
    end
    pendingMacroUpdate = false

    for _, key in ipairs(categoryOrder) do
        local category = categories[key]
        if Rummage.IsCategoryEnabled(key) then
            local body = MacroBody(category, Rummage.currentPick[key])
            local index = EnsureMacro(category, body)
            if index then
                local _, _, currentBody = GetMacroInfo(index)
                if currentBody ~= body then
                    local ok, err = pcall(EditMacro, index, category.macroName, MACRO_ICON, body)
                    if not ok then
                        Print("Cannot update the %s macro: %s", category.macroName, tostring(err))
                    else
                        Debug("%s macro updated", category.macroName)
                    end
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Scheduling
--------------------------------------------------------------------------------

local function RunScan()
    scanScheduled = false
    if InCombatLockdown() then
        dirty = true
        return
    end
    dirty = false
    ScanBags()
    UpdateMacros()
    if ns.settings and ns.settings.Refresh then
        ns.settings.Refresh()
    end
    if ns.window and ns.window.Refresh then
        ns.window.Refresh()
    end
end

function Rummage.RequestScan()
    dirty = true
    if scanScheduled then
        return
    end
    scanScheduled = true
    C_Timer.After(SCAN_DELAY, RunScan)
end

--------------------------------------------------------------------------------
-- Priority parsing
--------------------------------------------------------------------------------

-- Turns "haste crit stamina" into { "HASTE", "CRIT", "STAMINA" } using the
-- category's aliases. Returns the list and a list of rejected words.
function Rummage.ParsePriority(key, text)
    local category = categories[key]
    if not category then
        return nil, { key }
    end
    local list, rejected, seen = {}, {}, {}
    for word in tostring(text or ""):gmatch("[^%s,>]+") do
        local stat = category.statAliases and category.statAliases[word:lower()]
        if stat and not seen[stat] then
            seen[stat] = true
            list[#list + 1] = stat
        elseif not stat then
            rejected[#rejected + 1] = word
        end
    end
    return list, rejected
end

function Rummage.PriorityToText(key)
    local list = Rummage.GetPriority(key)
    local category = categories[key]
    local words = {}
    for _, stat in ipairs(list or {}) do
        words[#words + 1] = (category and category.statLabels and category.statLabels[stat]) or stat
    end
    if #words == 0 then
        return "any (strongest wins)"
    end
    return table.concat(words, " ")
end

--------------------------------------------------------------------------------
-- Slash command
--------------------------------------------------------------------------------

local function DescribeCandidate(category, candidate)
    if category.Describe then
        return category.Describe(candidate)
    end
    return candidate.link or tostring(candidate.itemID)
end

local function PrintStatus(key)
    local category = categories[key]
    local pick = Rummage.currentPick[key]
    local state = Rummage.IsCategoryEnabled(key) and "" or " (disabled)"
    if pick then
        Print("%s%s -> %s", category.label, state, DescribeCandidate(category, pick))
    else
        Print("%s%s -> nothing suitable in bags", category.label, state)
    end
end

local function PrintHelp()
    Print("commands:")
    print("  /rummage  - open the Rummage window (drag icons to your bars)")
    print("  /rummage config  - open Settings > AddOns > Rummage")
    print("  /rummage status  - print what each macro currently uses")
    print("  /rummage list <category>  - show every candidate in ranked order")
    print("  /rummage <category> <stat> <stat> ...  - set the stat priority for this character")
    print("  /rummage <category> on|off  - enable or disable that macro")
    print("  /rummage pickup <category>  - put the macro on the cursor to drop on a slot")
    print("  /rummage scan  - rescan bags now")
    print("  /rummage debug  - toggle debug output")
    local keys = {}
    for _, key in ipairs(categoryOrder) do
        keys[#keys + 1] = key
    end
    print("  categories: " .. table.concat(keys, ", "))
end

local function HandleSlash(input)
    input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local command, rest = input:match("^(%S+)%s*(.*)$")
    command = command and command:lower() or ""

    if command == "" then
        if ns.window and ns.window.Toggle then
            ns.window.Toggle()
        else
            for _, key in ipairs(categoryOrder) do
                PrintStatus(key)
            end
        end
        return
    elseif command == "status" then
        for _, key in ipairs(categoryOrder) do
            PrintStatus(key)
        end
        return
    elseif command == "help" then
        PrintHelp()
        return
    elseif command == "config" or command == "options" or command == "settings" then
        if ns.settings and ns.settings.Open then
            ns.settings.Open()
        end
        return
    elseif command == "scan" then
        Rummage.RequestScan()
        Print("rescanning bags")
        return
    elseif command == "debug" then
        RummageDB.debug = not RummageDB.debug
        Print("debug output %s", RummageDB.debug and "on" or "off")
        return
    elseif command == "list" then
        local key = rest:match("^(%S+)")
        local category = key and categories[key:lower()]
        if not category then
            Print("usage: /rummage list <category>")
            return
        end
        key = key:lower()
        local list = Rummage.candidates[key] or {}
        if category.statAliases then
            Print("%s candidates (priority: %s):", category.label, Rummage.PriorityToText(key))
        else
            Print("%s candidates:", category.label)
        end
        if #list == 0 then
            print("  none")
        end
        for i, candidate in ipairs(list) do
            local marker = (candidate == Rummage.currentPick[key]) and " |cff7fff7f<- current|r" or ""
            local level = ""
            if not candidate.usable then
                level = string.format(" |cffff7f7f(%s)|r", candidate.unusableReason or ("requires level " .. candidate.minLevel))
            end
            print(string.format("  %d. %s x%d%s%s", i, DescribeCandidate(category, candidate), candidate.count, level, marker))
        end
        return
    elseif command == "pickup" then
        local key = rest:match("^(%S+)")
        local category = key and categories[key:lower()]
        if not category then
            Print("usage: /rummage pickup <category>")
            return
        end
        if InCombatLockdown() then
            Print("cannot pick up macros in combat")
            return
        end
        local index = GetMacroIndexByName(category.macroName)
        if not index or index == 0 then
            UpdateMacros()
            index = GetMacroIndexByName(category.macroName)
        end
        if index and index > 0 then
            PickupMacro(index)
            Print("%s macro is on your cursor. Click an action slot to place it.", category.macroName)
        end
        return
    end

    local category = categories[command]
    if not category then
        PrintHelp()
        return
    end

    local lower = rest:lower()
    if lower == "on" or lower == "off" then
        Rummage.SetCategoryEnabled(command, lower == "on")
        Print("%s macro %s", category.label, lower == "on" and "enabled" or "disabled")
        return
    elseif lower == "" then
        PrintStatus(command)
        if category.statAliases then
            Print("priority: %s", Rummage.PriorityToText(command))
        end
        return
    elseif not category.statAliases then
        Print("%s has no stat priority; it always uses the strongest item. Use on|off.", category.label)
        return
    elseif lower == "reset" then
        Rummage.SetPriority(command, nil)
        Print("%s priority reset to default: %s", category.label, Rummage.PriorityToText(command))
        return
    elseif lower == "any" then
        Rummage.SetPriority(command, {})
        Print("%s: any buff, strongest wins", category.label)
        return
    end

    local list, rejected = Rummage.ParsePriority(command, rest)
    if #rejected > 0 then
        Print("unknown stat(s): %s", table.concat(rejected, ", "))
        local known = {}
        for alias in pairs(category.statAliases or {}) do
            known[#known + 1] = alias
        end
        table.sort(known)
        print("  known: " .. table.concat(known, ", "))
    end
    if #list > 0 then
        Rummage.SetPriority(command, list)
        Print("%s priority: %s", category.label, Rummage.PriorityToText(command))
    end
end

SLASH_RUMMAGE1 = "/rummage"
SLASH_RUMMAGE2 = "/rum"
SlashCmdList.RUMMAGE = HandleSlash

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local frame = eventFrame
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            InitSavedVariables()
        end
    elseif event == "PLAYER_LOGIN" then
        if ns.settings and ns.settings.Register then
            ns.settings.Register()
        end
        Rummage.RequestScan()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "BAG_UPDATE_DELAYED" then
        Rummage.RequestScan()
    elseif event == "PLAYER_LEVEL_UP" then
        ns.ClearTooltipCache()
        Rummage.RequestScan()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- Item data arriving late can change minLevel or tooltip text.
        if waitingForItemInfo then
            Rummage.RequestScan()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if dirty or pendingMacroUpdate then
            Rummage.RequestScan()
        end
    else
        -- Category-registered events (quest log, map changes, ...).
        Rummage.RequestScan()
    end
end)
