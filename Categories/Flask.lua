local _, ns = ...
local Rummage = ns.core
local stats = ns.stats

-- Flasks and elixirs: consumables that raise a stat for a long duration.
-- Ranked by the same stat priority mechanism as food. Battle and guardian
-- elixirs are not told apart yet; the macro simply uses the best match, so
-- keep the second elixir type on its own slot if you use both.

local OVERRIDES = {
}

local function IsFlaskLike(subclassID, lines)
    if subclassID == stats.SUBCLASS.FLASK or subclassID == stats.SUBCLASS.ELIXIR then
        return true
    end
    local name = lines and lines[1] and lines[1]:lower() or ""
    return name:find("flask", 1, true) ~= nil or name:find("elixir", 1, true) ~= nil or name:find("phial", 1, true) ~= nil
end

local function Classify(itemID, lines)
    local text = stats.Normalise(table.concat(lines, "\n"))
    if text:find("well fed", 1, true) or text:find("must remain seated", 1, true) then
        return nil
    end
    local _, _, _, _, _, _, subclassID = (C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant)(itemID)
    if not OVERRIDES[itemID] and not IsFlaskLike(subclassID, lines) then
        return nil
    end

    local found = {}
    for index, line in ipairs(lines) do
        if index > 1 then
            stats.ParseStats(stats.Normalise(line), found)
        end
    end
    if OVERRIDES[itemID] then
        for key, amount in pairs(OVERRIDES[itemID]) do
            found[key] = amount
        end
    end
    if next(found) == nil then
        return nil
    end

    return {
        name = lines[1],
        stats = found,
        isFlask = subclassID == stats.SUBCLASS.FLASK or (lines[1] or ""):lower():find("flask", 1, true) ~= nil,
    }
end

local function Rank(candidates, priority)
    stats.RankByPriority(candidates, priority)
end

local function Describe(candidate)
    local statText = stats.DescribeStats(candidate)
    return (candidate.link or candidate.name or ("item:" .. candidate.itemID))
        .. " (" .. (statText or "no stats") .. ")"
end

Rummage.RegisterCategory({
    key = "flask",
    label = "Flask / elixir",
    macroName = "SmartFlask",
    defaultPriority = { "STRENGTH", "AGILITY", "INTELLECT", "HASTE", "CRIT", "MASTERY", "VERS", "AP", "SP", "STAMINA", "HEALTH" },
    statAliases = stats.aliases,
    statLabels = stats.labels,
    Prefilter = function(itemID, classID, subclassID)
        if OVERRIDES[itemID] then
            return true
        end
        return classID == nil or classID == stats.CONSUMABLE_CLASS
    end,
    Classify = Classify,
    Rank = Rank,
    Describe = Describe,
})
