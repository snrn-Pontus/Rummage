-- Offline tests for the shared tooltip parser (Stats.lua) and drink ranking,
-- against tooltip wording from the WoW Forever and Classic clients.
--
--   npx -p fengari-node-cli fengari tests/stats_test.lua   (from the repo root)
--   lua tests/stats_test.lua                               (any Lua 5.1+)

function UnitHealthMax() return 1000 end
function UnitPowerMax() return 1000 end

local categories = {}
local ns = { core = { RegisterCategory = function(c) categories[c.key] = c end } }
for _, path in ipairs({ "Locale.lua", "Categories/Stats.lua", "Categories/Drink.lua" }) do
    assert(loadfile(path))("Rummage", ns)
end
local stats = ns.stats

local passed, failed = 0, 0
local function Test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("ok   " .. name)
    else
        failed = failed + 1
        print("FAIL " .. name .. "\n     " .. tostring(err))
    end
end

local function Expect(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", what or "value", tostring(expected), tostring(actual)), 2)
    end
end

-- Parses a line and returns its stats as "KEY=n,KEY=n", sorted.
local function Parse(line)
    local parts = {}
    for key, amount in pairs(stats.ParseStats(stats.Normalise(line), {})) do
        parts[#parts + 1] = key .. "=" .. amount
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

local CASES = {
    { "spell damage (food)", "If you spend at least 10 sec eating, you will become well fed and gain 22 Spell Damage for 15 min.", "SP=22" },
    { "healing power (tea)", "If you spend at least 10 sec eating, you will become well fed and gain 2 Healing Power for 15 min.", "HEALING=2" },
    { "percent crit (food)", "If you spend at least 10 sec eating, you will become well fed and gain 1% Critical Strike chance for 15 min.", "CRIT=1" },
    { "spell damage by up to", "Use: Increases spell damage by up to 35 for 1 hour.", "SP=35" },
    { "magical spells and effects", "Use: Increases damage done by magical spells and effects by up to 150 for 2 hrs.", "SP=150" },
    { "healing by spells and effects", "Use: Drink to increase healing done by spells and effects by up to 40. Lasts 1800 sec.", "HEALING=40" },
    { "one school is not spell power", "Use: Drink to increase nature spell damage by up to 40. Lasts 1800 sec.", "" },
    { "one school, classic wording", "Use: Increases spell shadow damage by up to 40 for 30 min.", "" },
    { "two stats by one amount", "Use: Increases Strength and Stamina by 18 for 1 hour.", "STAMINA=18,STRENGTH=18" },
    { "stat and percent crit", "Use: Increases Agility by 25 and chance to get a critical strike by 2% for 1 hour.", "AGILITY=25,CRIT=2" },
    { "health regeneration", "Use: Regenerate 20 health every 5 sec for 1 hour.", "HP5=20" },
    { "only against demons", "Use: Increases attack power by 265 against demons. Lasts 5 min.", "" },
    { "percent hit chance", "Use: Gives 60 Stamina and 5% Hit Chance while in Mount Hyjal.", "HIT=5,STAMINA=60" },
    { "a decrease is not a stat", "Use: Increases your Intellect by 4 and decreases your Stamina by 5 for 5 min.", "INTELLECT=4" },
}
for _, case in ipairs(CASES) do
    Test("parse: " .. case[1], function()
        Expect(Parse(case[2]), case[3], "stats")
    end)
end

Test("restore: percent per second counts the whole duration", function()
    local text = stats.Normalise("Use: Restores 2% of your health per second for 25 sec. Must remain seated while eating.")
    Expect(stats.ParseRestore(text, "health", 1000), 500, "health")
end)

Test("restore: health and mana per second", function()
    local text = stats.Normalise("Use: Restores 4% of your health and mana per second for 25 sec. Must remain seated while eating.")
    Expect(stats.ParseRestore(text, "health", 1000), 1000, "health")
    Expect(stats.ParseRestore(text, "mana", 1000), 1000, "mana")
end)

Test("restore: one-off percent is unchanged", function()
    Expect(stats.ParseRestore("restores 20% of your maximum health", "health", 1000), 200, "health")
end)

Test("drink: buff drinks come after every plain drink", function()
    local drinks = {
        { id = 1, lines = { "Wicked Smoothie", "Use: Restores 2821 mana over 30 sec. Must remain seated while drinking. If you spend at least 10 sec eating, you will become well fed and gain 20 Spirit for 15 min." } },
        { id = 2, lines = { "Conjured Water", "Use: Restores 1344 mana over 30 sec. Must remain seated while drinking." } },
    }
    local list = {}
    for _, drink in ipairs(drinks) do
        local info = assert(categories.drink.Classify(drink.id, drink.lines))
        info.itemID, info.count = drink.id, 1
        list[#list + 1] = info
    end
    categories.drink.Rank(list)
    Expect(list[1].name, "Conjured Water", "first")
    Expect(list[2].name, "Wicked Smoothie", "second")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
