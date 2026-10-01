-- Offline tests for the flask category: class defaults, spec detection and
-- skipping elixirs a class cannot use. Runs Stats.lua and Flask.lua against
-- stubbed WoW APIs and fake tooltips.
--
--   npx -p fengari-node-cli fengari tests/flask_test.lua   (from the repo root)
--   lua tests/flask_test.lua                               (any Lua 5.1+)

-- Fake tooltips, as the client shows them. Item IDs are made up.
local ELIXIRS = {
    agility   = { id = 1, lines = { "Elixir of Minor Agility", "Use: Increases your Agility by 4 for 1 hour." } },
    strength  = { id = 2, lines = { "Elixir of Lion's Strength", "Use: Increases your Strength by 4 for 1 hour." } },
    arcane    = { id = 3, lines = { "Minor Arcane Elixir", "Use: Increases your Spell Power by 5 for 30 min." } },
    wisdom    = { id = 4, lines = { "Elixir of Wisdom", "Use: Increases your Intellect by 6 for 1 hour." } },
    fortitude = { id = 5, lines = { "Elixir of Minor Fortitude", "Use: Increases the player's maximum health by 27 for 1 hour." } },
    spirit    = { id = 6, lines = { "Elixir of Minor Spirit", "Use: Increases your Spirit by 3 for 30 min." } },
    defense   = { id = 7, lines = { "Elixir of Minor Defense", "Use: Increases armor by 50 for 1 hour." } },
    -- Wording from the WoW Forever client.
    mageblood = { id = 8, lines = { "Minor Mageblood Elixir", "Use: Drink to regenerate 3 mana every 5 seconds. Lasts for 30 min.", "Requires Level 5" } },
}

-- World state the stubs read; each test sets it.
local world

local function Reset(class)
    world = { class = class }
end

function UnitClass() return world.class:lower(), world.class end
function tContains(list, value)
    for _, item in ipairs(list) do
        if item == value then return true end
    end
    return false
end
C_Item = {
    -- Seventh return is the subclass; every fake item is an elixir.
    GetItemInfoInstant = function() return nil, nil, nil, nil, nil, 0, 2 end,
}
-- Spec API (retail-style), only present when a test sets world.spec.
local function InstallSpecAPI()
    if world.spec then
        GetSpecialization = function() return 1 end
        GetSpecializationInfo = function() return 1, world.spec.name, "", 0, world.spec.role end
    else
        GetSpecialization, GetSpecializationInfo = nil, nil
    end
end
-- Talent tab API; world.tabs = { { name, points }, ... }. world.newTabs
-- switches to the (id, name, description, icon, points) return shape.
function GetNumTalentTabs() return world.tabs and #world.tabs or 0 end
function GetTalentTabInfo(tab)
    local entry = world.tabs[tab]
    if world.newTabs then
        return 100 + tab, entry[1], "", 0, entry[2]
    end
    return entry[1], "icon", entry[2], "file"
end

-- Load the addon files the way the client does: (addonName, ns).
local category
local ns = { core = { RegisterCategory = function(c) category = c end } }
for _, path in ipairs({ "Categories/Stats.lua", "Categories/Flask.lua" }) do
    local chunk = assert(loadfile(path))
    chunk("Rummage", ns)
end
assert(category and category.key == "flask", "Flask.lua did not register")

-- Runs a scan over the given elixir keys, like Core does: classify, mark
-- usable, rank with priority (or the class default), pick the first usable.
local function Scan(keys, priority)
    InstallSpecAPI()
    local list = {}
    for _, key in ipairs(keys) do
        local elixir = assert(ELIXIRS[key], key)
        local info = category.Classify(elixir.id, elixir.lines)
        assert(info, "did not classify " .. key)
        info.key, info.itemID, info.count, info.minLevel, info.usable = key, elixir.id, 1, 0, true
        list[#list + 1] = info
    end
    priority = priority or category.defaultPriority()
    category.Rank(list, priority)
    local pick
    for _, candidate in ipairs(list) do
        if candidate.usable then
            pick = candidate
            break
        end
    end
    return list, pick and pick.key, priority
end

-- Skipped elixirs keep their rank among themselves (by amount, since their
-- stats are not in the priority), after every usable one.
local function Order(list)
    local keys = {}
    for _, candidate in ipairs(list) do
        keys[#keys + 1] = candidate.key .. (candidate.usable and "" or "(skip)")
    end
    return table.concat(keys, " ")
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

local ALL = { "fortitude", "strength", "arcane", "agility", "wisdom", "spirit", "defense" }

Test("parses every fake tooltip into the right stat", function()
    Reset("HUNTER")
    local expected = { agility = "AGILITY", strength = "STRENGTH", arcane = "SP", wisdom = "INTELLECT",
        fortitude = "HEALTH", spirit = "SPIRIT", defense = "ARMOR", mageblood = "MP5" }
    for key, stat in pairs(expected) do
        local info = category.Classify(ELIXIRS[key].id, ELIXIRS[key].lines)
        assert(info.stats[stat], key .. " has no " .. stat)
    end
end)

Test("mageblood reads as 3 Mana/5 and nothing else", function()
    Reset("MAGE")
    local info = category.Classify(ELIXIRS.mageblood.id, ELIXIRS.mageblood.lines)
    Expect(info.stats.MP5, 3, "MP5")
    Expect(info.stats.MANA, nil, "MANA")
    Expect(next(info.stats, next(info.stats)), nil, "extra stats")
end)

Test("other mana-over-time wordings read as Mana/5", function()
    for _, line in ipairs({ "restores 4 mana per 5 sec. for 1 hour.", "regenerate 12 mana every 5 sec for 1 hour." }) do
        local found = ns.stats.ParseStats(line)
        assert(found.MP5 and not found.MANA, line)
    end
end)

Test("priest: mageblood ranks above spirit and intellect (MP5 before them)", function()
    Reset("PRIEST")
    local list = Scan({ "wisdom", "spirit", "mageblood" })
    Expect(Order(list), "mageblood spirit wisdom", "order")
end)

Test("warrior: mageblood is skipped", function()
    Reset("WARRIOR")
    local list, pick = Scan({ "mageblood", "fortitude" })
    Expect(pick, "fortitude", "pick")
    Expect(Order(list), "fortitude mageblood(skip)", "order")
end)

Test("hunter: agility first, strength and spell power skipped", function()
    Reset("HUNTER")
    local list, pick = Scan(ALL)
    Expect(pick, "agility", "pick")
    Expect(Order(list), "agility wisdom spirit fortitude defense arcane(skip) strength(skip)", "order")
end)

Test("hunter: matches the in-game screenshot (wisdom over fortitude)", function()
    Reset("HUNTER")
    local list, pick = Scan({ "fortitude", "wisdom" })
    Expect(pick, "wisdom", "pick")
    Expect(Order(list), "wisdom fortitude", "order")
end)

Test("mage: spell power first, strength and agility skipped", function()
    Reset("MAGE")
    local list, pick = Scan(ALL)
    Expect(pick, "arcane", "pick")
    Expect(Order(list), "arcane spirit wisdom fortitude defense agility(skip) strength(skip)", "order")
end)

Test("mage with only melee elixirs uses nothing", function()
    Reset("MAGE")
    local list, pick = Scan({ "strength", "agility" })
    Expect(pick, nil, "pick")
    Expect(list[1].unusableReason, "no use to your class", "reason")
end)

Test("mage who lists strength themselves gets it", function()
    Reset("MAGE")
    local _, pick = Scan({ "strength", "agility" }, { "SP", "STRENGTH" })
    Expect(pick, "strength", "pick")
end)

Test("mage with an empty ('any') priority still skips useless stats", function()
    Reset("MAGE")
    local list, pick = Scan({ "strength", "wisdom" }, {})
    Expect(pick, "wisdom", "pick")
    Expect(Order(list), "wisdom strength(skip)", "order")
end)

Test("warrior: strength first, intellect/spirit/spell power skipped", function()
    Reset("WARRIOR")
    local list, pick = Scan(ALL)
    Expect(pick, "strength", "pick")
    Expect(Order(list), "strength agility fortitude defense wisdom(skip) arcane(skip) spirit(skip)", "order")
end)

Test("rogue: agility first", function()
    Reset("ROGUE")
    local _, pick = Scan(ALL)
    Expect(pick, "agility", "pick")
end)

Test("warlock: spell power, then intellect, then health", function()
    Reset("WARLOCK")
    local list = Scan({ "fortitude", "wisdom", "arcane" })
    Expect(Order(list), "arcane wisdom fortitude", "order")
end)

Test("unspecced paladin: strength first, nothing skipped", function()
    Reset("PALADIN")
    local list, pick = Scan(ALL)
    Expect(pick, "strength", "pick")
    for _, candidate in ipairs(list) do
        assert(candidate.usable, candidate.key .. " was skipped")
    end
end)

Test("holy paladin (classic talent tabs): spell power first, strength skipped", function()
    Reset("PALADIN")
    world.tabs = { { "Holy", 11 }, { "Protection", 0 }, { "Retribution", 2 } }
    local list, pick = Scan(ALL)
    Expect(pick, "arcane", "pick")
    assert(not list[#list].usable, "last should be skipped")
end)

Test("protection paladin: strength first, health before agility", function()
    Reset("PALADIN")
    world.tabs = { { "Holy", 0 }, { "Protection", 8 }, { "Retribution", 0 } }
    local list, pick = Scan({ "agility", "fortitude", "strength", "defense" })
    Expect(pick, "strength", "pick")
    Expect(Order(list), "strength defense fortitude agility", "order")
end)

Test("enhancement shaman (newer talent tab shape): strength first", function()
    Reset("SHAMAN")
    world.newTabs = true
    world.tabs = { { "Elemental", 1 }, { "Enhancement", 9 }, { "Restoration", 0 } }
    local _, pick = Scan(ALL)
    Expect(pick, "strength", "pick")
end)

Test("restoration druid via spec API (HEALER role)", function()
    Reset("DRUID")
    world.spec = { name = "Restoration", role = "HEALER" }
    local list, pick = Scan(ALL)
    Expect(pick, "arcane", "pick")
    Expect(Order(list), "arcane wisdom spirit fortitude defense agility(skip) strength(skip)", "order")
end)

Test("feral druid via spec API (DAMAGER role, matched by name)", function()
    Reset("DRUID")
    world.spec = { name = "Feral", role = "DAMAGER" }
    local _, pick = Scan(ALL)
    Expect(pick, "strength", "pick")
end)

Test("unknown spec name falls back to the class default", function()
    Reset("DRUID")
    world.spec = { name = "Wildheart", role = "DAMAGER" }
    local _, pick, priority = Scan(ALL)
    Expect(priority[1], "SP", "first stat of druid default")
    Expect(pick, "arcane", "pick")
end)

Test("tied talent points pick the first tree", function()
    Reset("SHAMAN")
    world.tabs = { { "Elemental", 5 }, { "Enhancement", 5 }, { "Restoration", 0 } }
    local _, pick = Scan(ALL)
    Expect(pick, "arcane", "pick")
end)

Test("unknown class gets the generic list and skips nothing", function()
    Reset("DEATHKNIGHT")
    local list, pick, priority = Scan(ALL)
    Expect(priority[1], "STRENGTH", "first stat")
    Expect(pick, "strength", "pick")
    for _, candidate in ipairs(list) do
        assert(candidate.usable, candidate.key .. " was skipped")
    end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
