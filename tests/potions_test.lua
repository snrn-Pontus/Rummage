-- Offline tests for the health and mana potion categories: pure potions
-- before ones that restore both (Rejuvenation), which stay as a fallback.
--
--   npx -p fengari-node-cli fengari tests/potions_test.lua   (from the repo root)
--   lua tests/potions_test.lua                               (any Lua 5.1+)

local POTIONS = {
    healing = { id = 1, lines = { "Minor Healing Potion", "Use: Restores 70 to 90 health." } },
    mana    = { id = 2, lines = { "Minor Mana Potion", "Use: Restores 140 to 180 mana." } },
    lesser  = { id = 3, lines = { "Lesser Healing Potion", "Use: Restores 140 to 180 health." } },
    rejuv   = { id = 4, lines = { "Minor Rejuvenation Potion", "Use: Restores 90 to 150 mana and 90 to 150 health.", "Requires Level 5" } },
}

function UnitHealthMax() return 500 end
function UnitPowerMax() return 400 end
C_Item = {
    -- Seventh return is the subclass; every fake item is a potion.
    GetItemInfoInstant = function() return nil, nil, nil, nil, nil, 0, 1 end,
}

local categories = {}
local ns = { core = { RegisterCategory = function(c) categories[c.key] = c end } }
for _, path in ipairs({ "Categories/Stats.lua", "Categories/Potions.lua" }) do
    assert(loadfile(path))("Rummage", ns)
end

-- Classify every potion, rank, and return the keys in order (nil if a
-- potion was not picked up by the category).
local function Scan(categoryKey, keys)
    local category = assert(categories[categoryKey], categoryKey)
    local list = {}
    for _, key in ipairs(keys) do
        local potion = POTIONS[key]
        local info = category.Classify(potion.id, potion.lines)
        if info then
            info.key, info.itemID, info.count = key, potion.id, 1
            list[#list + 1] = info
        end
    end
    category.Rank(list)
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

Test("rejuvenation reads as 150 of both", function()
    local _, health = Scan("healthpotion", { "rejuv" })
    local _, mana = Scan("manapotion", { "rejuv" })
    Expect(health[1].amount, 150, "health")
    Expect(mana[1].amount, 150, "mana")
    assert(health[1].restoresBoth and mana[1].restoresBoth, "not flagged as restoring both")
end)

Test("health: a weaker pure healing potion beats rejuvenation", function()
    Expect(Scan("healthpotion", { "rejuv", "healing" }), "healing rejuv", "order")
end)

Test("health: pure potions by amount, rejuvenation last", function()
    Expect(Scan("healthpotion", { "rejuv", "healing", "lesser", "mana" }), "lesser healing rejuv", "order")
end)

Test("health: rejuvenation is used when it is all you have", function()
    Expect(Scan("healthpotion", { "rejuv", "mana" }), "rejuv", "order")
end)

Test("mana: pure mana potion first, rejuvenation after", function()
    Expect(Scan("manapotion", { "rejuv", "mana", "healing" }), "mana rejuv", "order")
end)

Test("pure potions are not flagged", function()
    local _, list = Scan("healthpotion", { "healing" })
    Expect(list[1].restoresBoth, false, "restoresBoth")
end)

Test("describe mentions the other resource", function()
    local _, list = Scan("healthpotion", { "rejuv" })
    Expect(categories.healthpotion.Describe(list[1]), "Minor Rejuvenation Potion (150 health, also mana)", "text")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
