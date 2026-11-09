-- Offline tests for the tooltip cache: a tooltip read before the item's
-- data has loaded must not be cached, or the item stays unrecognised until
-- /reload (looted bandages or potions not showing up in their macro).
--
--   npx -p fengari-node-cli fengari tests/tooltip_test.lua   (from the repo root)
--   lua tests/tooltip_test.lua                               (any Lua 5.1+)

local FULL = { "Linen Bandage", "Use: Heals 66 damage over 6 sec." }

-- World state the stubs read; each test sets it.
local world

local function Reset()
    world = { itemCached = false, spellCached = false, lines = { "Linen Bandage" }, itemLoads = 0, spellLoads = 0 }
end

function wipe(t)
    for k in pairs(t) do t[k] = nil end
    return t
end
ITEM_SPELL_TRIGGER_ONUSE = "Use:"
C_Item = {
    IsItemDataCachedByID = function() return world.itemCached end,
    RequestLoadItemDataByID = function() world.itemLoads = world.itemLoads + 1 end,
    GetItemSpell = function() return "First Aid", 7926 end,
}
C_Spell = {
    IsSpellDataCached = function() return world.spellCached end,
    RequestLoadSpellData = function() world.spellLoads = world.spellLoads + 1 end,
}
C_TooltipInfo = {
    GetBagItem = function()
        local lines = {}
        for _, text in ipairs(world.lines) do
            lines[#lines + 1] = { leftText = text }
        end
        return { lines = lines }
    end,
}

local ns = {}
assert(loadfile("Tooltip.lua"))("Rummage", ns)

local passed, failed = 0, 0
local function Test(name, fn)
    Reset()
    ns.ClearTooltipCache()
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

Test("incomplete tooltip is reported and not cached", function()
    local lines, complete = ns.GetBagItemTooltipLines(0, 1, 1251)
    Expect(#lines, 1, "lines")
    Expect(complete, false, "complete")
    Expect(world.itemLoads, 1, "item load requested")
    world.itemCached, world.spellCached, world.lines = true, true, FULL
    lines, complete = ns.GetBagItemTooltipLines(0, 1, 1251)
    Expect(#lines, 2, "lines after load")
    Expect(complete, true, "complete after load")
end)

Test("tooltip without the Use: spell text is not cached", function()
    -- Item loaded, spell description not yet: name and type, no Use: line.
    world.itemCached, world.lines = true, { "Linen Bandage", "Requires First Aid (1)" }
    local _, complete = ns.GetBagItemTooltipLines(0, 1, 1251)
    Expect(complete, false, "complete")
    Expect(world.spellLoads, 1, "spell load requested")
    world.spellCached, world.lines = true, FULL
    local lines = ns.GetBagItemTooltipLines(0, 1, 1251)
    Expect(lines[2], FULL[2], "fresh Use: line")
end)

Test("complete tooltip is cached", function()
    world.itemCached, world.spellCached, world.lines = true, true, FULL
    ns.GetBagItemTooltipLines(0, 1, 1251)
    world.lines = { "changed" }
    local lines, complete = ns.GetBagItemTooltipLines(0, 1, 1251)
    Expect(lines[1], "Linen Bandage", "cached")
    Expect(complete, true, "complete")
end)

Test("gives up requesting data that never arrives", function()
    for _ = 1, 5 do
        ns.GetBagItemTooltipLines(0, 1, 1251)
    end
    Expect(world.itemLoads, 3, "item load requests")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
