local _, ns = ...
local Rummage = ns.core
local stats = ns.stats

-- Food comes in two macros, so healing up never spends buff food:
--
--   SmartFood       buff food (gives Well Fed), ranked by the stats it gives.
--                   Keeps the "food" key so saved priorities and
--                   /rummage food <stats> still apply.
--   SmartPlainFood  food that only restores health, most health first.
--
-- Stats are read from the item tooltip so the addon does not need a
-- per-patch item table; OVERRIDES below fills the gaps for buff food whose
-- tooltip cannot be parsed.

-- Manual data for items whose tooltip does not parse. Keyed by item ID.
-- Example: [12345] = { HASTE = 20 }
local OVERRIDES = {
}

local IGNORE = { HEALTH = true, MANA = true }

local function IsWellFed(text)
    return text:find("well fed", 1, true) ~= nil
end

-- Buff food: anything that gives Well Fed (or is listed in OVERRIDES).
local function Classify(itemID, lines)
    local text = stats.Normalise(table.concat(lines, "\n"))
    local wellFed = IsWellFed(text)
    local health = stats.ParseRestore(text, "health")

    if not OVERRIDES[itemID] and not wellFed then
        return nil
    end

    local found = {}
    for _, line in ipairs(lines) do
        local lower = stats.Normalise(line)
        if lower:find("well fed", 1, true) then
            stats.ParseStats(lower, found)
        end
    end
    if OVERRIDES[itemID] then
        for key, amount in pairs(OVERRIDES[itemID]) do
            found[key] = amount
        end
    end

    return {
        name = lines[1],
        stats = found,
        health = health or 0,
        fallbackAmount = health or 0,
        wellFed = wellFed,
    }
end

-- Plain food: seated food that restores health and gives no buff.
local function ClassifyPlain(itemID, lines)
    if OVERRIDES[itemID] then
        return nil
    end
    local text = stats.Normalise(table.concat(lines, "\n"))
    if IsWellFed(text) or not text:find("must remain seated", 1, true) then
        return nil
    end
    local health = stats.ParseRestore(text, "health", UnitHealthMax("player"))
    if not health then
        return nil -- pure drink
    end
    return {
        name = lines[1],
        amount = health,
    }
end

local function RankPlain(candidates)
    table.sort(candidates, function(a, b)
        if a.amount ~= b.amount then return a.amount > b.amount end
        if a.count ~= b.count then return a.count > b.count end
        return a.itemID < b.itemID
    end)
end

local function Prefilter(itemID, classID, subclassID)
    if OVERRIDES[itemID] then
        return true
    end
    -- Some clients file food under other consumable subclasses, so only
    -- non-consumables are skipped here; the tooltip decides the rest.
    return classID == nil or classID == stats.CONSUMABLE_CLASS
end

local function Rank(candidates, priority)
    stats.RankByPriority(candidates, priority, IGNORE)
end

local function Describe(candidate)
    local statText = stats.DescribeStats(candidate, IGNORE)
    return (candidate.link or candidate.name or ("item:" .. candidate.itemID))
        .. " (" .. (statText or "no stats") .. ")"
end

Rummage.RegisterCategory({
    key = "food",
    label = "Buff food",
    macroName = "SmartFood",
    defaultPriority = { "HASTE", "CRIT", "MASTERY", "VERS", "STAMINA", "SPIRIT", "STRENGTH", "AGILITY", "INTELLECT", "AP", "SP" },
    statAliases = stats.aliases,
    statLabels = stats.labels,
    Prefilter = Prefilter,
    Classify = Classify,
    Rank = Rank,
    Describe = Describe,
})

Rummage.RegisterCategory({
    key = "plainfood",
    label = "Plain food",
    macroName = "SmartPlainFood",
    Prefilter = Prefilter,
    Classify = ClassifyPlain,
    Rank = RankPlain,
    Describe = function(candidate)
        return string.format("%s (%d health)", candidate.link or candidate.name or ("item:" .. candidate.itemID), candidate.amount)
    end,
})
