-- Offline tests for pt-BR tooltips: every category must classify the
-- Portuguese tooltip of an item exactly as it does the English one.
-- Tooltip text from Wowhead's pt-BR Classic tooltips, plus lines copied
-- from the in-game client where they differ ("Usar:", "280 a 360").
--
--   npx -p fengari-node-cli fengari tests/locale_test.lua   (from the repo root)
--   lua tests/locale_test.lua                               (any Lua 5.1+)

-- Consumable subclasses: 1 potion, 2 elixir, 3 flask, 4 scroll, 5 food, 7 bandage.
local ITEMS = {
    { id = 101, sub = 1, expect = "manapotion=360",
      en = { "Lesser Mana Potion", "Use: Restores 280 to 360 mana." },
      pt = { "Poção Inferior de Mana", "Usar: Restaura 280 a 360 pontos de mana.", "Requer o Nível 14" } },
    { id = 102, sub = 1, expect = "healthpotion=1750",
      en = { "Major Healing Potion", "Use: Restores 1050 to 1750 health. (2 Min Cooldown)" },
      pt = { "Poção Elevada de Cura", "Uso: Restaura 1050 para 1750 pontos de vida. (2 Min Recarga)" } },
    { id = 103, sub = 1, expect = "healthpotion=1760+ manapotion=1760+",
      en = { "Major Rejuvenation Potion", "Use: Restores 1440 to 1760 mana and health. (2 Min Cooldown)" },
      pt = { "Poção Elevada de Rejuvenescimento", "Uso: Restaura 1440 para 1760 pontos de mana e de vida. (2 Min Recarga)" } },
    { id = 104, sub = 5, expect = "drink=1992",
      en = { "Moonberry Juice", "Use: Restores 1992 mana over 30 sec. Must remain seated while drinking." },
      pt = { "Suco de Lunamora", "Uso: Recupera 1992 de mana ao longo de 30 s. É preciso ficar sentado enquanto bebe." } },
    { id = 105, sub = 5, expect = "drink=4410",
      en = { "Blessed Sunfruit Juice", "Use: Restores 4410 mana over 30 sec. Must remain seated while drinking. Also increases your Spirit by 10 for 10 min." },
      pt = { "Suco de Frutassol Abençoada", "Uso: Restaura 4410 pontos de mana ao longo de 30 s. É preciso permanecer sentado enquanto bebe. Também aumenta em 10 o Espírito por 10 min." } },
    { id = 106, sub = 5, expect = "plainfood=243",
      en = { "Haunch of Meat", "Use: Restores 243.6 health over 21 sec. Must remain seated while eating." },
      pt = { "Pernil de Carne", "Uso: Restaura 243.6 de vida ao longo de 21 s. É preciso ficar sentado enquanto come." } },
    { id = 107, sub = 5, expect = "food{SPIRIT:8,STAMINA:8}",
      en = { "Tasty Lion Steak", "Use: Restores 874.8 health over 27 sec. Must remain seated while eating. If you spend at least 10 seconds eating you will become well fed and gain 8 Stamina and Spirit for 15 min." },
      pt = { "Bife Saboroso de Leão", "Uso: Recupera 874.8 pontos de vida ao longo de 27 s. É preciso ficar sentado enquanto come. Se você gastar pelo menos 10 segundos comendo, ficará bem alimentado e ganhará 8 de Vigor e Espírito por 15 min." } },
    { id = 108, sub = 5, expect = "food{AGILITY:10}",
      en = { "Grilled Squid", "Use: Restores 874.8 health over 27 sec. Must remain seated while eating. If you spend at least 10 seconds eating you will become well fed and gain 10 Agility for 10 min." },
      pt = { "Lula Grelhada", "Uso: Restaura 874.8 pontos de vida ao longo de 27 s. É preciso ficar sentado enquanto come. Se você gastar pelo menos 10 s comendo, ganhará 10 de Agilidade por 10 min." } },
    { id = 109, sub = 5, expect = "food{STAMINA:10}",
      en = { "Cooked Glossy Mightfish", "Use: Restores 874.8 health over 27 sec. Must remain seated while eating. Also increases your Stamina by 10 for 10 min." },
      pt = { "Parrudo Lustroso Cozido", "Uso: Restaura 874.8 pontos de vida ao longo de 27 s. É preciso ficar sentado enquanto come. Também aumenta em 10 o Vigor por 10 min." } },
    { id = 110, sub = 5, expect = "food{MP5:8}",
      en = { "Nightfin Soup", "Use: Restores 874.8 health over 27 sec. Must remain seated while eating. Also restores 8 Mana every 5 seconds for 10 min." },
      pt = { "Sopa de Pinoturno", "Uso: Recupera 874.8 pontos de vida ao longo de 27 s. É preciso ficar sentado enquanto come. Além disso, recupera 8 pontos de mana a cada 5 segundos por 10 min." } },
    { id = 111, sub = 7, expect = "bandage=161",
      en = { "Wool Bandage", "Use: Heals 161 damage over 7 sec." },
      pt = { "Bandagem de Lã", "Uso: Cura 161 pontos de vida ao longo de 7 s." } },
    { id = 112, sub = 2, expect = "flask{INTELLECT:18,SPIRIT:18}",
      en = { "Elixir of the Sages", "Use: Increases Intellect and Spirit by 18 for 1 hour. (3 Sec Cooldown)" },
      pt = { "Elixir dos Sábios", "Uso: Aumenta em 18 o Intelecto e o Espírito por 1 hora. (3 Seg Recarga)" } },
    { id = 113, sub = 2, expect = "flask{AGILITY:25,CRIT:2}",
      en = { "Elixir of the Mongoose", "Use: Increases Agility by 25 and chance to get a critical hit by 2% for 1 hour. (3 Sec Cooldown)" },
      pt = { "Elixir do Mangusto", "Uso: Aumenta em 25 a Agilidade e em 2% a chance de acerto crítico por 1 hora. (3 Seg Recarga)" } },
    { id = 114, sub = 2, expect = "flask{SP:40}",
      en = { "Elixir of Shadow Power", "Use: Increases spell shadow damage by up to 40 for 30 min. (3 Sec Cooldown)" },
      pt = { "Elixir de Poder Sombrio", "Uso: Aumenta em até 40 o dano mágico de Sombra por 30 min. (3 Seg Recarga)" } },
    { id = 115, sub = 2, expect = "flask{MP5:12}",
      en = { "Mageblood Potion", "Use: Regenerate 12 mana per 5 sec for 1 hour. (3 Sec Cooldown)" },
      pt = { "Poção de Sangue de Mago", "Uso: Restaura 12 de mana a cada 5 s por 1 hora. (3 Seg Recarga)" } },
    { id = 116, sub = 3, expect = "flask{HEALTH:1200}",
      en = { "Flask of the Titans", "Use: Increases the player's maximum health by 1200 for 2 hrs. (3 Sec Cooldown)" },
      pt = { "Frasco dos Titãs", "Uso: Aumenta em 1200 o máximo de pontos de vida do jogador por 2 horas. (3 Seg Recarga)" } },
    { id = 117, sub = 3, expect = "flask{SP:150}",
      en = { "Flask of Supreme Power", "Use: Increases damage done by magical spells and effects by up to 150 for 2 hrs. (3 Sec Cooldown)" },
      pt = { "Frasco de Poder Supremo", "Uso: Aumenta em até 150 o dano causado por efeitos e feitiços mágicos por 2 horas. (3 Seg Recarga)" } },
    { id = 118, sub = 4, expect = "scroll{STAMINA:16}",
      en = { "Scroll of Stamina IV", "Use: Increases the target's Stamina by 16 for 30 min." },
      pt = { "Pergaminho do Vigor IV", "Uso: Aumenta em 16 o Vigor do alvo por 30 min." } },
    { id = 119, sub = 1, expect = "",
      en = { "Swim Speed Potion", "Use: Increases swim speed by 100% for 20 sec. (2 Min Cooldown)" },
      pt = { "Poção de Velocidade de Nado", "Uso: Aumenta em 100% a velocidade de nado por 20 s. (2 Min Recarga)" } },
    { id = 120, class = 12, expect = "quest",
      en = { "An Old History Book", "Binds when picked up", "Unique", "This Item Begins a Quest" },
      pt = { "Um Velho Livro de História", "Vincula-se ao ser recolhido", "Único", "Esse Item Começa uma Missão" } },
}

local byID = {}
for _, item in ipairs(ITEMS) do
    byID[item.id] = item
end

function UnitHealthMax() return 3000 end
function UnitPowerMax() return 4000 end
function UnitClass() return "Mage", "MAGE" end
function tContains(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end
function wipe(t)
    for k in pairs(t) do t[k] = nil end
    return t
end
C_Item = {
    GetItemInfoInstant = function(id)
        local item = byID[id] or {}
        return id, nil, nil, nil, nil, item.class or 0, item.sub or 8
    end,
}

-- Loads every category with the client language set to locale.
local function LoadCategories(locale)
    function GetLocale() return locale end
    local categories = {}
    local ns = { core = { RegisterCategory = function(c) categories[#categories + 1] = c end } }
    for _, path in ipairs({ "Locale.lua", "Categories/Stats.lua", "Categories/Food.lua", "Categories/Drink.lua",
        "Categories/Potions.lua", "Categories/Flask.lua", "Categories/Scroll.lua", "Categories/Bandage.lua",
        "Categories/Quest.lua" }) do
        assert(loadfile(path))("Rummage", ns)
    end
    return categories
end

-- "healthpotion=1760+ manapotion=1760+", "food{SPIRIT:8,STAMINA:8}", ...
local function Classify(categories, id, lines)
    local hits = {}
    for _, category in ipairs(categories) do
        local info = category.Classify(id, lines)
        if info then
            local text = category.key
            if info.amount then
                text = text .. "=" .. info.amount .. (info.restoresBoth and "+" or "")
            end
            if info.stats and next(info.stats) then
                local parts = {}
                for key, value in pairs(info.stats) do
                    parts[#parts + 1] = key .. ":" .. value
                end
                table.sort(parts)
                text = text .. "{" .. table.concat(parts, ",") .. "}"
            end
            hits[#hits + 1] = text
        end
    end
    return table.concat(hits, " ")
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

local english = LoadCategories("enUS")
local portuguese = LoadCategories("ptBR")
ITEM_STARTS_QUEST = nil

for _, item in ipairs(ITEMS) do
    Test("enUS " .. item.en[1], function()
        local got = Classify(english, item.id, item.en)
        assert(got == item.expect, "expected '" .. item.expect .. "', got '" .. got .. "'")
    end)
    Test("ptBR " .. item.pt[1], function()
        local got = Classify(portuguese, item.id, item.pt)
        assert(got == item.expect, "expected '" .. item.expect .. "', got '" .. got .. "'")
    end)
end

Test("pt-BR thousands separator", function()
    local item = { "Poção Gigante", "Usar: Restaura 1.200 a 2.000 pontos de vida." }
    assert(Classify(portuguese, 102, item) == "healthpotion=2000")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
