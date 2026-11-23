local _, ns = ...
local Rummage = ns.core
local stats = ns.stats

-- Drinks: anything you sit down with that restores mana (water, juice,
-- conjured water, mana strudels), ranked by the mana restored. Mana potions
-- are not seated and stay in their own category. Food that also restores
-- mana counts here too, since it works as a drink. Drinks with a buff (teas,
-- smoothies) come after every plain drink, so drinking up between pulls does
-- not spend them while anything else is left.

local function Classify(itemID, lines)
    local text = stats.Normalise(table.concat(lines, "\n"))
    if not text:find("must remain seated", 1, true) then
        return nil
    end
    local amount = stats.ParseRestore(text, "mana", UnitPowerMax("player", 0))
    if not amount then
        return nil
    end
    return {
        name = lines[1],
        amount = amount,
        wellFed = text:find("well fed", 1, true) ~= nil,
    }
end

local function Rank(candidates)
    table.sort(candidates, function(a, b)
        if a.wellFed ~= b.wellFed then return not a.wellFed end
        if a.amount ~= b.amount then return a.amount > b.amount end
        if a.count ~= b.count then return a.count > b.count end
        return a.itemID < b.itemID
    end)
end

Rummage.RegisterCategory({
    key = "drink",
    label = "Drink",
    macroName = "SmartDrink",
    Prefilter = function(itemID, classID, subclassID)
        return classID == nil or classID == stats.CONSUMABLE_CLASS
    end,
    Classify = Classify,
    Rank = Rank,
    Describe = function(candidate)
        return string.format("%s (%d mana)", candidate.link or candidate.name or ("item:" .. candidate.itemID), candidate.amount)
    end,
})
