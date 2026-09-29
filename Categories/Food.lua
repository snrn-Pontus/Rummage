local _, ns = ...
local Rummage = ns.core
local stats = ns.stats

-- Food: anything you sit down and eat that restores health, ranked by the
-- Well Fed stats it gives. Stats are read from the item tooltip so the addon
-- does not need a per-patch item table; OVERRIDES below fills the gaps for
-- items whose tooltip cannot be parsed.

-- Manual data for items whose tooltip does not parse. Keyed by item ID.
-- Example: [12345] = { HASTE = 20 }
local OVERRIDES = {
}

local IGNORE = { HEALTH = true, MANA = true }

local function Classify(itemID, lines)
    local text = stats.Normalise(table.concat(lines, "\n"))
    local wellFed = text:find("well fed", 1, true) ~= nil
    local seated = text:find("must remain seated", 1, true) ~= nil
    local health = stats.ParseRestore(text, "health")
    local mana = stats.ParseRestore(text, "mana")

    if not OVERRIDES[itemID] then
        if not wellFed and not (seated and health) then
            return nil
        end
        if mana and not health and not wellFed then
            return nil -- pure drink
        end
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
    label = "Food",
    macroName = "SmartFood",
    defaultPriority = { "HASTE", "CRIT", "MASTERY", "VERS", "STAMINA", "SPIRIT", "STRENGTH", "AGILITY", "INTELLECT", "AP", "SP" },
    statAliases = stats.aliases,
    statLabels = stats.labels,
    Prefilter = function(itemID, classID, subclassID)
        if OVERRIDES[itemID] then
            return true
        end
        -- Some clients file food under other consumable subclasses, so only
        -- non-consumables are skipped here; the tooltip decides the rest.
        return classID == nil or classID == stats.CONSUMABLE_CLASS
    end,
    Classify = Classify,
    Rank = Rank,
    Describe = Describe,
})
