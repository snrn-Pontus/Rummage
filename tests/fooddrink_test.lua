-- Offline tests for SmartFoodDrink: one macro that uses the SmartPlainFood
-- and SmartDrink picks together.
--
--   npx -p fengari-node-cli fengari tests/fooddrink_test.lua   (from the repo root)
--   lua tests/fooddrink_test.lua                               (any Lua 5.1+)

-- Fake tooltips, as the client shows them. Item IDs are made up.
local ITEMS = {
    bread   = { id = 1, lines = { "Tough Hunk of Bread", "Use: Restores 61 health over 18 sec. Must remain seated while eating." } },
    cheese  = { id = 2, lines = { "Dalaran Sharp", "Use: Restores 243 health over 21 sec. Must remain seated while eating." } },
    water   = { id = 5, lines = { "Refreshing Spring Water", "Use: Restores 151 mana over 18 sec. Must remain seated while drinking." } },
    juice   = { id = 7, lines = { "Moonberry Juice", "Use: Restores 1344 mana over 27 sec. Must remain seated while drinking." } },
    strudel = { id = 6, lines = { "Conjured Mana Strudel", "Use: Restores 2148 health and 4410 mana over 30 sec. Must remain seated while eating." } },
}

function UnitHealthMax() return 500 end
function UnitPowerMax() return 400 end

local categories = {}
local ns = { core = { RegisterCategory = function(c) categories[c.key] = c end } }
for _, path in ipairs({ "Categories/Stats.lua", "Categories/Food.lua", "Categories/Drink.lua", "Categories/FoodDrink.lua" }) do
    assert(loadfile(path))("Rummage", ns)
end

-- The pick a category would make from these items, as the core does it.
local function Pick(categoryKey, keys)
    local category = categories[categoryKey]
    local list = {}
    for _, key in ipairs(keys) do
        local item = ITEMS[key]
        local info = category.Classify(item.id, item.lines)
        if info then
            info.itemID, info.count, info.usable, info.minLevel = item.id, 1, true, 0
            list[#list + 1] = info
        end
    end
    category.Rank(list, category.defaultPriority)
    return list[1]
end

local function Combine(keys)
    local combined = categories.fooddrink
    local picks = {}
    for _, part in ipairs(combined.combines) do
        picks[part] = Pick(part, keys)
    end
    return combined.Combine(picks)
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

Test("category: off by default, combines plain food and drink", function()
    local combined = categories.fooddrink
    Expect(combined.macroName, "SmartFoodDrink", "macro")
    Expect(combined.defaultEnabled, false, "default")
    Expect(table.concat(combined.combines, " "), "plainfood drink", "combines")
end)

Test("macro: best food, then best drink", function()
    local pick = Combine({ "bread", "cheese", "water", "juice" })
    Expect(categories.fooddrink.MacroBody(pick), "#showtooltip\n/use item:2\n/use item:7", "body")
    Expect(pick.itemID, 2, "shown item")
end)

Test("macro: describe lists both", function()
    local pick = Combine({ "cheese", "water" })
    Expect(categories.fooddrink.Describe(pick), "Dalaran Sharp (243 health) + Refreshing Spring Water (151 mana)", "text")
end)

Test("macro: only food when you carry no drink", function()
    local pick = Combine({ "bread" })
    Expect(categories.fooddrink.MacroBody(pick), "#showtooltip\n/use item:1", "body")
end)

Test("macro: only drink when you carry no food", function()
    local pick = Combine({ "water" })
    Expect(categories.fooddrink.MacroBody(pick), "#showtooltip\n/use item:5", "body")
    Expect(pick.itemID, 5, "shown item")
end)

Test("macro: an item that is both picks is used once", function()
    local pick = Combine({ "strudel" })
    Expect(categories.fooddrink.MacroBody(pick), "#showtooltip\n/use item:6", "body")
end)

Test("macro: nothing to pick", function()
    Expect(Combine({}), nil, "pick")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
