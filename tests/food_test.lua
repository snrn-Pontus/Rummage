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
