local _, ns = ...

-- Shared helpers for categories: the stat vocabulary, the tooltip stat
-- parser, and a stat-priority ranker. Food, flasks and elixirs all use this.

local stats = {}
ns.stats = stats

stats.CONSUMABLE_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0

-- Consumable subclass IDs, with fallbacks matching every client so far.
local SUBCLASS_ENUM = Enum and Enum.ItemConsumableSubclass or {}
stats.SUBCLASS = {
    GENERIC = SUBCLASS_ENUM.Generic or 0,
    POTION = SUBCLASS_ENUM.Potion or 1,
    ELIXIR = SUBCLASS_ENUM.Elixir or 2,
    FLASK = SUBCLASS_ENUM.Flask or 3,
    SCROLL = SUBCLASS_ENUM.Scroll or 4,
    FOOD = SUBCLASS_ENUM.Fooddrink or 5,
    ENHANCEMENT = SUBCLASS_ENUM.Itemenhancement or 6,
    BANDAGE = SUBCLASS_ENUM.Bandage or 7,
    OTHER = SUBCLASS_ENUM.Other or 8,
}

-- Stat keys, how they appear in tooltips (lower case), and the words accepted
-- in /rummage <category> <stat> ...
stats.STATS = {
    { key = "STAMINA",   label = "Stamina",   phrases = { "stamina" },                                 aliases = { "stamina", "sta", "stam" } },
    { key = "SPIRIT",    label = "Spirit",    phrases = { "spirit" },                                  aliases = { "spirit", "spi" } },
    { key = "STRENGTH",  label = "Strength",  phrases = { "strength" },                                aliases = { "strength", "str" } },
    { key = "AGILITY",   label = "Agility",   phrases = { "agility" },                                 aliases = { "agility", "agi" } },
    { key = "INTELLECT", label = "Intellect", phrases = { "intellect" },                               aliases = { "intellect", "int" } },
    { key = "HASTE",     label = "Haste",     phrases = { "haste rating", "haste" },                   aliases = { "haste" } },
    { key = "CRIT",      label = "Crit",      phrases = { "critical strike rating", "critical strike", "critical hit", "crit" }, aliases = { "crit", "critical", "criticalstrike" } },
    { key = "MASTERY",   label = "Mastery",   phrases = { "mastery rating", "mastery" },               aliases = { "mastery", "mast" } },
    { key = "VERS",      label = "Versatility", phrases = { "versatility" },                           aliases = { "versatility", "vers", "versa" } },
    { key = "HIT",       label = "Hit",       phrases = { "hit rating", "hit chance" },                aliases = { "hit" } },
    { key = "EXPERTISE", label = "Expertise", phrases = { "expertise rating", "expertise" },           aliases = { "expertise", "exp" } },
    { key = "AP",        label = "Attack Power", phrases = { "attack power" },                         aliases = { "ap", "attackpower", "attack" } },
    { key = "SP",        label = "Spell Power", phrases = { "spell power", "spell damage" },           aliases = { "sp", "spellpower", "spell" } },
    { key = "HEALING",   label = "Healing",   phrases = { "healing power", "spell healing", "healing" }, aliases = { "healing", "heal", "healingpower" } },
    { key = "ARMOR",     label = "Armor",     phrases = { "armor" },                                   aliases = { "armor", "armour" } },
    { key = "MP5",       label = "Mana/5",    phrases = { "mana per 5 sec", "mana every 5 sec" },      aliases = { "mp5", "manaregen" } },
    { key = "HP5",       label = "Health/5",  phrases = { "health per 5 sec", "health every 5 sec" },  aliases = { "hp5", "healthregen" } },
    { key = "HEALTH",    label = "Health",    phrases = { "maximum health", "max health", "health" },   aliases = { "health", "hp" } },
    { key = "MANA",      label = "Mana",      phrases = { "maximum mana", "max mana", "mana" },         aliases = { "mana", "mp" } },
}

stats.aliases = {}
stats.labels = {}
local phraseList = {}
for _, stat in ipairs(stats.STATS) do
    stats.labels[stat.key] = stat.label
    for _, alias in ipairs(stat.aliases) do
        stats.aliases[alias] = stat.key
    end
    for _, phrase in ipairs(stat.phrases) do
        phraseList[#phraseList + 1] = { phrase = phrase, key = stat.key }
    end
end
table.sort(phraseList, function(a, b)
    return #a.phrase > #b.phrase
end)

-- "8 of all stats" grants each primary stat.
local ALL_STATS = { "STRENGTH", "AGILITY", "INTELLECT", "STAMINA", "SPIRIT" }

local function TrimWords(text)
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    text = text:gsub("^of%s+", ""):gsub("^your%s+", "")
    return text
end

local function MatchStat(phrase)
    phrase = TrimWords(phrase)
    for _, entry in ipairs(phraseList) do
        if phrase:sub(1, #entry.phrase) == entry.phrase then
            local nextChar = phrase:sub(#entry.phrase + 1, #entry.phrase + 1)
            if nextChar == "" or nextChar == " " then
                return entry.key
            end
        end
    end
    return nil
end
stats.MatchStat = MatchStat

local function AddStat(result, key, amount)
    if key == "ALLSTATS" then
        for _, primary in ipairs(ALL_STATS) do
            AddStat(result, primary, amount)
        end
        return
    end
    if amount > (result[key] or 0) then
        result[key] = amount
    end
end

-- Lower-cases a tooltip, drops thousands separators ("2,000" and pt-BR
-- "2.000") and decimals ("874.8 health" -> "874 health"), then rewrites
-- non-English text into the English wording the parsers expect.
function stats.Normalise(text)
    local result = text:lower()
    local previous
    repeat
        previous = result
        result = result:gsub("(%d)[.,](%d%d%d)%f[^%d]", "%1%2")
    until result == previous
    result = result:gsub("(%d)[.,]%d+", "%1"):gsub(",", "")
    result = ns.locale.Translate(result)
    result = result:gsub("by up to (%d+)", "by %1")
    return result
end

-- Finds the stat a "... by N" phrase ends in, looking at its last few words
-- ("increases your mastery" -> MASTERY).
local function MatchStatTail(phrase)
    local words = {}
    for word in phrase:gmatch("%a+") do
        words[#words + 1] = word
    end
    for start = math.max(1, #words - 3), #words do
        local key = MatchStat(table.concat(words, " ", start))
        if key then
            return key
        end
    end
    return nil
end

-- Spell damage of a single school is not general spell power.
local SCHOOLS = { arcane = true, fire = true, frost = true, nature = true, shadow = true, holy = true }

-- Long-hand tooltip wording, rewritten to the short stat names.
local REWRITES = {
    { "damage and healing done by magical spells and effects", "spell damage" },
    { "damage done by magical spells and effects", "spell damage" },
    { "healing done by magical spells and effects", "healing" },
    { "healing done by spells and effects", "healing" },
}

-- Reads "gain 20 Haste", "8 Stamina and Spirit", "increases your Mastery by
-- 15", "1% Critical Strike chance" and "8 of all stats" out of a normalised
-- tooltip line into result. MatchStat only checks the start of a phrase, so
-- trailing words ("haste for 1 hour") are harmless. Amounts restored by
-- "restores N health" are skipped so a potion's heal is not read as a Health
-- stat. Regeneration ("regenerate 3 mana every 5 seconds", "20 health per 5
-- sec") is Mana/5 or Health/5, not a maximum. Bonuses that only apply
-- "against demons" and single-school spell damage are left out.
function stats.ParseStats(line, result)
    result = result or {}
    local function Regen(key)
        return function(amount)
            AddStat(result, key, tonumber(amount))
            return " "
        end
    end
    line = line:gsub("(%d+)%s+mana%s+every%s+5%s+sec%a*", Regen("MP5")):gsub("(%d+)%s+mana%s+per%s+5%s+sec%a*", Regen("MP5"))
    line = line:gsub("(%d+)%s+health%s+every%s+5%s+sec%a*", Regen("HP5")):gsub("(%d+)%s+health%s+per%s+5%s+sec%a*", Regen("HP5"))
    line = line:gsub("restores?%s+%d+%s+to%s+%d+", " "):gsub("restores?%s+%d+", " "):gsub("heals?%s+%d+", " ")
    for _, rewrite in ipairs(REWRITES) do
        line = line:gsub(rewrite[1], rewrite[2])
    end
    line = line:gsub("by%s+up%s+to%s+(%d)", "by %1")
    line = line:gsub("by%s+%d+%s+against", "against"):gsub("%d+%%?(%s+[%a ]-%s+against%s)", "%1")
    line = line:gsub("(%a+)%s+spell%s+damage", function(word)
        if SCHOOLS[word] then
            return word .. " school damage"
        end
    end)
    for amount, phrase in line:gmatch("(%d+)%%?%s+([%a%s]+)") do
        amount = tonumber(amount)
        if phrase:match("^of all stats") then
            AddStat(result, "ALLSTATS", amount)
        else
            for part in (phrase .. " and "):gmatch("(.-)%s+and%s+") do
                local key = MatchStat(part)
                if key then
                    AddStat(result, key, amount)
                end
            end
        end
    end
    -- "increases strength and stamina by 18" names two stats.
    for phrase, amount in line:gmatch("([%a%s]+)%s+by%s+(%d+)") do
        for part in (phrase .. " and "):gmatch("(.-)%s+and%s+") do
            local key = not part:find("decrease", 1, true) and MatchStatTail(part)
            if key then
                AddStat(result, key, tonumber(amount))
            end
        end
    end
    return result
end

-- "Restores 1050 to 1750 health" -> 1750; "Restores 20% of your maximum
-- health" -> that share of the player's max, times the duration for "2% of
-- your health per second for 25 sec"; "Heals 2000 damage over 8 sec" ->
-- 2000. Returns nil when the text does not restore that resource.
function stats.ParseRestore(text, resource, maxValue)
    -- Regeneration ("8 mana every 5 sec") is a buff, not an amount restored.
    text = text:gsub("%d+%s+%a+%s+every%s+5%s+sec%a*", " "):gsub("%d+%s+%a+%s+per%s+5%s+sec%a*", " ")
    local low, high = text:match("(%d+)%s+to%s+(%d+)%s+" .. resource)
    if not high then
        -- Rejuvenation: "restores 1440 to 1760 mana and health".
        low, high = text:match("(%d+)%s+to%s+(%d+)%s+%a+%s+and%s+" .. resource)
    end
    if high then
        return tonumber(high)
    end
    local percent = text:match("(%d+)%%%s+of%s+[%a%s]-" .. resource)
    if percent and maxValue then
        local seconds = text:match(resource .. "[%a%s]-per%s+second%s+for%s+(%d+)%s+sec")
        return math.floor(maxValue * tonumber(percent) / 100 * (tonumber(seconds) or 1))
    end
    local flat = text:match("restores?%s+(%d+)%s+" .. resource)
        or text:match("heals?%s+(%d+)%s+" .. resource)
        or text:match("(%d+)%s+" .. resource .. "%s+over")
    if resource == "health" and not flat then
        flat = text:match("heals?%s+(%d+)%s+damage")
    end
    return tonumber(flat)
end

-- Rank candidates that carry a .stats table by a stat priority list:
-- the first listed stat a candidate has decides its rank, larger amounts
-- win ties, unlisted stats beat none. Sets .rank and .rankAmount.
function stats.RankByPriority(candidates, priority, ignoreKeys)
    ignoreKeys = ignoreKeys or {}
    for _, candidate in ipairs(candidates) do
        local rank = #priority + 1
        local amount = 0
        for index, key in ipairs(priority) do
            local value = candidate.stats[key]
            if value then
                rank = index
                amount = value
                break
            end
        end
        if rank > #priority then
            for key, value in pairs(candidate.stats) do
                if not ignoreKeys[key] then
                    amount = amount + value
                end
            end
            if amount == 0 then
                rank = #priority + 2
                amount = candidate.fallbackAmount or 0
            end
        end
        candidate.rank = rank
        candidate.rankAmount = amount
    end
    table.sort(candidates, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.rankAmount ~= b.rankAmount then return a.rankAmount > b.rankAmount end
        local fa, fb = a.fallbackAmount or 0, b.fallbackAmount or 0
        if fa ~= fb then return fa > fb end
        if a.count ~= b.count then return a.count > b.count end
        return a.itemID < b.itemID
    end)
end

-- "item link (20 Haste, 8 Stamina)" for chat and the settings page.
function stats.DescribeStats(candidate, ignoreKeys)
    ignoreKeys = ignoreKeys or {}
    local parts = {}
    for _, stat in ipairs(stats.STATS) do
        local value = candidate.stats and candidate.stats[stat.key]
        if value and not ignoreKeys[stat.key] then
            parts[#parts + 1] = string.format("%d %s", value, stat.label)
        end
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, ", ")
end

function stats.ItemName(candidate, lines)
    if lines and lines[1] then
        return lines[1]
    end
    return candidate.link or ("item:" .. tostring(candidate.itemID))
end
