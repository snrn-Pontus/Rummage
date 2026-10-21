local _, ns = ...

-- Tooltip text for bag items, cached per item ID. Uses C_TooltipInfo where
-- the client has it and falls back to a hidden GameTooltip otherwise. The
-- cache is cleared on level-up because scaling consumables change their text.
--
-- A bag item's tooltip is only complete once the client has both the item
-- and its "Use:" spell loaded. Before that it can come back with just the
-- name, or without the "Use: Restores ..." line, and the item is not
-- recognised. Such a tooltip is never cached (it used to be, which left a
-- freshly looted potion or bandage ignored until /reload); instead the
-- data is requested and the core rescans when it arrives.

local cache = {}
local scanTooltip
local loadRequests = {}       -- "item:ID" / "spell:ID" -> times requested
local MAX_LOAD_REQUESTS = 3

local USE_PREFIX = (ITEM_SPELL_TRIGGER_ONUSE or "Use:"):lower()

-- Asks the client for data it does not have yet. Returns false while a
-- request is outstanding; gives up after a few tries so an item whose data
-- never arrives cannot keep the scanner busy.
local function Request(kind, id, isCached, load)
    if isCached(id) then
        return true
    end
    local key = kind .. ":" .. id
    local tries = loadRequests[key] or 0
    if tries >= MAX_LOAD_REQUESTS then
        return true
    end
    loadRequests[key] = tries + 1
    if load then
        pcall(load, id)
    end
    return false
end

local function IsDataLoaded(itemID)
    local ready = true
    if C_Item and C_Item.IsItemDataCachedByID then
        ready = Request("item", itemID, C_Item.IsItemDataCachedByID, C_Item.RequestLoadItemDataByID) and ready
    end
    local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    if getSpell and C_Spell and C_Spell.IsSpellDataCached then
        local ok, _, spellID = pcall(getSpell, itemID)
        if ok and spellID then
            ready = Request("spell", spellID, C_Spell.IsSpellDataCached, C_Spell.RequestLoadSpellData) and ready
        end
    end
    return ready
end

local function HasUseLine(lines)
    for _, line in ipairs(lines) do
        if line:lower():sub(1, #USE_PREFIX) == USE_PREFIX then
            return true
        end
    end
    return false
end

local function SurfaceLine(line)
    if line.leftText == nil and TooltipUtil and TooltipUtil.SurfaceArgs then
        TooltipUtil.SurfaceArgs(line)
    end
    return line.leftText
end

local function LinesFromTooltipInfo(bag, slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then
        return nil
    end
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
        return nil
    end
    local lines = {}
    for _, line in ipairs(data.lines) do
        local text = SurfaceLine(line)
        if text and text ~= "" then
            lines[#lines + 1] = text
        end
    end
    return lines
end

local function LinesFromScanTooltip(bag, slot)
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "RummageScanTooltip", UIParent, "GameTooltipTemplate")
        scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    scanTooltip:ClearLines()
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    local ok = pcall(scanTooltip.SetBagItem, scanTooltip, bag, slot)
    if not ok then
        return {}
    end
    local lines = {}
    for i = 1, scanTooltip:NumLines() do
        local fontString = _G["RummageScanTooltipTextLeft" .. i]
        local text = fontString and fontString:GetText()
        if text and text ~= "" then
            lines[#lines + 1] = text
        end
    end
    scanTooltip:Hide()
    return lines
end

-- Returns the tooltip lines and whether they are complete. When they are
-- not, the caller should rescan once the item or spell data has loaded.
function ns.GetBagItemTooltipLines(bag, slot, itemID)
    local cached = itemID and cache[itemID]
    if cached then
        return cached, true
    end
    local loaded = not itemID or IsDataLoaded(itemID)
    local lines = LinesFromTooltipInfo(bag, slot) or LinesFromScanTooltip(bag, slot)
    local complete = loaded and #lines > 1
    -- Only cache a full tooltip. Items without a "Use:" line (rare among
    -- consumables) are re-read each scan, which is cheap and never stale.
    if itemID and complete and HasUseLine(lines) then
        cache[itemID] = lines
    end
    return lines, complete
end

function ns.ClearTooltipCache()
    wipe(cache)
    wipe(loadRequests)
end
