local _, ns = ...
local Rummage = ns.core
local stats = ns.stats

-- Flasks and elixirs: consumables that raise a stat for a long duration.
-- Ranked by the same stat priority mechanism as food, with a default order
-- picked from your class and talents. Battle and guardian elixirs are not
-- told apart yet; the macro simply uses the best match, so keep the second
-- elixir type on its own slot if you use both.

local OVERRIDES = {
}

-- Default priorities per class and role, after the WoW Forever guides on
-- Icy Veins (Sept 2026): melee want Strength/Agility and Attack Power, casters
-- want Spell Power (healing includes a share of it), then Spirit/Intellect for
-- mana. useless lists stats an elixir would be wasted on for that role; an
-- elixir that only gives those is never used unless you list the stat yourself.
local MELEE_STR = { "STRENGTH", "AP", "AGILITY", "CRIT", "HIT", "STAMINA", "HEALTH", "ARMOR" }
local MELEE_AGI = { "AGILITY", "AP", "STRENGTH", "CRIT", "HIT", "STAMINA", "HEALTH", "ARMOR" }
local CASTER = { "SP", "INTELLECT", "SPIRIT", "MP5", "MANA", "CRIT", "HIT", "STAMINA", "HEALTH", "ARMOR" }
local NO_MANA = { INTELLECT = true, SPIRIT = true, SP = true, MP5 = true, MANA = true }
local NO_MELEE = { STRENGTH = true, AGILITY = true, AP = true }

local PROFILES = {
    WARRIOR = { default = { priority = MELEE_STR, useless = NO_MANA } },
    ROGUE = { default = { priority = MELEE_AGI, useless = NO_MANA } },
    HUNTER = { default = {
        priority = { "AGILITY", "AP", "CRIT", "HIT", "INTELLECT", "SPIRIT", "MP5", "STAMINA", "HEALTH", "ARMOR" },
        useless = { STRENGTH = true, SP = true },
    } },
    MAGE = { default = { priority = { "SP", "SPIRIT", "INTELLECT", "MP5", "MANA", "CRIT", "HIT", "STAMINA", "HEALTH", "ARMOR" }, useless = NO_MELEE } },
    WARLOCK = { default = { priority = { "SP", "STAMINA", "INTELLECT", "SPIRIT", "MP5", "MANA", "HEALTH", "CRIT", "HIT", "ARMOR" }, useless = NO_MELEE } },
    PRIEST = { default = { priority = { "SP", "MP5", "SPIRIT", "INTELLECT", "MANA", "STAMINA", "HEALTH", "CRIT", "HIT", "ARMOR" }, useless = NO_MELEE } },
    PALADIN = {
        default = { priority = { "STRENGTH", "AP", "AGILITY", "CRIT", "HIT", "INTELLECT", "STAMINA", "HEALTH", "ARMOR", "SP", "MP5", "SPIRIT" } },
        caster = { priority = CASTER, useless = NO_MELEE },
        tank = { priority = { "STRENGTH", "STAMINA", "ARMOR", "HEALTH", "AGILITY", "HIT", "AP", "INTELLECT" } },
    },
    SHAMAN = {
        default = { priority = { "STRENGTH", "AGILITY", "AP", "INTELLECT", "CRIT", "HIT", "SP", "MP5", "STAMINA", "HEALTH", "ARMOR", "SPIRIT" } },
        caster = { priority = CASTER, useless = NO_MELEE },
    },
    DRUID = {
        -- Unspecced druids level on Wrath, so casting comes first.
        default = { priority = { "SP", "INTELLECT", "SPIRIT", "STRENGTH", "AGILITY", "AP", "MP5", "STAMINA", "HEALTH", "ARMOR" } },
        caster = { priority = CASTER, useless = NO_MELEE },
        melee = { priority = { "STRENGTH", "AGILITY", "AP", "CRIT", "HIT", "STAMINA", "HEALTH", "ARMOR", "INTELLECT" } },
        tank = { priority = { "STAMINA", "ARMOR", "AGILITY", "STRENGTH", "HEALTH", "HIT", "AP", "INTELLECT" } },
    },
}

local SPEC_ROLES = {
    holy = "caster", discipline = "caster", restoration = "caster", balance = "caster", elemental = "caster",
    protection = "tank", guardian = "tank",
    retribution = "melee", feral = "melee", enhancement = "melee",
}

-- The tree with the most talent points, by name. Classic clients return
-- (name, icon, points, ...); later ones (id, name, description, icon, points, ...).
local function MainTalentTree()
    if not GetNumTalentTabs or not GetTalentTabInfo then
        return nil
    end
    local bestName, bestPoints = nil, 0
    for tab = 1, GetNumTalentTabs() do
        local a, b, c, _, e = GetTalentTabInfo(tab)
        local name, points = a, c
        if type(a) == "number" then
            name, points = b, e
        end
        if type(points) == "number" and points > bestPoints then
            bestName, bestPoints = name, points
        end
    end
    return bestName
end

-- "caster", "melee", "tank" or nil when the character has no spec yet.
local function PlayerRole()
    if GetSpecialization and GetSpecializationInfo then
        local spec = GetSpecialization()
        if spec and spec > 0 then
            local _, name, _, _, role = GetSpecializationInfo(spec)
            if role == "HEALER" then
                return "caster"
            elseif role == "TANK" then
                return "tank"
            end
            return name and SPEC_ROLES[name:lower()] or nil
        end
    end
    local tree = MainTalentTree()
    return tree and SPEC_ROLES[tree:lower()] or nil
end

local function PlayerProfile()
    local _, classFile = UnitClass("player")
    local profiles = PROFILES[classFile]
    if not profiles then
        return nil
    end
    local role = PlayerRole()
    return role and profiles[role] or profiles.default
end

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

local FALLBACK_PRIORITY = { "STRENGTH", "AGILITY", "INTELLECT", "HASTE", "CRIT", "MASTERY", "VERS", "AP", "SP", "STAMINA", "HEALTH" }

local function DefaultPriority()
    local profile = PlayerProfile()
    return profile and profile.priority or FALLBACK_PRIORITY
end

-- True when every stat on the elixir is one this class gets nothing from.
-- Stats the player put in their own priority always count as useful.
local function IsWasted(candidate, useless, priority)
    for key in pairs(candidate.stats) do
        if not useless[key] or tContains(priority, key) then
            return false
        end
    end
    return true
end

local function Rank(candidates, priority)
    stats.RankByPriority(candidates, priority)
    local profile = PlayerProfile()
    local useless = profile and profile.useless
    if not useless then
        return
    end
    local kept, wasted = {}, {}
    for _, candidate in ipairs(candidates) do
        if IsWasted(candidate, useless, priority) then
            candidate.usable = false
            candidate.unusableReason = "no use to your class"
            wasted[#wasted + 1] = candidate
        else
            kept[#kept + 1] = candidate
        end
    end
    for _, candidate in ipairs(wasted) do
        kept[#kept + 1] = candidate
    end
    for index, candidate in ipairs(kept) do
        candidates[index] = candidate
    end
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
    defaultPriority = DefaultPriority,
    -- Talent and spec changes move the default priority.
    events = { "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED" },
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
