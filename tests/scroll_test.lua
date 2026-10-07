-- Offline tests for the scroll category: stat parsing, the highest rank of a
-- scroll winning, class defaults shared with flasks, and skipping scrolls a
-- class cannot use. Runs Stats.lua, Flask.lua and Scroll.lua against stubbed
-- WoW APIs and fake tooltips.
--
--   npx -p fengari-node-cli fengari tests/scroll_test.lua   (from the repo root)
--   lua tests/scroll_test.lua                               (any Lua 5.1+)

-- Fake tooltips, as the client shows them. Item IDs are made up; subclass is
-- the consumable subclass GetItemInfoInstant reports (4 = Scroll, 0 = Generic).
local SCROLLS = {
    stamina    = { id = 1, subclass = 4, lines = { "Scroll of Stamina", "Use: Increases the target's Stamina by 3 for 30 min." } },
    stamina2   = { id = 2, subclass = 4, lines = { "Scroll of Stamina II", "Use: Increases the target's Stamina by 7 for 30 min.", "Requires Level 25" } },
    intellect  = { id = 3, subclass = 4, lines = { "Scroll of Intellect", "Use: Increases the target's Intellect by 4 for 30 min." } },
    intellect2 = { id = 4, subclass = 4, lines = { "Scroll of Intellect II", "Use: Increases the target's Intellect by 8 for 30 min." } },
    spirit     = { id = 5, subclass = 4, lines = { "Scroll of Spirit", "Use: Increases the target's Spirit by 3 for 30 min." } },
    strength   = { id = 6, subclass = 4, lines = { "Scroll of Strength", "Use: Increases the target's Strength by 5 for 30 min." } },
    agility    = { id = 7, subclass = 4, lines = { "Scroll of Agility", "Use: Increases the target's Agility by 5 for 30 min." } },
    protection = { id = 8, subclass = 4, lines = { "Scroll of Protection", "Use: Increases the target's Armor by 60 for 30 min." } },
    -- Clients that file scrolls under Generic: found by name.
    generic    = { id = 9, subclass = 0, lines = { "Scroll of Agility II", "Use: Increases the target's Agility by 9 for 30 min." } },
    -- Not stat scrolls.
    recipe     = { id = 10, subclass = 0, lines = { "Scroll of Teleportation", "Use: Teleports the caster to the nearest graveyard." } },
    elixir     = { id = 11, subclass = 2, lines = { "Elixir of Minor Agility", "Use: Increases your Agility by 4 for 1 hour." } },
}

local world

local function Reset(class)
    world = { class = class }
end

local subclassByID = {}
for _, scroll in pairs(SCROLLS) do
    subclassByID[scroll.id] = scroll.subclass
end

function UnitClass() return world.class:lower(), world.class end
function tContains(list, value)
    for _, item in ipairs(list) do
        if item == value then return true end
    end
    return false
end
C_Item = {
    GetItemInfoInstant = function(itemID) return nil, nil, nil, nil, nil, 0, subclassByID[itemID] end,
}
function GetNumTalentTabs() return world.tabs and #world.tabs or 0 end
function GetTalentTabInfo(tab)
    local entry = world.tabs[tab]
    return entry[1], "icon", entry[2], "file"
end

-- Load the addon files the way the client does: (addonName, ns).
local categories = {}
local ns = { core = { RegisterCategory = function(c) categories[c.key] = c end } }
for _, path in ipairs({ "Categories/Stats.lua", "Categories/Flask.lua", "Categories/Scroll.lua" }) do
    assert(loadfile(path))("Rummage", ns)
end
local category = assert(categories.scroll, "Scroll.lua did not register")

-- Classify, mark usable, rank with priority (or the class default) and pick
-- the first usable, like Core does.
local function Scan(keys, priority)
    local list = {}
    for _, key in ipairs(keys) do
        local scroll = assert(SCROLLS[key], key)
        local info = category.Classify(scroll.id, scroll.lines)
        assert(info, "did not classify " .. key)
        info.key, info.itemID, info.count, info.minLevel, info.usable = key, scroll.id, 1, 0, true
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
    return list, pick and pick.key
end

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

local ALL = { "stamina", "intellect", "spirit", "strength", "agility", "protection" }

Test("parses every scroll into its stat and amount", function()
    Reset("HUNTER")
    local expected = { stamina = { "STAMINA", 3 }, stamina2 = { "STAMINA", 7 }, intellect = { "INTELLECT", 4 },
        spirit = { "SPIRIT", 3 }, strength = { "STRENGTH", 5 }, agility = { "AGILITY", 5 },
        protection = { "ARMOR", 60 }, generic = { "AGILITY", 9 } }
    for key, stat in pairs(expected) do
        local info = assert(category.Classify(SCROLLS[key].id, SCROLLS[key].lines), key)
        Expect(info.stats[stat[1]], stat[2], key .. " " .. stat[1])
        Expect(next(info.stats, next(info.stats)), nil, key .. " extra stats")
    end
end)

Test("non-stat scrolls and elixirs are not scrolls", function()
    Reset("HUNTER")
    Expect(category.Classify(SCROLLS.recipe.id, SCROLLS.recipe.lines), nil, "teleport scroll")
    Expect(category.Classify(SCROLLS.elixir.id, SCROLLS.elixir.lines), nil, "elixir")
end)

Test("the flask category does not take scrolls", function()
    Reset("HUNTER")
    Expect(categories.flask.Classify(SCROLLS.agility.id, SCROLLS.agility.lines), nil, "flask")
end)

Test("highest rank of the same stat wins", function()
    Reset("MAGE")
    local _, pick = Scan({ "intellect", "intellect2" })
    Expect(pick, "intellect2", "pick")
    local _, pick2 = Scan({ "stamina", "stamina2" }, { "STAMINA" })
    Expect(pick2, "stamina2", "pick")
end)

Test("warrior: strength first, intellect and spirit skipped", function()
    Reset("WARRIOR")
    local list, pick = Scan(ALL)
    Expect(pick, "strength", "pick")
    Expect(Order(list), "strength agility stamina protection intellect(skip) spirit(skip)", "order")
end)

Test("rogue: agility first", function()
    Reset("ROGUE")
    local _, pick = Scan(ALL)
    Expect(pick, "agility", "pick")
end)

Test("mage: spirit, then intellect, strength and agility skipped", function()
    Reset("MAGE")
    local list, pick = Scan(ALL)
    Expect(pick, "spirit", "pick")
    Expect(Order(list), "spirit intellect stamina protection strength(skip) agility(skip)", "order")
end)

Test("mage with only melee scrolls uses nothing", function()
    Reset("MAGE")
    local list, pick = Scan({ "strength", "agility" })
    Expect(pick, nil, "pick")
    Expect(list[1].unusableReason, "no use to your class", "reason")
end)

Test("own priority overrides the class default and the skip", function()
    Reset("MAGE")
    local _, pick = Scan({ "strength", "intellect" }, { "STRENGTH" })
    Expect(pick, "strength", "pick")
end)

Test("protection paladin: strength, then stamina and armor", function()
    Reset("PALADIN")
    world.tabs = { { "Holy", 0 }, { "Protection", 8 }, { "Retribution", 0 } }
    local list = Scan({ "agility", "protection", "stamina", "strength" })
    Expect(Order(list), "strength stamina protection agility", "order")
end)

Test("macro uses the scroll on yourself", function()
    Expect(category.MacroBody({ itemID = 42 }), "#showtooltip\n/use [@player] item:42", "macro")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
