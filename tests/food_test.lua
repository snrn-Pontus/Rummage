-- Offline tests for the two food categories: SmartFood (buff food, by stat
-- priority) and SmartPlainFood (food without a buff, most health first).
--
--   npx -p fengari-node-cli fengari tests/food_test.lua   (from the repo root)
--   lua tests/food_test.lua                               (any Lua 5.1+)

-- Fake tooltips, as the client shows them. Item IDs are made up.
local FOOD = {
    bread    = { id = 1, lines = { "Tough Hunk of Bread", "Use: Restores 61 health over 18 sec. Must remain seated while eating." } },
    cheese   = { id = 2, lines = { "Dalaran Sharp", "Use: Restores 243 health over 21 sec. Must remain seated while eating." } },
    jerky    = { id = 3, lines = { "Herb Baked Egg", "Use: Restores 61 health over 18 sec. Must remain seated while eating. If you spend at least 10 seconds eating you will become well fed and gain 2 Stamina and Spirit for 15 min." } },
    sagefish = { id = 4, lines = { "Sagefish Delight", "Use: Restores 840 health and 630 mana over 30 sec. Must remain seated while eating. If you spend at least 10 seconds eating you will become well fed and gain 6 Mana every 5 seconds for 15 min." } },
    water    = { id = 5, lines = { "Refreshing Spring Water", "Use: Restores 151 mana over 18 sec. Must remain seated while drinking." } },
    yellowtail = { id = 7, lines = { "Spotted Yellowtail", "Use: Restores 1,338 health over 30 sec. Must remain seated while eating. If you spend at least 10 sec eating, you will become well fed and gain 22 Spell Damage for 15 min. Additionally, experience gained from kills is increased by 5%. (1 Sec Cooldown)" } },
    tea      = { id = 8, lines = { "Peace Tea", "Use: Restores 100 mana over 30 sec. Must remain seated while drinking. If you spend at least 10 sec eating, you will become well fed and gain 2 Healing Power for 15 min." } },
    squid    = { id = 9, lines = { "Grilled Squid", "Use: Restores 874 health over 27 sec. Must remain seated while eating. If you spend at least 10 sec eating, you will become well fed and gain 1% Critical Strike chance for 15 min." } },
    sunfruit = { id = 10, lines = { "Blessed Sunfruit", "Use: Restores 1933 health over 27 sec. Must remain seated while eating. Also increases your Strength by 10 for 10 min." } },
    harvest  = { id = 11, lines = { "Harvest Bread", "Use: Restores 2% of your health per second for 25 sec. Must remain seated while eating." } },
    strudel  = { id = 6, lines = { "Conjured Mana Strudel", "Use: Restores 2148 health and 4410 mana over 30 sec. Must remain seated while eating." } },
}

function UnitHealthMax() return 500 end
function UnitPowerMax() return 400 end

local categories = {}
local ns = { core = { RegisterCategory = function(c) categories[c.key] = c end } }
for _, path in ipairs({ "Categories/Stats.lua", "Categories/Food.lua" }) do
    assert(loadfile(path))("Rummage", ns)
end

local function Scan(categoryKey, keys, priority)
    local category = assert(categories[categoryKey], categoryKey)
    local list = {}
    for _, key in ipairs(keys) do
        local food = FOOD[key]
        local info = category.Classify(food.id, food.lines)
        if info then
            info.key, info.itemID, info.count = key, food.id, 1
            list[#list + 1] = info
        end
    end
    category.Rank(list, priority or category.defaultPriority)
    local order = {}
    for _, candidate in ipairs(list) do
        order[#order + 1] = candidate.key
    end
    return table.concat(order, " "), list
end

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

local ALL = { "bread", "cheese", "jerky", "sagefish", "water", "strudel" }

Test("macros: SmartFood keeps the food key, plain food has its own", function()
    Expect(categories.food.macroName, "SmartFood", "buff macro")
    Expect(categories.plainfood.macroName, "SmartPlainFood", "plain macro")
    assert(categories.food.statAliases, "buff food keeps its stat priority")
    assert(not categories.plainfood.statAliases, "plain food has no priority")
end)

Test("buff food: only Well Fed food, never plain food", function()
    Expect(Scan("food", ALL, { "STAMINA" }), "jerky sagefish", "order")
end)

Test("buff food: priority still decides", function()
    Expect(Scan("food", ALL, { "MP5" }), "sagefish jerky", "order")
end)

Test("buff food: Spell Damage counts as Spell Power", function()
    local _, list = Scan("food", { "yellowtail" })
    Expect(list[1].stats.SP, 22, "spell power")
    Expect(Scan("food", { "jerky", "yellowtail" }, { "SP", "STAMINA" }), "yellowtail jerky", "order")
end)

Test("buff food: Forever wording (Healing Power, % crit, no Well Fed)", function()
    local _, list = Scan("food", { "tea", "squid", "sunfruit" }, { "HEALING", "CRIT", "STRENGTH" })
    Expect(list[1].stats.HEALING, 2, "tea")
    Expect(list[2].stats.CRIT, 1, "squid")
    Expect(list[3].stats.STRENGTH, 10, "sunfruit")
    Expect(Scan("plainfood", { "sunfruit" }), "", "sunfruit is not plain food")
end)

Test("plain food: percent per second food counts its whole heal", function()
    Expect(Scan("plainfood", { "cheese", "harvest" }), "harvest cheese", "order")
end)

Test("buff food: nothing when you only carry plain food", function()
    Expect(Scan("food", { "bread", "cheese" }), "", "order")
end)

Test("plain food: no buff food, no drinks, most health first", function()
    Expect(Scan("plainfood", ALL), "strudel cheese bread", "order")
end)

Test("plain food: nothing when you only carry buff food", function()
    Expect(Scan("plainfood", { "jerky", "sagefish" }), "", "order")
end)

Test("plain food: describe shows health", function()
    local _, list = Scan("plainfood", { "cheese" })
    Expect(categories.plainfood.Describe(list[1]), "Dalaran Sharp (243 health)", "text")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
