local _, ns = ...
local Rummage = ns.core
local stats = ns.stats
local classStats = ns.classStats

-- Stat scrolls (Scroll of Stamina, Intellect, Spirit, Strength, Agility,
-- Protection). Ranked like flasks: your stat priority, or the class and
-- talent default, the highest rank of a matching scroll first, and scrolls
-- your class gets nothing from skipped. A scroll buffs your target when you
-- have one, so the macro always uses it on yourself.

local function IsScroll(subclassID, lines)
    if subclassID == stats.SUBCLASS.SCROLL then
        return true
    end
    local name = lines and lines[1] and lines[1]:lower() or ""
    return name:find("scroll", 1, true) ~= nil
end

local function Classify(itemID, lines)
    local _, _, _, _, _, _, subclassID = (C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant)(itemID)
    if not IsScroll(subclassID, lines) then
        return nil
    end
    -- Only the stat lines count, so scrolls that teleport, summon or teach
    -- something are left out.
    local found = {}
    for index, line in ipairs(lines) do
        if index > 1 then
            stats.ParseStats(stats.Normalise(line), found)
        end
    end
    if next(found) == nil then
        return nil
    end
    return {
        name = lines[1],
        stats = found,
    }
end

Rummage.RegisterCategory({
    key = "scroll",
    label = "Scroll",
    macroName = "SmartScroll",
    defaultPriority = classStats.DefaultPriority,
    -- Talent and spec changes move the default priority.
    events = { "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED" },
    statAliases = stats.aliases,
    statLabels = stats.labels,
    Prefilter = function(itemID, classID, subclassID)
        return classID == nil or classID == stats.CONSUMABLE_CLASS
    end,
    Classify = Classify,
    Rank = classStats.Rank,
    Describe = function(candidate)
        return (candidate.link or candidate.name or ("item:" .. candidate.itemID))
            .. " (" .. (stats.DescribeStats(candidate) or "no stats") .. ")"
    end,
    MacroBody = function(pick)
        return "#showtooltip\n/use [@player] item:" .. pick.itemID
    end,
})
