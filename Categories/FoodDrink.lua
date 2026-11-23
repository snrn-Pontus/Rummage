local _, ns = ...
local Rummage = ns.core

-- SmartFoodDrink: one macro that eats the SmartPlainFood pick and drinks the
-- SmartDrink pick in the same click, for people short on action slots.
-- Food and drink are off the global cooldown, so both /use lines go through
-- and you sit down with both running.
--
-- Off by default. Turning it on turns the two separate macros off, and
-- turning it off turns them back on. Plain food and drinks are still
-- scanned while their own macros are off; this macro needs their picks.

local function ItemText(candidate)
    return candidate.link or candidate.name or ("item:" .. candidate.itemID)
end

local function Combine(picks)
    local food, drink = picks.plainfood, picks.drink
    -- Food that also restores mana can be both picks; use it once.
    if food and drink and food.itemID == drink.itemID then
        drink = nil
    end
    local shown = food or drink
    if not shown then
        return nil
    end
    return {
        itemID = shown.itemID,
        link = shown.link,
        name = shown.name,
        count = shown.count,
        minLevel = shown.minLevel or 0,
        usable = true,
        food = food,
        drink = drink,
    }
end

local function Describe(candidate)
    local parts = {}
    if candidate.food then
        parts[#parts + 1] = string.format("%s (%d health)", ItemText(candidate.food), candidate.food.amount)
    end
    if candidate.drink then
        parts[#parts + 1] = string.format("%s (%d mana)", ItemText(candidate.drink), candidate.drink.amount)
    end
    return table.concat(parts, " + ")
end

local function MacroBody(candidate)
    local lines = { "#showtooltip" }
    if candidate.food then
        lines[#lines + 1] = "/use item:" .. candidate.food.itemID
    end
    if candidate.drink then
        lines[#lines + 1] = "/use item:" .. candidate.drink.itemID
    end
    return table.concat(lines, "\n")
end

Rummage.RegisterCategory({
    key = "fooddrink",
    label = "Food & drink",
    macroName = "SmartFoodDrink",
    defaultEnabled = false,
    combines = { "plainfood", "drink" },
    combinesNote = "Eats your plain food and drinks your drink in one click, to save an action slot. Turning it on turns off SmartPlainFood and SmartDrink; turning it off turns them back on.",
    Combine = Combine,
    Describe = Describe,
    MacroBody = MacroBody,
})
