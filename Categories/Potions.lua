local _, ns = ...
local Rummage = ns.core
local stats = ns.stats

-- Healing and mana potions, ranked by how much they restore. Percent-based
-- potions are converted using the player's current maximum, so the pick is
-- re-evaluated when bags change (which also happens after a level-up).
--
-- Only items filed as potions, or named "... Potion", count. Healthstones
-- and similar are left alone because they do not share the potion cooldown
-- and deserve their own slot.
--
-- Potions that restore both (Rejuvenation) rank after every single-resource
-- potion: pressing the health macro should not spend the mana half too, since
-- potions share a cooldown. They are still used when nothing else is left.

local function IsPotion(itemID, subclassID, lines)
    if subclassID == stats.SUBCLASS.POTION then
        return true
    end
    local name = lines and lines[1] and lines[1]:lower() or ""
    return name:find("potion", 1, true) ~= nil or name:find("draught", 1, true) ~= nil
end

local function MakeClassifier(resource, maxFunc, otherResource)
    return function(itemID, lines)
        local text = stats.Normalise(table.concat(lines, "\n"))
        if text:find("must remain seated", 1, true) or text:find("well fed", 1, true) then
            return nil
        end
        local _, _, _, _, _, _, subclassID = (C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant)(itemID)
        if not IsPotion(itemID, subclassID, lines) then
            return nil
        end
        local amount = stats.ParseRestore(text, resource, maxFunc())
        if not amount then
            return nil
        end
        return {
            name = lines[1],
            amount = amount,
            restoresBoth = stats.ParseRestore(text, otherResource) ~= nil,
        }
    end
end

local function Rank(candidates)
    table.sort(candidates, function(a, b)
        if a.restoresBoth ~= b.restoresBoth then return not a.restoresBoth end
        if a.amount ~= b.amount then return a.amount > b.amount end
        if a.count ~= b.count then return a.count > b.count end
        return a.itemID < b.itemID
    end)
end

local function MakeDescriber(resource, otherResource)
    return function(candidate)
        return string.format("%s (%d %s%s)", candidate.link or candidate.name or ("item:" .. candidate.itemID), candidate.amount, resource,
            candidate.restoresBoth and (", also " .. otherResource) or "")
    end
end

local function Prefilter(itemID, classID, subclassID)
    return classID == nil or classID == stats.CONSUMABLE_CLASS
end

Rummage.RegisterCategory({
    key = "healthpotion",
    label = "Healing potion",
    macroName = "SmartHealthPotion",
    Prefilter = Prefilter,
    Classify = MakeClassifier("health", function() return UnitHealthMax("player") end, "mana"),
    Rank = Rank,
    Describe = MakeDescriber("health", "mana"),
})

Rummage.RegisterCategory({
    key = "manapotion",
    label = "Mana potion",
    macroName = "SmartManaPotion",
    Prefilter = Prefilter,
    Classify = MakeClassifier("mana", function() return UnitPowerMax("player", 0) end, "health"),
    Rank = Rank,
    Describe = MakeDescriber("mana", "health"),
})
