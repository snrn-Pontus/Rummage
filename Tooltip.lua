local _, ns = ...

-- Tooltip text for bag items, cached per item ID. Uses C_TooltipInfo where
-- the client has it and falls back to a hidden GameTooltip otherwise. The
-- cache is cleared on level-up because scaling consumables change their text.

local cache = {}
local scanTooltip

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

function ns.GetBagItemTooltipLines(bag, slot, itemID)
    local cached = itemID and cache[itemID]
    if cached then
        return cached
    end
    local lines = LinesFromTooltipInfo(bag, slot) or LinesFromScanTooltip(bag, slot)
    -- An empty tooltip usually means the item is not in the client cache yet;
    -- do not cache that so the next scan tries again.
    if itemID and #lines > 1 then
        cache[itemID] = lines
    end
    return lines
end

function ns.ClearTooltipCache()
    wipe(cache)
end
