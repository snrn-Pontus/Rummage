local _, ns = ...

-- Tooltip text depends on the client language, but the category parsers are
-- written against English wording ("restores 280 to 360 health", "must
-- remain seated", "increases agility by 25"). For other languages this file
-- rewrites the (lower-cased) tooltip into that English form, so the parsers
-- and rankers stay the same everywhere. It also lists the words used to
-- recognise items by name when the item subclass is not enough.
--
-- Rules are applied in order with string.gsub on lower-cased text whose
-- numbers are already normalised (no thousands separators, no decimals).
-- Only ASCII letters change case in WoW's lower(), so patterns avoid
-- capitalised accented letters ("É preciso" is matched as "preciso").
--
-- pt-BR wording taken from Wowhead's pt-BR tooltips (Classic and retail).

local locale = {}
ns.locale = locale

local LANGUAGES = {
    ptBR = {
        names = {
            potion = { "poção", "tônico" },
            bandage = { "bandagem", "atadura" },
            flask = { "frasco", "elixir", "frasquinho" },
            scroll = { "pergaminho" },
        },
        startsQuest = { "esse item começa uma missão", "este item inicia uma missão", "este item começa uma missão" },
        rules = {
            -- Food and drink.
            { "preciso ficar sentad[oa]", "must remain seated" },
            { "preciso permanecer sentad[oa]", "must remain seated" },
            { "enquanto come", "while eating" },
            { "enquanto bebe", "while drinking" },
            { "bem alimentad[oa]", "well fed" },

            -- Stats. Longer phrases first.
            { "índice de acerto crítico", "critical strike rating" },
            { "chance de acerto crítico", "critical strike" },
            { "acerto crítico", "critical strike" },
            { "índice de acerto", "hit rating" },
            { "índice de aceleração", "haste rating" },
            { "aceleração", "haste" },
            { "índice de maestria", "mastery rating" },
            { "maestria", "mastery" },
            { "versatilidade", "versatility" },
            { "índice de especialização", "expertise rating" },
            { "vigor", "stamina" },
            { "espírito", "spirit" },
            { "força", "strength" },
            { "agilidade", "agility" },
            { "intelecto", "intellect" },
            { "armadura", "armor" },
            { "poder de ataque", "attack power" },
            { "poder mágico", "spell power" },
            { "dano causado por efeitos e feitiços mágicos", "spell damage" },
            { "dano de fogo de feitiços", "spell damage" },
            { "dano mágico", "spell damage" },
            { "todos os atributos", "of all stats" },

            -- Health and mana.
            { "pontos de mana e de vida", "mana and health" },
            { "pontos de vida", "health" },
            { "pontos de mana", "mana" },
            { "(%d+) de vida", "%1 health" },
            { "(%d+) de mana", "%1 mana" },
            { "do máximo de ", "of maximum " },
            { "máximo de ", "maximum " },
            { "a cada 5 segundos", "every 5 sec" },
            { "a cada 5 s", "every 5 sec" },
            { "ao longo de", "over" },
            { "restaura", "restores" },
            { "recupera", "restores" },
            { "regenera", "regenerate" },
            { "cura (%d+)", "heals %1" },
            { "(%d+) para (%d+)", "%1 to %2" },
            { "(%d+) a (%d+)", "%1 to %2" }, -- in-game: "Restaura 280 a 360"

            -- "aumenta em 25 a agilidade" -> "increases 25 agility",
            -- "aumenta sua versatilidade em 11" -> "increases sua versatility by 11",
            -- "agilidade aumentada em 10" -> "agility increased by 10".
            { " em até (%d+)", " em %1" },
            { " e em (%d+)", " and increases %1" },
            { "aumentad[oa] em (%d+)", "increased by %1" },
            { "aumenta em (%d+)", "increases %1" },
            { "aumenta", "increases" },
            { "(%a) em (%d+)", "%1 by %2" },
            { "ganhará (%d+)", "gain %1" },
            { "(%d+)%% [oa] ", "%1 " },
            { "(%d+) de ", "%1 " },
            { "(%d+) a sua ", "%1 " },
            { "(%d+) o seu ", "%1 " },
            { "(%d+) sua ", "%1 " },
            { "(%d+) seu ", "%1 " },
            { "(%d+) [oa]s? ", "%1 " },
            { " e [oa]s? ", " and " },
            { " e ", " and " },
        },
    },
}

local ENGLISH_NAMES = {
    potion = { "potion", "draught" },
    bandage = { "bandage" },
    flask = { "flask", "elixir", "phial" },
    scroll = { "scroll" },
}

local language = LANGUAGES[GetLocale and GetLocale() or "enUS"] or {}
local rules = language.rules or {}

-- Translates already lower-cased, number-normalised tooltip text.
function locale.Translate(text)
    for _, rule in ipairs(rules) do
        text = text:gsub(rule[1], rule[2])
    end
    return text
end

-- True when the item name contains one of the words for that kind of item
-- ("potion", "bandage", "flask"), in English or the client language.
function locale.NameHas(kind, name)
    if not name then
        return false
    end
    name = name:lower()
    for _, list in ipairs({ ENGLISH_NAMES[kind] or {}, language.names and language.names[kind] or {} }) do
        for _, word in ipairs(list) do
            if name:find(word, 1, true) then
                return true
            end
        end
    end
    return false
end

-- True when the tooltip says the item starts a quest.
function locale.StartsQuest(lines)
    local text = table.concat(lines, "\n"):lower()
    local phrases = { "begins a quest", "starts a quest" }
    if ITEM_STARTS_QUEST then
        phrases[#phrases + 1] = ITEM_STARTS_QUEST:lower()
    end
    for _, phrase in ipairs(language.startsQuest or {}) do
        phrases[#phrases + 1] = phrase
    end
    for _, phrase in ipairs(phrases) do
        if text:find(phrase, 1, true) then
            return true
        end
    end
    return false
end
