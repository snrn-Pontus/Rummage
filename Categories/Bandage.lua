local _, ns = ...
local Rummage = ns.core
local stats = ns.stats

-- Bandages, ranked by the amount healed. The macro targets yourself, since
-- a bandage on the action bar is almost always a self-heal; change the
-- macro's target condition in MacroBody if you want the cursor instead.

local function IsBandage(subclassID, lines)
    if subclassID == stats.SUBCLASS.BANDAGE then
        return true
    end
    local name = lines and lines[1] and lines[1]:lower() or ""
    return name:find("bandage", 1, true) ~= nil
end

local function Classify(itemID, lines)
    local text = stats.Normalise(table.concat(lines, "\n"))
    local _, _, _, _, _, _, subclassID = (C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant)(itemID)
    if not IsBandage(subclassID, lines) then
        return nil
    end
    local amount = stats.ParseRestore(text, "health", UnitHealthMax("player"))
    if not amount then
        return nil
    end
    return {
        name = lines[1],
        amount = amount,
    }
end

local function Rank(candidates)
    table.sort(candidates, function(a, b)
        if a.amount ~= b.amount then return a.amount > b.amount end
        if a.count ~= b.count then return a.count > b.count end
        return a.itemID < b.itemID
    end)
end

Rummage.RegisterCategory({
    key = "bandage",
    label = "Bandage",
    macroName = "SmartBandage",
    Prefilter = function(itemID, classID, subclassID)
        return classID == nil or classID == stats.CONSUMABLE_CLASS
    end,
    Classify = Classify,
    Rank = Rank,
    Describe = function(candidate)
        return string.format("%s (heals %d)", candidate.link or candidate.name or ("item:" .. candidate.itemID), candidate.amount)
    end,
    MacroBody = function(pick)
        return "#showtooltip\n/use [@player] item:" .. pick.itemID
    end,
})
